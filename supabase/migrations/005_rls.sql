-- ==========================================================
-- Lumeni
-- 005_rls.sql
--
-- Isolation multi-commerce, droits par rôle et permissions
-- explicites pour l'API Supabase.
--
-- Rôles métier :
--   owner    : contrôle complet du commerce ;
--   admin    : administration opérationnelle ;
--   employee : clients, visites, récompenses et tags associés.
--
-- Dépend de :
--   001_schema.sql
--   002_functions.sql
--   003_triggers.sql
--   004_indexes.sql
-- ==========================================================

begin;

-- ==========================================================
-- 1. Helpers RLS supplémentaires
--
-- Ces fonctions sont SECURITY DEFINER afin d'éviter les
-- récursions de politiques sur memberships et customers.
-- Elles n'accordent aucun droit d'écriture.
-- ==========================================================

create or replace function private.lumeni_shares_business(
    p_profile_id uuid
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
        from public.memberships target_membership
        join public.memberships current_membership
          on current_membership.business_id = target_membership.business_id
        where target_membership.profile_id = p_profile_id
          and target_membership.deleted_at is null
          and current_membership.profile_id = auth.uid()
          and current_membership.deleted_at is null
    );
$$;

comment on function private.lumeni_shares_business(uuid) is
'Vérifie que le profil demandé partage au moins un commerce avec l’utilisateur connecté.';

create or replace function private.lumeni_can_access_customer(
    p_customer_id uuid,
    p_roles text[] default null
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
        from public.customers c
        join public.memberships m
          on m.business_id = c.business_id
        where c.id = p_customer_id
          and c.deleted_at is null
          and m.profile_id = auth.uid()
          and m.deleted_at is null
          and (
              p_roles is null
              or m.role = any(p_roles)
          )
    );
$$;

comment on function private.lumeni_can_access_customer(uuid, text[]) is
'Vérifie l’accès de l’utilisateur connecté à un client, avec filtre de rôles facultatif.';

revoke all on function private.lumeni_shares_business(uuid)
from public, anon, authenticated;

revoke all on function private.lumeni_can_access_customer(uuid, text[])
from public, anon, authenticated;

grant execute on function private.lumeni_shares_business(uuid)
to authenticated;

grant execute on function private.lumeni_can_access_customer(uuid, text[])
to authenticated;

-- ==========================================================
-- 2. Activation du Row Level Security
-- ==========================================================

alter table public.profiles enable row level security;
alter table public.businesses enable row level security;
alter table public.memberships enable row level security;
alter table public.reward_templates enable row level security;
alter table public.loyalty_programs enable row level security;
alter table public.customers enable row level security;
alter table public.customer_loyalty_accounts enable row level security;
alter table public.visits enable row level security;
alter table public.reward_claims enable row level security;
alter table public.activity_logs enable row level security;
alter table public.customer_tags enable row level security;
alter table public.customer_tag_assignments enable row level security;

-- ==========================================================
-- 3. Suppression des privilèges implicites
--
-- Le rôle anon ne doit accéder à aucune donnée métier.
-- authenticated ne reçoit ensuite que les colonnes et
-- opérations réellement nécessaires au frontend.
-- ==========================================================

revoke all on table public.profiles
from public, anon, authenticated;

revoke all on table public.businesses
from public, anon, authenticated;

revoke all on table public.memberships
from public, anon, authenticated;

revoke all on table public.reward_templates
from public, anon, authenticated;

revoke all on table public.loyalty_programs
from public, anon, authenticated;

revoke all on table public.customers
from public, anon, authenticated;

revoke all on table public.customer_loyalty_accounts
from public, anon, authenticated;

revoke all on table public.visits
from public, anon, authenticated;

revoke all on table public.reward_claims
from public, anon, authenticated;

revoke all on table public.activity_logs
from public, anon, authenticated;

revoke all on table public.customer_tags
from public, anon, authenticated;

revoke all on table public.customer_tag_assignments
from public, anon, authenticated;

grant usage on schema public to authenticated;
grant usage on schema private to authenticated;

-- ==========================================================
-- 4. Privilèges de colonnes
-- ==========================================================

-- Profils : lecture, puis modification de son identité produit.
grant select on table public.profiles
to authenticated;

grant update (
    first_name,
    last_name,
    avatar_url,
    job_title,
    phone,
    preferred_language,
    onboarding_completed,
    last_login_at,
    active
)
on public.profiles
to authenticated;

-- Commerces : les champs d'abonnement restent contrôlés par
-- le backend de facturation, jamais directement par le client.
grant select on table public.businesses
to authenticated;

