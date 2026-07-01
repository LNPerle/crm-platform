-- ==========================================================
-- Lumeni
-- 002_functions.sql
--
-- Fonctions utilitaires, fonctions d'autorisation et
-- fonctions RPC utilisées par l'application Lumeni.
-- ==========================================================

-- ==========================================================
-- Private schema
--
-- Contient les fonctions internes et les helpers RLS.
-- Ce schéma n'est pas exposé directement par l'API.
-- ==========================================================

create schema if not exists private;

revoke all on schema private from public;

grant usage on schema private to authenticated;

-- ==========================================================
-- Slugify
--
-- Transforme un nom en slug compatible avec une URL.
--
-- Exemple :
-- "Escale à Saigon" devient "escale-a-saigon".
-- ==========================================================

create or replace function public.lumeni_slugify(
    p_value text
)
returns text
language sql
immutable
strict
set search_path = ''
as
$$
    select trim(
        both '-'
        from regexp_replace(
            lower(public.unaccent(trim(p_value))),
            '[^a-z0-9]+',
            '-',
            'g'
        )
    );
$$;

comment on function public.lumeni_slugify(text) is
'Transforme une chaîne de caractères en slug URL.';

-- ==========================================================
-- Generate unique business slug
--
-- Génère automatiquement :
--
-- escale-a-saigon
-- escale-a-saigon-2
-- escale-a-saigon-3
-- ==========================================================

create or replace function public.lumeni_generate_unique_business_slug(
    p_business_name text
)
returns text
language plpgsql
volatile
security definer
set search_path = ''
as
$$
declare
    v_base_slug text;
    v_candidate text;
    v_suffix integer := 1;
begin
    v_base_slug := public.lumeni_slugify(p_business_name);

    if v_base_slug is null or v_base_slug = '' then
        v_base_slug := 'commerce';
    end if;

    v_candidate := v_base_slug;

    while exists (
        select 1
        from public.businesses b
        where lower(b.slug) = lower(v_candidate)
    )
    loop
        v_suffix := v_suffix + 1;
        v_candidate := v_base_slug || '-' || v_suffix;
    end loop;

    return v_candidate;
end;
$$;

comment on function public.lumeni_generate_unique_business_slug(text) is
'Génère un slug unique pour un commerce.';

-- ==========================================================
-- Business membership helper
--
-- Vérifie que l'utilisateur appartient au commerce.
--
-- Cette fonction sera utilisée par les politiques RLS.
-- ==========================================================

