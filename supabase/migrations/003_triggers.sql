-- ==========================================================
-- Lumeni
-- 003_triggers.sql
--
-- Automatismes métier : profils, updated_at, intégrité
-- multi-commerce, visites, progression et récompenses.
--
-- Dépend de :
--   001_schema.sql
--   002_functions.sql
-- ==========================================================

-- Évite un dépassement pour les clients revenant après de longues périodes.
alter table public.customers
    alter column average_days_between_visits type numeric(8, 2);

-- ==========================================================
-- 1. Synchronisation auth.users -> public.profiles
-- ==========================================================

create or replace function public.lumeni_sync_auth_user_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as
$$
begin
    insert into public.profiles as p (
        id,
        email,
        first_name,
        last_name,
        avatar_url
    )
    values (
        new.id,
        new.email,
        nullif(trim(new.raw_user_meta_data ->> 'first_name'), ''),
        nullif(trim(new.raw_user_meta_data ->> 'last_name'), ''),
        nullif(trim(new.raw_user_meta_data ->> 'avatar_url'), '')
    )
    on conflict (id)
    do update set
        email = excluded.email,
        first_name = coalesce(excluded.first_name, p.first_name),
        last_name = coalesce(excluded.last_name, p.last_name),
        avatar_url = coalesce(excluded.avatar_url, p.avatar_url),
        updated_at = now();

    return new;
end;
$$;

comment on function public.lumeni_sync_auth_user_profile() is
'Synchronise un utilisateur Supabase Auth avec public.profiles.';

revoke all on function public.lumeni_sync_auth_user_profile()
from public, anon, authenticated;

drop trigger if exists lumeni_10_auth_user_created
on auth.users;

create trigger lumeni_10_auth_user_created
after insert on auth.users
for each row
execute function public.lumeni_sync_auth_user_profile();

drop trigger if exists lumeni_10_auth_user_updated
on auth.users;

create trigger lumeni_10_auth_user_updated
after update of email, raw_user_meta_data on auth.users
for each row
execute function public.lumeni_sync_auth_user_profile();

-- ==========================================================
-- 2. Mise à jour automatique de updated_at
-- ==========================================================

create or replace function private.lumeni_set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as
$$
begin
    new.updated_at := now();
    return new;
end;
$$;

comment on function private.lumeni_set_updated_at() is
'Met automatiquement à jour la colonne updated_at.';

revoke all on function private.lumeni_set_updated_at()
from public, anon, authenticated;

drop trigger if exists lumeni_90_profiles_updated_at
on public.profiles;
create trigger lumeni_90_profiles_updated_at
before update on public.profiles
for each row execute function private.lumeni_set_updated_at();

drop trigger if exists lumeni_90_businesses_updated_at
on public.businesses;
create trigger lumeni_90_businesses_updated_at
before update on public.businesses
for each row execute function private.lumeni_set_updated_at();

drop trigger if exists lumeni_90_memberships_updated_at
on public.memberships;
create trigger lumeni_90_memberships_updated_at
before update on public.memberships
for each row execute function private.lumeni_set_updated_at();

drop trigger if exists lumeni_90_reward_templates_updated_at
on public.reward_templates;
create trigger lumeni_90_reward_templates_updated_at
before update on public.reward_templates
for each row execute function private.lumeni_set_updated_at();

drop trigger if exists lumeni_90_loyalty_programs_updated_at
on public.loyalty_programs;
create trigger lumeni_90_loyalty_programs_updated_at
before update on public.loyalty_programs
for each row execute function private.lumeni_set_updated_at();

drop trigger if exists lumeni_90_customers_updated_at
on public.customers;
create trigger lumeni_90_customers_updated_at
before update on public.customers
for each row execute function private.lumeni_set_updated_at();

drop trigger if exists lumeni_90_customer_loyalty_accounts_updated_at
on public.customer_loyalty_accounts;
create trigger lumeni_90_customer_loyalty_accounts_updated_at
before update on public.customer_loyalty_accounts
for each row execute function private.lumeni_set_updated_at();