grant update (
    name,
    slug,
    industry,
    logo_url,
    timezone,
    currency,
    settings
)
on public.businesses
to authenticated;

-- Memberships : invitation_token n'est volontairement pas
-- lisible depuis l'API cliente.
grant select (
    id,
    profile_id,
    business_id,
    role,
    invited_email,
    invitation_expires_at,
    accepted_at,
    created_at,
    updated_at,
    deleted_at
)
on public.memberships
to authenticated;

grant insert (
    profile_id,
    business_id,
    role,
    invited_email,
    invitation_token,
    invitation_expires_at,
    accepted_at
)
on public.memberships
to authenticated;

grant update (
    role,
    invited_email,
    invitation_token,
    invitation_expires_at,
    accepted_at,
    deleted_at
)
on public.memberships
to authenticated;

-- Catalogue de récompenses.
grant select on table public.reward_templates
to authenticated;

grant insert (
    business_id,
    name,
    description,
    reward_type,
    reward_value,
    validity_days,
    active
)
on public.reward_templates
to authenticated;

grant update (
    name,
    description,
    reward_type,
    reward_value,
    validity_days,
    active,
    deleted_at
)
on public.reward_templates
to authenticated;

-- Programmes de fidélité.
grant select on table public.loyalty_programs
to authenticated;

grant insert (
    business_id,
    reward_template_id,
    name,
    description,
    mode,
    target,
    active,
    priority,
    starts_at,
    ends_at
)
on public.loyalty_programs
to authenticated;

grant update (
    reward_template_id,
    name,
    description,
    mode,
    target,
    active,
    priority,
    starts_at,
    ends_at,
    deleted_at
)
on public.loyalty_programs
to authenticated;

-- Clients : les agrégats sont exclusivement mis à jour par
-- les triggers, jamais par le frontend.
grant select on table public.customers
to authenticated;

grant insert (
    business_id,
    first_name,
    last_name,
    email,
    phone,
    birth_date,
    preferred_language,
    notes_public,
    notes_private,
    accepted_terms_at,
    marketing_email,
    marketing_sms,
    marketing_push,
    status,
    favorite,
    source
)
on public.customers
to authenticated;

grant update (
    first_name,
    last_name,
    email,
    phone,
    birth_date,
    preferred_language,
    notes_public,
    notes_private,
    accepted_terms_at,
    marketing_email,
    marketing_sms,
    marketing_push,
    status,
    favorite,
    source,
    last_seen_at
)
on public.customers
to authenticated;

-- Progression : lecture seule depuis le client.
grant select on table public.customer_loyalty_accounts
to authenticated;

-- Visites : historique immuable. Les corrections et imports
-- seront réalisés plus tard via des RPC dédiées.
grant select on table public.visits
to authenticated;

grant insert (
    customer_id,
    employee_id,
    loyalty_program_id,
    points_earned,
    visit_source,
    notes
)
on public.visits
to authenticated;

-- Récompenses : le frontend peut uniquement changer le statut.
grant select on table public.reward_claims
to authenticated;

grant update (status)
on public.reward_claims
to authenticated;

-- Journal : lecture seule depuis le client.
grant select on table public.activity_logs
to authenticated;

-- Tags : catalogue administré par owner/admin.
grant select on table public.customer_tags
to authenticated;

grant insert (
    business_id,
    name,
    color,
    icon
)
on public.customer_tags
to authenticated;

grant update (
    name,
    color,
    icon,
    deleted_at
)
on public.customer_tags
to authenticated;

-- Affectations de tags : tous les membres peuvent ajouter ou
-- retirer un tag d'un client accessible.
grant select on table public.customer_tag_assignments
to authenticated;

grant insert (customer_id, tag_id)
on public.customer_tag_assignments
to authenticated;

grant delete on table public.customer_tag_assignments
to authenticated;

-- Séquence de customer_number, si PostgreSQL exige son usage
-- explicite pour la colonne identity dans l'environnement cible.
do
$$
declare
    v_sequence_name text;
begin
    select pg_get_serial_sequence(
        'public.customers',
        'customer_number'
    )
    into v_sequence_name;

    if v_sequence_name is not null then
        execute format(
            'grant usage, select on sequence %s to authenticated',
            v_sequence_name
        );
    end if;
end;
$$;

-- ==========================================================
-- 5. Policies : profiles
-- ==========================================================

drop policy if exists profiles_select_shared_business
on public.profiles;

create policy profiles_select_shared_business
on public.profiles
for select
to authenticated
using (
    id = auth.uid()
    or private.lumeni_shares_business(id)
);

drop policy if exists profiles_update_own
on public.profiles;

