-- ==========================================================
-- Lumeni
-- 004_indexes.sql
--
-- Indexes d'unicité, de recherche et de performance.
--
-- Dépend de :
--   001_schema.sql
--   002_functions.sql
--   003_triggers.sql
-- ==========================================================

begin;

-- ==========================================================
-- 1. Extension de recherche approximative
--
-- pg_trgm accélère les recherches ILIKE et tolère les
-- recherches partielles sur les noms, emails et téléphones.
-- ==========================================================

create extension if not exists pg_trgm;

-- ==========================================================
-- 2. Unicité et normalisation logique
--
-- Les contraintes UNIQUE déjà créées dans 001_schema.sql
-- restent en place. Les index ci-dessous ajoutent les règles
-- insensibles à la casse sans modifier les contraintes dont
-- dépendent les UPSERT et les triggers existants.
-- ==========================================================

-- L'email d'un profil doit être unique indépendamment de la casse.
drop index if exists public.profiles_email_ci_uidx;

create unique index profiles_email_ci_uidx
    on public.profiles (lower(btrim(email)));

comment on index public.profiles_email_ci_uidx is
'Garantit l’unicité insensible à la casse des emails de profils.';

-- Un slug reste réservé même si le commerce est archivé, afin d'éviter
-- qu'une ancienne URL pointe ultérieurement vers un autre commerce.
drop index if exists public.businesses_slug_ci_uidx;

create unique index businesses_slug_ci_uidx
    on public.businesses (lower(slug));

comment on index public.businesses_slug_ci_uidx is
'Garantit l’unicité insensible à la casse des slugs de commerces.';

-- Un client actif ne peut utiliser qu'une fois le même email dans un commerce.
drop index if exists public.customers_active_business_email_ci_uidx;

create unique index customers_active_business_email_ci_uidx
    on public.customers (
        business_id,
        lower(btrim(email))
    )
    where deleted_at is null;

comment on index public.customers_active_business_email_ci_uidx is
'Empêche les doublons actifs d’email client dans un même commerce.';

-- Les noms de tags sont uniques dans un commerce, sans tenir compte de la casse.
-- L'index n'est pas partiel afin de rester cohérent avec la contrainte UNIQUE
-- définie dans 001_schema.sql, qui réserve aussi les noms archivés.
drop index if exists public.customer_tags_business_name_ci_uidx;

create unique index customer_tags_business_name_ci_uidx
    on public.customer_tags (
        business_id,
        lower(btrim(name))
    );

comment on index public.customer_tags_business_name_ci_uidx is
'Empêche les doublons de tags dans un commerce, sans tenir compte de la casse.';

-- Protection supplémentaire contre deux numéros identiques pour un client.
drop index if exists public.visits_customer_visit_number_uidx;

create unique index visits_customer_visit_number_uidx
    on public.visits (customer_id, visit_number)
    where visit_number is not null;

comment on index public.visits_customer_visit_number_uidx is
'Garantit l’unicité du numéro de visite pour chaque client.';

-- ==========================================================
-- 3. Profils et commerces
-- ==========================================================

drop index if exists public.profiles_active_full_name_idx;
create index profiles_active_full_name_idx
    on public.profiles (full_name)
    where deleted_at is null and active = true;

drop index if exists public.businesses_active_created_at_idx;
create index businesses_active_created_at_idx
    on public.businesses (created_at desc)
    where deleted_at is null;

-- ==========================================================
-- 4. Memberships et autorisations RLS
--
-- Ces index accélèrent les helpers :
--   private.lumeni_is_business_member(...)
--   private.lumeni_has_business_role(...)
-- ==========================================================

drop index if exists public.memberships_active_business_role_idx;
create index memberships_active_business_role_idx
    on public.memberships (business_id, role, profile_id)
    where deleted_at is null;

drop index if exists public.memberships_pending_invited_email_idx;
create index memberships_pending_invited_email_idx
    on public.memberships (lower(btrim(invited_email)))
    where deleted_at is null
      and accepted_at is null
      and invited_email is not null;

-- ==========================================================
-- 5. Récompenses et programmes
-- ==========================================================

drop index if exists public.reward_templates_business_active_idx;
create index reward_templates_business_active_idx
    on public.reward_templates (business_id, created_at desc)
    where deleted_at is null and active = true;

drop index if exists public.reward_templates_business_all_idx;
create index reward_templates_business_all_idx
    on public.reward_templates (business_id, created_at desc)
    where deleted_at is null;

-- Sélection du programme actif ayant la priorité la plus élevée.
drop index if exists public.loyalty_programs_business_active_priority_idx;
create index loyalty_programs_business_active_priority_idx
    on public.loyalty_programs (
        business_id,
        priority desc,
        created_at asc
    )
    where deleted_at is null and active = true;

drop index if exists public.loyalty_programs_reward_template_idx;
create index loyalty_programs_reward_template_idx
    on public.loyalty_programs (reward_template_id)
    where deleted_at is null and reward_template_id is not null;

-- ==========================================================
-- 6. Clients
-- ==========================================================

-- Listes principales du dashboard et du CRM.
drop index if exists public.customers_business_created_at_idx;
create index customers_business_created_at_idx
    on public.customers (business_id, created_at desc)
    where deleted_at is null;

drop index if exists public.customers_business_status_last_visit_idx;
create index customers_business_status_last_visit_idx
    on public.customers (
        business_id,
        status,
        last_visit_at desc nulls last
    )
    where deleted_at is null;

drop index if exists public.customers_business_favorites_idx;
create index customers_business_favorites_idx
    on public.customers (
        business_id,
        total_visits desc,
        last_visit_at desc nulls last
    )
    where deleted_at is null and favorite = true;