drop trigger if exists lumeni_90_reward_claims_updated_at
on public.reward_claims;
create trigger lumeni_90_reward_claims_updated_at
before update on public.reward_claims
for each row execute function private.lumeni_set_updated_at();

drop trigger if exists lumeni_90_customer_tags_updated_at
on public.customer_tags;
create trigger lumeni_90_customer_tags_updated_at
before update on public.customer_tags
for each row execute function private.lumeni_set_updated_at();

-- ==========================================================
-- 3. Attribution automatique des auteurs d'une fiche client
-- ==========================================================

create or replace function private.lumeni_track_customer_editor()
returns trigger
language plpgsql
set search_path = ''
as
$$
begin
    if tg_op = 'INSERT' then
        new.created_by := coalesce(new.created_by, auth.uid());
        new.updated_by := coalesce(new.updated_by, new.created_by, auth.uid());
    else
        new.created_by := old.created_by;
        new.updated_by := coalesce(auth.uid(), new.updated_by, old.updated_by);
    end if;

    return new;
end;
$$;

revoke all on function private.lumeni_track_customer_editor()
from public, anon, authenticated;

drop trigger if exists lumeni_20_customers_track_editor
on public.customers;

create trigger lumeni_20_customers_track_editor
before insert or update on public.customers
for each row
execute function private.lumeni_track_customer_editor();

-- ==========================================================
-- 4. Intégrité multi-commerce
-- ==========================================================

create or replace function private.lumeni_validate_loyalty_program()
returns trigger
language plpgsql
set search_path = ''
as
$$
begin
    if new.reward_template_id is not null
       and not exists (
            select 1
            from public.reward_templates r
            where r.id = new.reward_template_id
              and r.business_id = new.business_id
              and r.deleted_at is null
       ) then
        raise exception
            'The reward template must belong to the same business as the loyalty program.'
            using errcode = '23514';
    end if;

    return new;
end;
$$;

revoke all on function private.lumeni_validate_loyalty_program()
from public, anon, authenticated;

drop trigger if exists lumeni_10_loyalty_programs_validate
on public.loyalty_programs;

create trigger lumeni_10_loyalty_programs_validate
before insert or update of business_id, reward_template_id
on public.loyalty_programs
for each row
execute function private.lumeni_validate_loyalty_program();

create or replace function private.lumeni_validate_customer_loyalty_account()
returns trigger
language plpgsql
set search_path = ''
as
$$
declare
    v_customer_business_id uuid;
    v_program_business_id uuid;
begin
    select c.business_id
    into v_customer_business_id
    from public.customers c
    where c.id = new.customer_id
      and c.deleted_at is null;

    select p.business_id
    into v_program_business_id
    from public.loyalty_programs p
    where p.id = new.loyalty_program_id
      and p.deleted_at is null;

    if v_customer_business_id is null then
        raise exception 'Customer not found.'
            using errcode = '23503';
    end if;

    if v_program_business_id is null then
        raise exception 'Loyalty program not found.'
            using errcode = '23503';
    end if;

    if v_customer_business_id <> v_program_business_id then
        raise exception
            'The customer and program must belong to the same business.'
            using errcode = '23514';
    end if;

    if new.business_id is not null
       and new.business_id <> v_customer_business_id then
        raise exception
            'The loyalty account must belong to the customer business.'
            using errcode = '23514';
    end if;

    new.business_id := v_customer_business_id;

    return new;
end;
$$;

revoke all on function private.lumeni_validate_customer_loyalty_account()
from public, anon, authenticated;

drop trigger if exists lumeni_10_customer_loyalty_accounts_validate
on public.customer_loyalty_accounts;

create trigger lumeni_10_customer_loyalty_accounts_validate
before insert or update of business_id, customer_id, loyalty_program_id
on public.customer_loyalty_accounts
for each row
execute function private.lumeni_validate_customer_loyalty_account();

create or replace function private.lumeni_validate_customer_tag_assignment()
returns trigger
language plpgsql
set search_path = ''
as
$$
declare
    v_customer_business_id uuid;
    v_tag_business_id uuid;