create policy profiles_update_own
on public.profiles
for update
to authenticated
using (
    id = auth.uid()
)
with check (
    id = auth.uid()
);

-- ==========================================================
-- 6. Policies : businesses
-- ==========================================================

drop policy if exists businesses_select_members
on public.businesses;

create policy businesses_select_members
on public.businesses
for select
to authenticated
using (
    private.lumeni_is_business_member(id)
);

drop policy if exists businesses_update_owner_admin
on public.businesses;

create policy businesses_update_owner_admin
on public.businesses
for update
to authenticated
using (
    private.lumeni_has_business_role(
        id,
        array['owner', 'admin']::text[]
    )
)
with check (
    private.lumeni_has_business_role(
        id,
        array['owner', 'admin']::text[]
    )
);

-- Aucun INSERT direct : public.lumeni_create_business(...)
-- réalise la création atomique et sécurisée.

-- ==========================================================
-- 7. Policies : memberships
-- ==========================================================

drop policy if exists memberships_select_business_members
on public.memberships;

create policy memberships_select_business_members
on public.memberships
for select
to authenticated
using (
    profile_id = auth.uid()
    or private.lumeni_is_business_member(business_id)
);

drop policy if exists memberships_insert_owner_admin
on public.memberships;

create policy memberships_insert_owner_admin
on public.memberships
for insert
to authenticated
with check (
    (
        private.lumeni_has_business_role(
            business_id,
            array['owner']::text[]
        )
    )
    or
    (
        role <> 'owner'
        and private.lumeni_has_business_role(
            business_id,
            array['admin']::text[]
        )
    )
);

drop policy if exists memberships_update_owner_admin
on public.memberships;

create policy memberships_update_owner_admin
on public.memberships
for update
to authenticated
using (
    private.lumeni_has_business_role(
        business_id,
        array['owner']::text[]
    )
    or
    (
        role <> 'owner'
        and private.lumeni_has_business_role(
            business_id,
            array['admin']::text[]
        )
    )
)
with check (
    private.lumeni_has_business_role(
        business_id,
        array['owner']::text[]
    )
    or
    (
        role <> 'owner'
        and private.lumeni_has_business_role(
            business_id,
            array['admin']::text[]
        )
    )
);

-- Aucun DELETE direct : une suppression d'accès utilise
-- deleted_at afin de conserver l'historique d'équipe.

-- ==========================================================
-- 8. Policies : reward_templates
-- ==========================================================

drop policy if exists reward_templates_select_members
on public.reward_templates;

create policy reward_templates_select_members
on public.reward_templates
for select
to authenticated
using (
    private.lumeni_is_business_member(business_id)
);

drop policy if exists reward_templates_insert_owner_admin
on public.reward_templates;

create policy reward_templates_insert_owner_admin
on public.reward_templates
for insert
to authenticated
with check (
    private.lumeni_has_business_role(
        business_id,
        array['owner', 'admin']::text[]
    )
);

drop policy if exists reward_templates_update_owner_admin
on public.reward_templates;

create policy reward_templates_update_owner_admin
on public.reward_templates
for update
to authenticated
using (
    private.lumeni_has_business_role(
        business_id,
        array['owner', 'admin']::text[]
    )
)
with check (
    private.lumeni_has_business_role(
        business_id,
        array['owner', 'admin']::text[]
    )
);

-- ==========================================================
-- 9. Policies : loyalty_programs
-- ==========================================================

drop policy if exists loyalty_programs_select_members
on public.loyalty_programs;

create policy loyalty_programs_select_members
on public.loyalty_programs
for select
to authenticated
using (
    private.lumeni_is_business_member(business_id)
);

drop policy if exists loyalty_programs_insert_owner_admin
on public.loyalty_programs;

create policy loyalty_programs_insert_owner_admin
on public.loyalty_programs
for insert
to authenticated
with check (
    private.lumeni_has_business_role(
        business_id,
        array['owner', 'admin']::text[]
    )
);

drop policy if exists loyalty_programs_update_owner_admin
on public.loyalty_programs;

create policy loyalty_programs_update_owner_admin
on public.loyalty_programs
for update
to authenticated
using (
    private.lumeni_has_business_role(
        business_id,
        array['owner', 'admin']::text[]
    )
)
with check (
    private.lumeni_has_business_role(
        business_id,
        array['owner', 'admin']::text[]
    )
);

-- ==========================================================
-- 10. Policies : customers
-- ==========================================================

drop policy if exists customers_select_members
on public.customers;

create policy customers_select_members
on public.customers
for select
to authenticated
using (
    private.lumeni_is_business_member(business_id)
);

drop policy if exists customers_insert_members
on public.customers;