create or replace function private.lumeni_is_business_member(
    p_business_id uuid,
    p_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = ''
as
$$
    select exists (
        select 1
        from public.memberships m
        where m.business_id = p_business_id
          and m.profile_id = p_user_id
          and m.deleted_at is null
    );
$$;

comment on function private.lumeni_is_business_member(uuid, uuid) is
'Vérifie qu’un utilisateur appartient à un commerce.';

-- ==========================================================
-- Business role helper
--
-- Vérifie que l'utilisateur possède l'un des rôles demandés.
-- ==========================================================

create or replace function private.lumeni_has_business_role(
    p_business_id uuid,
    p_roles text[],
    p_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = ''
as
$$
    select exists (
        select 1
        from public.memberships m
        where m.business_id = p_business_id
          and m.profile_id = p_user_id
          and m.role = any(p_roles)
          and m.deleted_at is null
    );
$$;

comment on function private.lumeni_has_business_role(
    uuid,
    text[],
    uuid
) is
'Vérifie le rôle d’un utilisateur dans un commerce.';

-- ==========================================================
-- Create activity
--
-- Fonction interne permettant d'ajouter un événement dans
-- le Journal du commerce.
-- ==========================================================

create or replace function private.lumeni_create_activity(

    p_business_id uuid,

    p_profile_id uuid,

    p_customer_id uuid,

    p_entity text,

    p_entity_id uuid,

    p_action text,

    p_title text,

    p_description text default null,

    p_metadata jsonb default '{}'::jsonb,

    p_severity text default 'info'

)
returns uuid
language plpgsql
security definer
set search_path = ''
as
$$
declare
    v_activity_id uuid;
begin
    insert into public.activity_logs (
        business_id,
        profile_id,
        customer_id,
        entity,
        entity_id,
        action,
        title,
        description,
        metadata,
        severity
    )
    values (
        p_business_id,
        p_profile_id,
        p_customer_id,
        p_entity,
        p_entity_id,
        p_action,
        p_title,
        p_description,
        coalesce(p_metadata, '{}'::jsonb),
        p_severity
    )
    returning id into v_activity_id;

    return v_activity_id;
end;
$$;

comment on function private.lumeni_create_activity(
    uuid,
    uuid,
    uuid,
    text,
    uuid,
    text,
    text,
    text,
    jsonb,
    text
) is
'Ajoute un événement dans le Journal du commerce.';

-- ==========================================================
-- Create business and default loyalty program
--
-- Crée atomiquement :
--
-- 1. le profil de l'utilisateur si nécessaire ;
-- 2. le commerce ;
-- 3. la membership owner ;
-- 4. la récompense par défaut ;
-- 5. le programme de fidélité par défaut.
--
-- Si une étape échoue, aucune donnée n'est conservée.
-- ==========================================================

create or replace function public.lumeni_create_business(

    p_name text,

    p_industry text,

    p_program_name text default 'Programme principal',

    p_mode text default 'visits',

    p_target integer default 12,

    p_reward_name text default 'Récompense offerte',

    p_reward_type text default 'gift',

    p_reward_value integer default null

)
returns uuid
language plpgsql
security definer
set search_path = ''
as
$$
declare
    v_user_id uuid;
    v_user_email text;
    v_business_id uuid;
    v_reward_template_id uuid;
    v_slug text;
begin
    v_user_id := auth.uid();

    if v_user_id is null then
        raise exception 'Authentication required.'
            using errcode = '42501';
    end if;

    if nullif(trim(p_name), '') is null then
        raise exception 'Business name is required.'
            using errcode = '22023';
    end if;

    if nullif(trim(p_industry), '') is null then
        raise exception 'Industry is required.'
            using errcode = '22023';
    end if;

    if p_mode not in ('visits', 'points') then
        raise exception 'Invalid loyalty mode.'
            using errcode = '22023';
    end if;

    if p_target <= 0 then
        raise exception 'The loyalty target must be greater than zero.'
            using errcode = '22023';
    end if;

    if p_reward_type not in (
        'gift',
        'discount',
        'free_product',
        'points'
    ) then
        raise exception 'Invalid reward type.'
            using errcode = '22023';
    end if;

    select u.email
    into v_user_email
    from auth.users u
    where u.id = v_user_id;

    if v_user_email is null then
        raise exception 'The authenticated user has no email.'
            using errcode = '22023';
    end if;

    insert into public.profiles (
        id,
        email,
        first_name,
        last_name,
        last_login_at
    )
    select
        u.id,
        u.email,
        nullif(u.raw_user_meta_data ->> 'first_name', ''),
        nullif(u.raw_user_meta_data ->> 'last_name', ''),
        now()
    from auth.users u
    where u.id = v_user_id

    on conflict (id)
    do update set
        email = excluded.email,
        last_login_at = now(),
        updated_at = now();

    v_slug :=
        public.lumeni_generate_unique_business_slug(p_name);

    insert into public.businesses (
        name,
        slug,
        industry,
        subscription_status,
        trial_ends_at,
        plan
    )
    values (
        trim(p_name),
        v_slug,
        trim(p_industry),
        'trial',
        now() + interval '14 days',
        'starter'
    )
    returning id into v_business_id;

    insert into public.memberships (
        profile_id,
        business_id,
        role,
        accepted_at
    )
    values (
        v_user_id,
        v_business_id,
        'owner',
        now()
    );

    insert into public.reward_templates (
        business_id,
        name,
        reward_type,
        reward_value,
        validity_days,
        active
    )
    values (
        v_business_id,
        trim(p_reward_name),
        p_reward_type,
        p_reward_value,
        90,
        true
    )
    returning id into v_reward_template_id;

    insert into public.loyalty_programs (
        business_id,
        reward_template_id,
        name,
        mode,
        target,
        active,
        priority
    )
    values (
        v_business_id,
        v_reward_template_id,
        trim(p_program_name),
        p_mode,
        p_target,
        true,
        1
    );

    perform private.lumeni_create_activity(
        v_business_id,
        v_user_id,
        null,
        'business',
        v_business_id,
        'created',
        'Votre commerce est prêt 🎉',
        format(
            'Le commerce %s a été créé avec succès.',
            trim(p_name)
        ),
        jsonb_build_object(
            'industry', trim(p_industry),
            'slug', v_slug
        ),
        'success'
    );

    return v_business_id;
end;
$$;

comment on function public.lumeni_create_business(
    text,
    text,
    text,
    text,
    integer,
    text,
    text,
    integer
) is
'Crée un commerce, une membership et son programme initial.';

-- ==========================================================
-- Dashboard statistics
--
-- Retourne les principaux indicateurs d'un commerce dans un
-- unique objet JSON.
-- ==========================================================

create or replace function public.lumeni_dashboard_stats(
    p_business_id uuid
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as
$$
declare
    v_timezone text;
    v_local_date date;
begin
    if not private.lumeni_is_business_member(p_business_id) then
        raise exception 'Access denied.'
            using errcode = '42501';
    end if;

    select b.timezone
    into v_timezone
    from public.businesses b
    where b.id = p_business_id
      and b.deleted_at is null;

    if v_timezone is null then
        raise exception 'Business not found.'
            using errcode = 'P0002';
    end if;

    v_local_date := (now() at time zone v_timezone)::date;

    return jsonb_build_object(

        'customers',
        (
            select count(*)
            from public.customers c
            where c.business_id = p_business_id
              and c.deleted_at is null
        ),

        'activeCustomers',
        (
            select count(*)
            from public.customers c
            where c.business_id = p_business_id
              and c.status = 'active'
              and c.deleted_at is null
        ),

        'visitsToday',
        (
            select count(*)
            from public.visits v
            where v.business_id = p_business_id
              and (
                  v.created_at at time zone v_timezone
              )::date = v_local_date
        ),

        'visitsLast30Days',
        (
            select count(*)
            from public.visits v
            where v.business_id = p_business_id
              and v.created_at >= now() - interval '30 days'
        ),

        'availableRewards',
        (
            select count(*)
            from public.reward_claims r
            where r.business_id = p_business_id
              and r.status = 'available'
              and r.deleted_at is null
              and (
                  r.expires_at is null
                  or r.expires_at > now()
              )
        ),

        'birthdaysToday',
        (
            select count(*)
            from public.customers c
            where c.business_id = p_business_id
              and c.birth_date is not null
              and c.deleted_at is null
              and extract(month from c.birth_date)
                    = extract(month from v_local_date)
              and extract(day from c.birth_date)
                    = extract(day from v_local_date)
        )

    );
end;
$$;

comment on function public.lumeni_dashboard_stats(uuid) is
'Retourne les statistiques principales du dashboard.';

-- ==========================================================
-- Top customers
--
-- Retourne le classement des clients les plus fidèles.
-- ==========================================================

create or replace function public.lumeni_top_customers(

    p_business_id uuid,

    p_limit integer default 10

)
returns table (

    customer_rank bigint,

    customer_id uuid,

    full_name text,

    total_visits integer,

    completed_cycles bigint,

    total_rewards integer,

    last_visit_at timestamptz,

    customer_since timestamptz

)
language plpgsql
stable
security invoker
set search_path = ''
as
$$
begin
    if not private.lumeni_is_business_member(p_business_id) then
        raise exception 'Access denied.'
            using errcode = '42501';
    end if;

    return query

    with cycle_totals as (

        select
            a.customer_id,
            coalesce(sum(a.completed_cycles), 0)::bigint
                as completed_cycles

        from public.customer_loyalty_accounts a

        where a.business_id = p_business_id
          and a.deleted_at is null

        group by a.customer_id

    )

    select
        row_number() over (
            order by
                c.total_visits desc,
                coalesce(ct.completed_cycles, 0) desc,
                c.created_at asc
        ) as customer_rank,

        c.id as customer_id,

        c.full_name,

        c.total_visits,

        coalesce(ct.completed_cycles, 0),

        c.total_rewards,

        c.last_visit_at,

        coalesce(c.first_visit_at, c.created_at)
            as customer_since

    from public.customers c

    left join cycle_totals ct
        on ct.customer_id = c.id

    where c.business_id = p_business_id
      and c.deleted_at is null
      and c.status <> 'blocked'

    order by
        c.total_visits desc,
        coalesce(ct.completed_cycles, 0) desc,
        c.created_at asc

    limit least(
        greatest(p_limit, 1),
        100
    );
end;
$$;

comment on function public.lumeni_top_customers(uuid, integer) is
'Retourne le classement des clients les plus fidèles.';

-- ==========================================================
-- Birthdays today
-- ==========================================================

create or replace function public.lumeni_birthdays_today(
    p_business_id uuid
)
returns table (

    customer_id uuid,

    full_name text,

    birth_date date,

    total_visits integer,

    customer_since timestamptz

)
language plpgsql
stable
security invoker
set search_path = ''
as
$$
declare
    v_timezone text;
    v_local_date date;
begin
    if not private.lumeni_is_business_member(p_business_id) then
        raise exception 'Access denied.'
            using errcode = '42501';
    end if;

    select b.timezone
    into v_timezone
    from public.businesses b
    where b.id = p_business_id
      and b.deleted_at is null;

    if v_timezone is null then
        raise exception 'Business not found.'
            using errcode = 'P0002';
    end if;

    v_local_date := (now() at time zone v_timezone)::date;

    return query

    select
        c.id,
        c.full_name,
        c.birth_date,
        c.total_visits,
        coalesce(c.first_visit_at, c.created_at)

    from public.customers c

    where c.business_id = p_business_id
      and c.birth_date is not null
      and c.deleted_at is null
      and c.status = 'active'
      and extract(month from c.birth_date)
            = extract(month from v_local_date)
      and extract(day from c.birth_date)
            = extract(day from v_local_date)

    order by c.full_name;
end;
$$;

comment on function public.lumeni_birthdays_today(uuid) is
'Retourne les clients dont l’anniversaire est aujourd’hui.';

-- ==========================================================
-- Customer loyalty progress
--
-- Retourne la progression d'un client dans un programme.
-- ==========================================================

create or replace function public.lumeni_customer_progress(

    p_customer_id uuid,

    p_loyalty_program_id uuid

)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as
$$
declare
    v_business_id uuid;
    v_result jsonb;
begin
    select c.business_id
    into v_business_id
    from public.customers c
    where c.id = p_customer_id
      and c.deleted_at is null;

    if v_business_id is null then
        raise exception 'Customer not found.'
            using errcode = 'P0002';
    end if;

    if not private.lumeni_is_business_member(v_business_id) then
        raise exception 'Access denied.'
            using errcode = '42501';
    end if;

    select jsonb_build_object(

        'programId',
        p.id,

        'programName',
        p.name,

        'mode',
        p.mode,

        'target',
        p.target,

        'current',
        case
            when p.mode = 'visits'
                then coalesce(a.current_visits, 0)
            else coalesce(a.current_points, 0)
        end,

        'remaining',
        greatest(
            p.target -
            case
                when p.mode = 'visits'
                    then coalesce(a.current_visits, 0)
                else coalesce(a.current_points, 0)
            end,
            0
        ),

        'progressPercent',
        round(
            (
                least(
                    case
                        when p.mode = 'visits'
                            then coalesce(a.current_visits, 0)
                        else coalesce(a.current_points, 0)
                    end,
                    p.target
                )::numeric
                / p.target::numeric
            ) * 100,
            1
        ),

        'completedCycles',
        coalesce(a.completed_cycles, 0),

        'reward',
        case
            when r.id is null then null
            else jsonb_build_object(
                'id', r.id,
                'name', r.name,
                'type', r.reward_type,
                'value', r.reward_value
            )
        end

    )
    into v_result

    from public.loyalty_programs p

    left join public.customer_loyalty_accounts a
        on a.loyalty_program_id = p.id
       and a.customer_id = p_customer_id
       and a.deleted_at is null

    left join public.reward_templates r
        on r.id = p.reward_template_id
       and r.deleted_at is null

    where p.id = p_loyalty_program_id
      and p.business_id = v_business_id
      and p.deleted_at is null;

    if v_result is null then
        raise exception 'Loyalty program not found.'
            using errcode = 'P0002';
    end if;

    return v_result;
end;
$$;

comment on function public.lumeni_customer_progress(uuid, uuid) is
'Retourne la progression fidélité d’un client.';

-- ==========================================================
-- Function permissions
--
-- Les fonctions SQL ne sont pas protégées automatiquement
-- par les politiques RLS. Leur exécution est donc limitée
-- explicitement aux utilisateurs authentifiés.
-- ==========================================================

revoke all on function
    public.lumeni_slugify(text)
from public;

revoke all on function
    public.lumeni_generate_unique_business_slug(text)
from public;

revoke all on function
    public.lumeni_create_business(
        text,
        text,
        text,
        text,
        integer,
        text,
        text,
        integer
    )
from public;

revoke all on function
    public.lumeni_dashboard_stats(uuid)
from public;

revoke all on function
    public.lumeni_top_customers(uuid, integer)
from public;

revoke all on function
    public.lumeni_birthdays_today(uuid)
from public;

revoke all on function
    public.lumeni_customer_progress(uuid, uuid)
from public;

revoke all on function
    private.lumeni_is_business_member(uuid, uuid)
from public;

revoke all on function
    private.lumeni_has_business_role(uuid, text[], uuid)
from public;

revoke all on function
    private.lumeni_create_activity(
        uuid,
        uuid,
        uuid,
        text,
        uuid,
        text,
        text,
        text,
        jsonb,
        text
    )
from public;

grant execute on function
    public.lumeni_slugify(text)
to authenticated;

grant execute on function
    public.lumeni_generate_unique_business_slug(text)
to authenticated;

grant execute on function
    public.lumeni_create_business(
        text,
        text,
        text,
        text,
        integer,
        text,
        text,
        integer
    )
to authenticated;

grant execute on function
    public.lumeni_dashboard_stats(uuid)
to authenticated;

grant execute on function
    public.lumeni_top_customers(uuid, integer)
to authenticated;

grant execute on function
    public.lumeni_birthdays_today(uuid)
to authenticated;

grant execute on function
    public.lumeni_customer_progress(uuid, uuid)
to authenticated;

grant execute on function
    private.lumeni_is_business_member(uuid, uuid)
to authenticated;

grant execute on function
    private.lumeni_has_business_role(uuid, text[], uuid)
to authenticated;