begin
    select c.business_id
    into v_customer_business_id
    from public.customers c
    where c.id = new.customer_id
      and c.deleted_at is null;

    select t.business_id
    into v_tag_business_id
    from public.customer_tags t
    where t.id = new.tag_id
      and t.deleted_at is null;

    if v_customer_business_id is null then
        raise exception 'Customer not found.'
            using errcode = '23503';
    end if;

    if v_tag_business_id is null then
        raise exception 'Customer tag not found.'
            using errcode = '23503';
    end if;

    if v_customer_business_id <> v_tag_business_id then
        raise exception
            'The customer and tag must belong to the same business.'
            using errcode = '23514';
    end if;

    return new;
end;
$$;

revoke all on function private.lumeni_validate_customer_tag_assignment()
from public, anon, authenticated;

drop trigger if exists lumeni_10_customer_tag_assignments_validate
on public.customer_tag_assignments;

create trigger lumeni_10_customer_tag_assignments_validate
before insert or update of customer_id, tag_id
on public.customer_tag_assignments
for each row
execute function private.lumeni_validate_customer_tag_assignment();

-- ==========================================================
-- 5. Préparation d'une visite
--
-- Ce trigger :
--   - vérifie les références ;
--   - choisit le programme prioritaire si aucun n'est fourni ;
--   - sérialise les visites d'un même client ;
--   - met à jour ses statistiques ;
--   - attribue visit_number.
-- ==========================================================

create or replace function private.lumeni_prepare_visit()
returns trigger
language plpgsql
security definer
set search_path = ''
as
$$
declare
    v_customer public.customers%rowtype;
    v_program public.loyalty_programs%rowtype;
    v_total_visits integer;
    v_first_visit_at timestamptz;
    v_last_visit_at timestamptz;
    v_average_days numeric(6, 2);
begin
    if new.created_at is null then
        new.created_at := now();
    end if;

    if new.points_earned < 0 then
        raise exception 'points_earned cannot be negative.'
            using errcode = '23514';
    end if;

    select c.*
    into v_customer
    from public.customers c
    where c.id = new.customer_id
      and c.deleted_at is null
    for update;

    if not found then
        raise exception 'Customer not found.'
            using errcode = '23503';
    end if;

    if v_customer.status = 'blocked' then
        raise exception 'A blocked customer cannot receive a visit.'
            using errcode = '23514';
    end if;

    if new.business_id is not null
       and new.business_id <> v_customer.business_id then
        raise exception
            'The visit and customer must belong to the same business.'
            using errcode = '23514';
    end if;

    new.business_id := v_customer.business_id;
    new.employee_id := coalesce(new.employee_id, auth.uid());

    if new.employee_id is not null
       and not exists (
            select 1
            from public.memberships m
            where m.business_id = new.business_id
              and m.profile_id = new.employee_id
              and m.deleted_at is null
       ) then
        raise exception
            'The employee must belong to the same business.'
            using errcode = '23514';
    end if;

    if new.loyalty_program_id is null then
        select p.*
        into v_program
        from public.loyalty_programs p
        where p.business_id = new.business_id
          and p.active = true
          and p.deleted_at is null
          and (p.starts_at is null or p.starts_at <= new.created_at)
          and (p.ends_at is null or p.ends_at > new.created_at)
        order by p.priority desc, p.created_at asc
        limit 1;

        if found then
            new.loyalty_program_id := v_program.id;
        end if;
    else
        select p.*
        into v_program
        from public.loyalty_programs p
        where p.id = new.loyalty_program_id
          and p.business_id = new.business_id
          and p.deleted_at is null;

        if not found then
            raise exception
                'The loyalty program must belong to the same business.'
                using errcode = '23514';
        end if;

        if new.visit_source <> 'import'
           and (
                v_program.active = false
                or (v_program.starts_at is not null and v_program.starts_at > new.created_at)
                or (v_program.ends_at is not null and v_program.ends_at <= new.created_at)
           ) then
            raise exception 'The loyalty program is not active for this visit.'
                using errcode = '23514';
        end if;
    end if;

    v_total_visits := v_customer.total_visits + 1;

    v_first_visit_at := case
        when v_customer.first_visit_at is null then new.created_at
        else least(v_customer.first_visit_at, new.created_at)
    end;

    v_last_visit_at := case
        when v_customer.last_visit_at is null then new.created_at
        else greatest(v_customer.last_visit_at, new.created_at)
    end;

    if v_total_visits <= 1 then
        v_average_days := null;
    else
        v_average_days := round(
            (
                extract(epoch from (v_last_visit_at - v_first_visit_at))
                / 86400.0
                / (v_total_visits - 1)
            )::numeric,
            2
        );
    end if;

    new.visit_number := v_total_visits;

    update public.customers c
    set
        total_visits = v_total_visits,
        total_points = c.total_points + new.points_earned,
        lifetime_points = c.lifetime_points + new.points_earned,
        first_visit_at = v_first_visit_at,
        last_visit_at = v_last_visit_at,
        last_seen_at = case
            when c.last_seen_at is null then new.created_at
            else greatest(c.last_seen_at, new.created_at)
        end,
        average_days_between_visits = v_average_days,
        status = case
            when c.status = 'inactive' then 'active'
            else c.status
        end,
        updated_by = coalesce(new.employee_id, c.updated_by)
    where c.id = new.customer_id;

    return new;