create policy customers_insert_members
on public.customers
for insert
to authenticated
with check (
    private.lumeni_is_business_member(business_id)
);

drop policy if exists customers_update_members
on public.customers;

create policy customers_update_members
on public.customers
for update
to authenticated
using (
    private.lumeni_is_business_member(business_id)
)
with check (
    private.lumeni_is_business_member(business_id)
);

-- Aucun DELETE direct : la suppression RGPD et l'archivage
-- seront encapsulés dans des RPC auditées.

-- ==========================================================
-- 11. Policies : customer_loyalty_accounts
-- ==========================================================

drop policy if exists customer_loyalty_accounts_select_members
on public.customer_loyalty_accounts;

create policy customer_loyalty_accounts_select_members
on public.customer_loyalty_accounts
for select
to authenticated
using (
    private.lumeni_is_business_member(business_id)
);

-- Aucun droit d'écriture direct. Les triggers de visites sont
-- les seuls responsables de cette table.

-- ==========================================================
-- 12. Policies : visits
-- ==========================================================

drop policy if exists visits_select_members
on public.visits;

create policy visits_select_members
on public.visits
for select
to authenticated
using (
    private.lumeni_is_business_member(business_id)
);

drop policy if exists visits_insert_members
on public.visits;

create policy visits_insert_members
on public.visits
for insert
to authenticated
with check (
    private.lumeni_is_business_member(business_id)
    and employee_id = auth.uid()
);

-- Aucun UPDATE ou DELETE direct : une visite validée est un
-- événement métier immuable.

-- ==========================================================
-- 13. Policies : reward_claims
-- ==========================================================

drop policy if exists reward_claims_select_members
on public.reward_claims;

create policy reward_claims_select_members
on public.reward_claims
for select
to authenticated
using (
    private.lumeni_is_business_member(business_id)
);

drop policy if exists reward_claims_update_members
on public.reward_claims;

create policy reward_claims_update_members
on public.reward_claims
for update
to authenticated
using (
    private.lumeni_is_business_member(business_id)
)
with check (
    private.lumeni_is_business_member(business_id)
);

-- Le GRANT de colonnes limite cet UPDATE au seul champ status.
-- Le trigger valide ensuite les transitions possibles.

-- ==========================================================
-- 14. Policies : activity_logs
-- ==========================================================

drop policy if exists activity_logs_select_members
on public.activity_logs;

create policy activity_logs_select_members
on public.activity_logs
for select
to authenticated
using (
    private.lumeni_is_business_member(business_id)
    and (
        visible = true
        or private.lumeni_has_business_role(
            business_id,
            array['owner', 'admin']::text[]
        )
    )
);

-- Aucun droit d'écriture direct. Le journal est alimenté par
-- private.lumeni_create_activity(...) et les triggers.

-- ==========================================================
-- 15. Policies : customer_tags
-- ==========================================================

drop policy if exists customer_tags_select_members
on public.customer_tags;

create policy customer_tags_select_members
on public.customer_tags
for select
to authenticated
using (
    private.lumeni_is_business_member(business_id)
);

drop policy if exists customer_tags_insert_owner_admin
on public.customer_tags;

create policy customer_tags_insert_owner_admin
on public.customer_tags
for insert
to authenticated
with check (
    private.lumeni_has_business_role(
        business_id,
        array['owner', 'admin']::text[]
    )
);

drop policy if exists customer_tags_update_owner_admin
on public.customer_tags;

create policy customer_tags_update_owner_admin
on public.customer_tags
for update
to authenticated
using (
    private.lumeni_has_business_role(
        business_id,
        array['owner', 'admin']::text[]
    )
)
with check (
    private.lumeni_has_business_role(
        business_id,
        array['owner', 'admin']::text[]
    )
);

-- ==========================================================
-- 16. Policies : customer_tag_assignments
-- ==========================================================

drop policy if exists customer_tag_assignments_select_members
on public.customer_tag_assignments;

create policy customer_tag_assignments_select_members
on public.customer_tag_assignments
for select
to authenticated
using (
    private.lumeni_can_access_customer(customer_id)
);

drop policy if exists customer_tag_assignments_insert_members
on public.customer_tag_assignments;

create policy customer_tag_assignments_insert_members
on public.customer_tag_assignments
for insert
to authenticated
with check (
    private.lumeni_can_access_customer(customer_id)
);

drop policy if exists customer_tag_assignments_delete_members
on public.customer_tag_assignments;

create policy customer_tag_assignments_delete_members
on public.customer_tag_assignments
for delete
to authenticated
using (
    private.lumeni_can_access_customer(customer_id)
);

commit;