-- Hall of Fame et classements.
drop index if exists public.customers_business_ranking_idx;
create index customers_business_ranking_idx
    on public.customers (
        business_id,
        total_visits desc,
        total_rewards desc,
        created_at asc
    )
    where deleted_at is null and status <> 'blocked';

-- Anniversaires du jour ou d'une période donnée.
drop index if exists public.customers_business_birthday_idx;
create index customers_business_birthday_idx
    on public.customers (
        business_id,
        (extract(month from birth_date)),
        (extract(day from birth_date))
    )
    where deleted_at is null
      and status = 'active'
      and birth_date is not null;

-- Recherche CRM par nom, email ou téléphone.
drop index if exists public.customers_full_name_trgm_idx;
create index customers_full_name_trgm_idx
    on public.customers
    using gin (full_name gin_trgm_ops)
    where deleted_at is null;

drop index if exists public.customers_email_trgm_idx;
create index customers_email_trgm_idx
    on public.customers
    using gin (email gin_trgm_ops)
    where deleted_at is null;

drop index if exists public.customers_phone_trgm_idx;
create index customers_phone_trgm_idx
    on public.customers
    using gin (phone gin_trgm_ops)
    where deleted_at is null and phone is not null;

-- ==========================================================
-- 7. Progression fidélité
-- ==========================================================

drop index if exists public.customer_loyalty_accounts_business_customer_idx;
create index customer_loyalty_accounts_business_customer_idx
    on public.customer_loyalty_accounts (
        business_id,
        customer_id,
        last_activity_at desc nulls last
    )
    where deleted_at is null;

drop index if exists public.customer_loyalty_accounts_program_ranking_idx;
create index customer_loyalty_accounts_program_ranking_idx
    on public.customer_loyalty_accounts (
        loyalty_program_id,
        completed_cycles desc,
        lifetime_visits desc,
        lifetime_points desc
    )
    where deleted_at is null;

-- ==========================================================
-- 8. Visites
-- ==========================================================

-- Statistiques par commerce et période.
drop index if exists public.visits_business_created_at_idx;
create index visits_business_created_at_idx
    on public.visits (business_id, created_at desc);

-- Historique d'un client et calcul de sa fréquence.
drop index if exists public.visits_customer_created_at_idx;
create index visits_customer_created_at_idx
    on public.visits (customer_id, created_at desc);

-- Statistiques par programme.
drop index if exists public.visits_program_created_at_idx;
create index visits_program_created_at_idx
    on public.visits (loyalty_program_id, created_at desc)
    where loyalty_program_id is not null;

-- Activité d'un employé.
drop index if exists public.visits_employee_created_at_idx;
create index visits_employee_created_at_idx
    on public.visits (employee_id, created_at desc)
    where employee_id is not null;

-- ==========================================================
-- 9. Récompenses obtenues
-- ==========================================================

-- Compteurs et listes par commerce.
drop index if exists public.reward_claims_business_status_created_idx;
create index reward_claims_business_status_created_idx
    on public.reward_claims (
        business_id,
        status,
        created_at desc
    )
    where deleted_at is null;

-- Historique d'un client.
drop index if exists public.reward_claims_customer_created_idx;
create index reward_claims_customer_created_idx
    on public.reward_claims (
        customer_id,
        created_at desc
    )
    where deleted_at is null;

-- Récompenses disponibles ou arrivant bientôt à expiration.
drop index if exists public.reward_claims_available_expiry_idx;
create index reward_claims_available_expiry_idx
    on public.reward_claims (
        business_id,
        expires_at,
        created_at desc
    )
    where deleted_at is null and status = 'available';

-- Recherche depuis la visite ou le programme d'origine.
drop index if exists public.reward_claims_visit_idx;
create index reward_claims_visit_idx
    on public.reward_claims (visit_id)
    where visit_id is not null and deleted_at is null;

drop index if exists public.reward_claims_program_created_idx;
create index reward_claims_program_created_idx
    on public.reward_claims (loyalty_program_id, created_at desc)
    where loyalty_program_id is not null and deleted_at is null;

-- ==========================================================
-- 10. Journal d'activité
-- ==========================================================

-- Fil principal du Journal du commerce.
drop index if exists public.activity_logs_business_visible_created_idx;
create index activity_logs_business_visible_created_idx
    on public.activity_logs (business_id, created_at desc)
    where visible = true;

-- Historique d'un client.
drop index if exists public.activity_logs_customer_created_idx;
create index activity_logs_customer_created_idx
    on public.activity_logs (customer_id, created_at desc)
    where customer_id is not null;

-- Audit d'une entité métier précise.
drop index if exists public.activity_logs_entity_idx;
create index activity_logs_entity_idx
    on public.activity_logs (business_id, entity, entity_id, created_at desc)
    where entity_id is not null;

-- Recherche structurée dans les métadonnées, utile plus tard pour l'IA
-- et les événements métier avancés.
drop index if exists public.activity_logs_metadata_gin_idx;
create index activity_logs_metadata_gin_idx
    on public.activity_logs
    using gin (metadata jsonb_path_ops);

-- ==========================================================
-- 11. Tags clients
-- ==========================================================

-- La clé primaire couvre déjà (customer_id, tag_id).
-- Cet index couvre le sens inverse : tag -> clients.
drop index if exists public.customer_tag_assignments_tag_customer_idx;
create index customer_tag_assignments_tag_customer_idx
    on public.customer_tag_assignments (tag_id, customer_id);

drop index if exists public.customer_tags_business_name_idx;
create index customer_tags_business_name_idx
    on public.customer_tags (business_id, name)
    where deleted_at is null;

commit;