end;
$$;

comment on function private.lumeni_prepare_visit() is
'Valide une visite, met à jour le client et attribue son numéro.';

revoke all on function private.lumeni_prepare_visit()
from public, anon, authenticated;

drop trigger if exists lumeni_10_visits_prepare
on public.visits;

create trigger lumeni_10_visits_prepare
before insert on public.visits
for each row
execute function private.lumeni_prepare_visit();

-- ==========================================================
-- 6. Progression fidélité après une visite
-- ==========================================================

create or replace function private.lumeni_apply_visit_to_loyalty()
returns trigger
language plpgsql
security definer
set search_path = ''
as
$$
declare
    v_program public.loyalty_programs%rowtype;
    v_account public.customer_loyalty_accounts%rowtype;
    v_reward public.reward_templates%rowtype;
    v_increment integer := 0;
    v_new_current integer := 0;
    v_completed_cycles integer := 0;
    v_remainder integer := 0;
    v_rewards_created integer := 0;
    v_description text;
begin
    perform private.lumeni_create_activity(
        new.business_id,
        new.employee_id,
        new.customer_id,
        'visit',
        new.id,
        'created',
        case
            when new.visit_number = 1 then 'Premier passage enregistré 🎉'
            else 'Nouvelle visite enregistrée'
        end,
        format(
            'La visite n°%s a été enregistrée.',
            new.visit_number
        ),
        jsonb_build_object(
            'visitNumber', new.visit_number,
            'source', new.visit_source,
            'pointsEarned', new.points_earned,
            'loyaltyProgramId', new.loyalty_program_id
        ),
        case
            when new.visit_number = 1 then 'success'
            else 'info'
        end
    );

    if new.loyalty_program_id is null then
        return new;
    end if;

    select p.*
    into v_program
    from public.loyalty_programs p
    where p.id = new.loyalty_program_id
      and p.business_id = new.business_id
      and p.deleted_at is null;

    if not found then
        raise exception 'Loyalty program not found.'
            using errcode = '23503';
    end if;

    insert into public.customer_loyalty_accounts as account (
        business_id,
        customer_id,
        loyalty_program_id,
        last_activity_at
    )
    values (
        new.business_id,
        new.customer_id,
        new.loyalty_program_id,
        new.created_at
    )
    on conflict (customer_id, loyalty_program_id)
    do update set
        business_id = excluded.business_id,
        deleted_at = null,
        last_activity_at = greatest(
            coalesce(account.last_activity_at, excluded.last_activity_at),
            excluded.last_activity_at
        );

    select a.*
    into v_account
    from public.customer_loyalty_accounts a
    where a.customer_id = new.customer_id
      and a.loyalty_program_id = new.loyalty_program_id
    for update;

    if v_program.mode = 'visits' then
        v_increment := 1;
        v_new_current := v_account.current_visits + v_increment;
        v_completed_cycles := v_new_current / v_program.target;
        v_remainder := mod(v_new_current, v_program.target);

        update public.customer_loyalty_accounts a
        set
            current_visits = v_remainder,
            lifetime_visits = a.lifetime_visits + v_increment,
            completed_cycles = a.completed_cycles + v_completed_cycles,
            last_activity_at = greatest(
                coalesce(a.last_activity_at, new.created_at),
                new.created_at
            )
        where a.id = v_account.id;
    else
        v_increment := new.points_earned;
        v_new_current := v_account.current_points + v_increment;
        v_completed_cycles := v_new_current / v_program.target;
        v_remainder := mod(v_new_current, v_program.target);

        update public.customer_loyalty_accounts a
        set
            current_points = v_remainder,
            lifetime_points = a.lifetime_points + v_increment,
            completed_cycles = a.completed_cycles + v_completed_cycles,
            last_activity_at = greatest(
                coalesce(a.last_activity_at, new.created_at),
                new.created_at
            )
        where a.id = v_account.id;

        if v_completed_cycles > 0 then
            update public.customers c
            set total_points = greatest(
                c.total_points - (v_completed_cycles * v_program.target),
                0
            )
            where c.id = new.customer_id;
        end if;
    end if;

    if v_completed_cycles <= 0 then
        return new;
    end if;

    if v_program.reward_template_id is not null then
        select r.*
        into v_reward
        from public.reward_templates r
        where r.id = v_program.reward_template_id
          and r.business_id = new.business_id
          and r.active = true
          and r.deleted_at is null;

        if found then
            insert into public.reward_claims (
                business_id,
                customer_id,
                reward_template_id,
                loyalty_program_id,
                visit_id,
                status,
                expires_at,
                created_at
            )
            select
                new.business_id,
                new.customer_id,
                v_reward.id,
                v_program.id,
                new.id,
                'available',
                new.created_at + make_interval(days => v_reward.validity_days),
                new.created_at
            from generate_series(1, v_completed_cycles);

            get diagnostics v_rewards_created = row_count;
        end if;
    end if;

    v_description := case
        when v_completed_cycles = 1 then
            format(
                'Le client a terminé un cycle du programme « %s ».',
                v_program.name
            )
        else
            format(
                'Le client a terminé %s cycles du programme « %s ».',
                v_completed_cycles,
                v_program.name
            )
    end;

    perform private.lumeni_create_activity(
        new.business_id,
        new.employee_id,
        new.customer_id,
        'loyalty_program',
        v_program.id,
        'cycle_completed',
        case
            when v_rewards_created > 0 then 'Récompense débloquée 🎁'
            else 'Objectif fidélité atteint 🏆'
        end,
        v_description,
        jsonb_build_object(
            'visitId', new.id,
            'programId', v_program.id,
            'completedCycles', v_completed_cycles,
            'rewardsCreated', v_rewards_created,
            'remainingProgress', v_remainder,
            'rewardTemplateId', v_program.reward_template_id
        ),
        'success'
    );

    return new;
end;
$$;

comment on function private.lumeni_apply_visit_to_loyalty() is
'Applique une visite à la progression fidélité et débloque les récompenses.';

revoke all on function private.lumeni_apply_visit_to_loyalty()
from public, anon, authenticated;

drop trigger if exists lumeni_20_visits_apply_loyalty
on public.visits;

create trigger lumeni_20_visits_apply_loyalty
after insert on public.visits
for each row
execute function private.lumeni_apply_visit_to_loyalty();

-- ==========================================================
-- 7. Validation et cycle de vie des récompenses
-- ==========================================================

create or replace function private.lumeni_prepare_reward_claim()
returns trigger
language plpgsql
security definer
set search_path = ''
as
$$
declare
    v_customer_business_id uuid;
    v_reward_business_id uuid;
    v_validity_days integer;
    v_program_business_id uuid;
    v_visit_business_id uuid;
    v_visit_customer_id uuid;
begin
    if tg_op = 'UPDATE' then
        if new.business_id <> old.business_id
           or new.customer_id <> old.customer_id
           or new.reward_template_id <> old.reward_template_id
           or new.loyalty_program_id is distinct from old.loyalty_program_id
           or new.visit_id is distinct from old.visit_id
           or new.created_at <> old.created_at then
            raise exception 'The identity of a reward claim is immutable.'
                using errcode = '23514';
        end if;

        if old.status <> new.status
           and old.status <> 'available' then
            raise exception 'A completed reward claim cannot change status.'
                using errcode = '23514';
        end if;

        if old.status = 'available'
           and new.status not in ('available', 'redeemed', 'expired', 'cancelled') then
            raise exception 'Invalid reward status transition.'
                using errcode = '23514';
        end if;
    end if;

    select c.business_id
    into v_customer_business_id
    from public.customers c
    where c.id = new.customer_id
      and c.deleted_at is null;

    select r.business_id, r.validity_days
    into v_reward_business_id, v_validity_days
    from public.reward_templates r
    where r.id = new.reward_template_id
      and r.deleted_at is null;

    if v_customer_business_id is null then
        raise exception 'Customer not found.'
            using errcode = '23503';
    end if;

    if v_reward_business_id is null then
        raise exception 'Reward template not found.'
            using errcode = '23503';
    end if;

    if v_customer_business_id <> v_reward_business_id then
        raise exception
            'The customer and reward must belong to the same business.'
            using errcode = '23514';
    end if;

    if new.business_id is not null
       and new.business_id <> v_customer_business_id then
        raise exception
            'The reward claim must belong to the customer business.'
            using errcode = '23514';
    end if;

    new.business_id := v_customer_business_id;

    if new.loyalty_program_id is not null then
        select p.business_id
        into v_program_business_id
        from public.loyalty_programs p
        where p.id = new.loyalty_program_id
          and p.deleted_at is null;

        if v_program_business_id is null
           or v_program_business_id <> new.business_id then
            raise exception
                'The loyalty program must belong to the same business.'
                using errcode = '23514';
        end if;
    end if;

    if new.visit_id is not null then
        select v.business_id, v.customer_id
        into v_visit_business_id, v_visit_customer_id
        from public.visits v
        where v.id = new.visit_id;

        if v_visit_business_id is null
           or v_visit_business_id <> new.business_id
           or v_visit_customer_id <> new.customer_id then
            raise exception
                'The source visit must belong to the same business and customer.'
                using errcode = '23514';
        end if;
    end if;

    if new.created_at is null then
        new.created_at := now();
    end if;

    if tg_op = 'INSERT' and new.expires_at is null then
        new.expires_at := new.created_at + make_interval(days => v_validity_days);
    end if;

    if new.status = 'redeemed'
       and new.expires_at is not null
       and new.expires_at <= now() then
        raise exception 'An expired reward cannot be redeemed.'
            using errcode = '23514';
    end if;

    if new.status = 'available'
       and new.expires_at is not null
       and new.expires_at <= now() then
        new.status := 'expired';
    end if;

    if new.status = 'redeemed' then
        new.redeemed_at := coalesce(new.redeemed_at, now());
    elsif tg_op = 'INSERT' then
        new.redeemed_at := null;
    elsif old.status <> 'redeemed' then
        new.redeemed_at := null;
    end if;

    return new;
end;
$$;

comment on function private.lumeni_prepare_reward_claim() is
'Valide les références, l’expiration et les transitions d’une récompense.';

revoke all on function private.lumeni_prepare_reward_claim()
from public, anon, authenticated;

drop trigger if exists lumeni_10_reward_claims_prepare
on public.reward_claims;

create trigger lumeni_10_reward_claims_prepare
before insert or update on public.reward_claims
for each row
execute function private.lumeni_prepare_reward_claim();

create or replace function private.lumeni_after_reward_claim_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as
$$
declare
    v_reward_name text;
    v_profile_id uuid;
begin
    select r.name
    into v_reward_name
    from public.reward_templates r
    where r.id = new.reward_template_id;

    if new.visit_id is not null then
        select v.employee_id
        into v_profile_id
        from public.visits v
        where v.id = new.visit_id;
    end if;

    v_profile_id := coalesce(v_profile_id, auth.uid());

    update public.customers c
    set
        total_rewards = c.total_rewards + 1,
        last_reward_at = case
            when c.last_reward_at is null then new.created_at
            else greatest(c.last_reward_at, new.created_at)
        end
    where c.id = new.customer_id;

    perform private.lumeni_create_activity(
        new.business_id,
        v_profile_id,
        new.customer_id,
        'reward_claim',
        new.id,
        'created',
        'Nouvelle récompense disponible 🎁',
        format(
            'La récompense « %s » est maintenant disponible.',
            coalesce(v_reward_name, 'Récompense')
        ),
        jsonb_build_object(
            'rewardTemplateId', new.reward_template_id,
            'loyaltyProgramId', new.loyalty_program_id,
            'visitId', new.visit_id,
            'expiresAt', new.expires_at,
            'status', new.status
        ),
        'success'
    );

    return new;
end;
$$;

revoke all on function private.lumeni_after_reward_claim_insert()
from public, anon, authenticated;

drop trigger if exists lumeni_20_reward_claims_after_insert
on public.reward_claims;

create trigger lumeni_20_reward_claims_after_insert
after insert on public.reward_claims
for each row
execute function private.lumeni_after_reward_claim_insert();

create or replace function private.lumeni_after_reward_claim_status_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as
$$
declare
    v_reward_name text;
    v_title text;
    v_action text;
    v_severity text;
begin
    if new.status = old.status then
        return new;
    end if;

    select r.name
    into v_reward_name
    from public.reward_templates r
    where r.id = new.reward_template_id;

    v_action := new.status;

    case new.status
        when 'redeemed' then
            v_title := 'Récompense utilisée ✅';
            v_severity := 'success';
        when 'expired' then
            v_title := 'Récompense expirée';
            v_severity := 'warning';
        when 'cancelled' then
            v_title := 'Récompense annulée';
            v_severity := 'warning';
        else
            v_title := 'Récompense mise à jour';
            v_severity := 'info';
    end case;

    perform private.lumeni_create_activity(
        new.business_id,
        auth.uid(),
        new.customer_id,
        'reward_claim',
        new.id,
        v_action,
        v_title,
        format(
            'La récompense « %s » est maintenant au statut « %s ».',
            coalesce(v_reward_name, 'Récompense'),
            new.status
        ),
        jsonb_build_object(
            'previousStatus', old.status,
            'status', new.status,
            'redeemedAt', new.redeemed_at,
            'expiresAt', new.expires_at
        ),
        v_severity
    );

    return new;
end;
$$;

revoke all on function private.lumeni_after_reward_claim_status_change()
from public, anon, authenticated;

drop trigger if exists lumeni_30_reward_claims_status_activity
on public.reward_claims;

create trigger lumeni_30_reward_claims_status_activity
after update of status on public.reward_claims
for each row
when (old.status is distinct from new.status)
execute function private.lumeni_after_reward_claim_status_change();

-- ==========================================================
-- 8. Journal : création d'un client
-- ==========================================================

create or replace function private.lumeni_after_customer_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as
$$
begin
    perform private.lumeni_create_activity(
        new.business_id,
        coalesce(new.created_by, auth.uid()),
        new.id,
        'customer',
        new.id,
        'created',
        'Nouveau client 🎉',
        format(
            '%s a rejoint votre programme de fidélité.',
            new.full_name
        ),
        jsonb_build_object(
            'source', new.source,
            'marketingEmail', new.marketing_email,
            'marketingSms', new.marketing_sms,
            'marketingPush', new.marketing_push
        ),
        'success'
    );

    return new;
end;
$$;

revoke all on function private.lumeni_after_customer_insert()
from public, anon, authenticated;

drop trigger if exists lumeni_30_customers_created_activity
on public.customers;

create trigger lumeni_30_customers_created_activity
after insert on public.customers
for each row
execute function private.lumeni_after_customer_insert();

-- ==========================================================
-- 9. Vérifications finales des fonctions de trigger
-- ==========================================================

comment on trigger lumeni_10_visits_prepare
on public.visits is
'Prépare la visite et met à jour les agrégats du client.';

comment on trigger lumeni_20_visits_apply_loyalty
on public.visits is
'Applique la visite au programme et génère les récompenses.';

comment on trigger lumeni_10_reward_claims_prepare
on public.reward_claims is
'Valide le cycle de vie d’une récompense.';
