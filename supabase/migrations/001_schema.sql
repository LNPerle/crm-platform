-- ==========================================================
-- Lumeni
-- 001_schema.sql
--
-- Description :
-- Schéma principal de la base de données Lumeni.
--
-- Contient :
-- - Extensions
-- - Profiles
-- - Businesses
-- - Memberships
--
-- Les fonctions, triggers, index et policies RLS sont
-- définis dans les fichiers suivants.
-- ==========================================================

create extension if not exists "pgcrypto";

create extension if not exists unaccent
    with schema public;

-- ==========================================================
-- Profiles
--
-- Représente un utilisateur authentifié.
-- Un profil correspond à un utilisateur Supabase Auth.
--
-- Relation :
-- auth.users (1) ---- (1) profiles
-- ==========================================================

create table public.profiles (

    id uuid primary key
        references auth.users(id)
        on delete cascade,

    first_name text,

    last_name text,

    email text not null unique,

    avatar_url text,

    last_login_at timestamptz,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    deleted_at timestamptz

);

comment on table public.profiles is
'Utilisateurs de Lumeni.';

comment on column public.profiles.avatar_url is
'Avatar du commerçant.';

-- ==========================================================
-- Businesses
--
-- Représente un commerce.
--
-- Un commerce possède :
-- - des clients
-- - des programmes de fidélité
-- - des récompenses
-- - des statistiques
--
-- Un utilisateur peut appartenir à plusieurs commerces.
-- ==========================================================

create table public.businesses (

    id uuid primary key
        default gen_random_uuid(),

    name text not null,

    slug text not null unique,

    industry text not null,

    description text,

    welcome_message text,

    theme_color text
        not null
        default '#4F46E5',

    logo_url text,

    website text,

    instagram_url text,

    facebook_url text,

    google_business_url text,

    email text,

    phone text,

    address text,

    city text,

    postal_code text,

    country text
        not null
        default 'France',

    timezone text
        not null
        default 'Europe/Paris',

    currency text
        not null
        default 'EUR',

    launch_completed boolean
        not null
        default false,

    subscription_status text
        not null
        default 'trial',

    trial_ends_at timestamptz,

    plan text
        not null
        default 'starter',

    created_at timestamptz
        not null
        default now(),

    updated_at timestamptz
        not null
        default now(),

    deleted_at timestamptz,

    constraint businesses_subscription_status_check
        check (
            subscription_status in (
                'trial',
                'active',
                'cancelled',
                'expired'
            )
        ),

    updated_at timestamptz
        not null
        default now(),

    deleted_at timestamptz,

    is_demo boolean
        not null
        default false,

    locale text
        not null
        default 'fr',

    constraint businesses_subscription_status_check
        check (
            subscription_status in (
                'trial',
                'active',
                'cancelled',
                'expired'
            )
        )
);

comment on table public.businesses is
'Commerces utilisant Lumeni.';

comment on column public.businesses.launch_completed is
'Assistant de démarrage terminé.';

-- ==========================================================
-- Memberships
--
-- Relation entre un utilisateur et un commerce.
--
-- Un utilisateur peut appartenir à plusieurs commerces.
--
-- owner
-- manager
-- employee
-- ==========================================================

create table public.memberships (

    id uuid primary key
        default gen_random_uuid(),

    profile_id uuid
        not null
        references public.profiles(id)
        on delete cascade,

    business_id uuid
        not null
        references public.businesses(id)
        on delete cascade,

    role text
        not null
        default 'owner',

    invited_by uuid
        references public.profiles(id)
        on delete set null,

    accepted_at timestamptz,

    created_at timestamptz
        not null
        default now(),

    updated_at timestamptz
        not null
        default now(),

    deleted_at timestamptz,

    constraint memberships_unique
        unique (
            profile_id,
            business_id
        ),

    constraint memberships_role_check
        check (
            role in (
                'owner',
                'manager',
                'employee'
            )
        )

);

comment on table public.memberships is
'Association entre les utilisateurs et les commerces.';

comment on column public.memberships.role is
'Rôle du membre dans le commerce.';

-- ==========================================================
-- Reward Templates
--
-- Catalogue des récompenses disponibles pour un commerce.
--
-- Une récompense peut être utilisée dans plusieurs
-- programmes de fidélité.
-- ==========================================================

create table public.reward_templates (

    id uuid primary key
        default gen_random_uuid(),

    business_id uuid
        not null
        references public.businesses(id)
        on delete cascade,

    name text
        not null,

    description text,

    reward_type text
        not null
        default 'gift',

    reward_value integer,

    validity_days integer
        not null
        default 90,

    active boolean
        not null
        default true,

    created_at timestamptz
        not null
        default now(),

    updated_at timestamptz
        not null
        default now(),

    deleted_at timestamptz,

    constraint reward_templates_type_check
        check (
            reward_type in (
                'gift',
                'discount',
                'free_product',
                'points'
            )
        ),

    constraint reward_templates_validity_check
        check (
            validity_days > 0
        )

);

comment on table public.reward_templates is
'Catalogue des récompenses proposées par un commerce.';

comment on column public.reward_templates.reward_type is
'Type de récompense.';

-- ==========================================================
-- Loyalty Programs
--
-- Programme de fidélité associé à un commerce.
--
-- Exemples :
--
-- 10 visites -> Café offert
--
-- 100 points -> -10%
--
-- ==========================================================

create table public.loyalty_programs (

    id uuid primary key
        default gen_random_uuid(),

    business_id uuid
        not null
        references public.businesses(id)
        on delete cascade,

    reward_template_id uuid
        references public.reward_templates(id)
        on delete set null,

    name text
        not null,

    description text,

    mode text
        not null,

    target integer
        not null,

    active boolean
        not null
        default true,

    priority integer
        not null
        default 1,

    starts_at timestamptz,

    ends_at timestamptz,

    created_at timestamptz
        not null
        default now(),

    updated_at timestamptz
        not null
        default now(),

    deleted_at timestamptz,

    constraint loyalty_programs_mode_check
        check (
            mode in (
                'visits',
                'points'
            )
        ),

    constraint loyalty_programs_target_check
        check (
            target > 0
        ),

    constraint loyalty_programs_dates_check
        check (
            starts_at is null
            or ends_at is null
            or starts_at < ends_at
        )

);

comment on table public.loyalty_programs is
'Programmes de fidélité des commerces.';

-- ==========================================================
-- Customers
--
-- Représente un client appartenant à un commerce.
--
-- Cette table contient les informations du client ainsi
-- que des statistiques calculées afin d'éviter des requêtes
-- coûteuses lors de l'affichage du dashboard.
--
-- Les visites sont historisées dans la table visits.
-- ==========================================================

create table public.customers (

    id uuid primary key
        default gen_random_uuid(),

    business_id uuid
        not null
        references public.businesses(id)
        on delete cascade,

    qr_token uuid
        not null
        default gen_random_uuid()
        unique,

    customer_number bigint
        generated always as identity,

    first_name text
        not null,

    last_name text,

    full_name text
        generated always as (
            trim(first_name || ' ' || coalesce(last_name, ''))
        ) stored,

    email text
        not null,

    phone text,

    birth_date date,

    preferred_language text
        not null
        default 'fr',

    notes_public text,

    notes_private text,

    accepted_terms_at timestamptz,

    marketing_email boolean
        not null
        default false,

    marketing_sms boolean
        not null
        default false,

    marketing_push boolean
        not null
        default false,

    status text
        not null
        default 'active',

    favorite boolean
        not null
        default false,

    source text,

    first_visit_at timestamptz,

    last_visit_at timestamptz,

    last_reward_at timestamptz,

    total_visits integer
        not null
        default 0,

    total_points integer
        not null
        default 0,

    lifetime_points integer
        not null
        default 0,

    total_rewards integer
        not null
        default 0,

    average_days_between_visits numeric(6,2),

    last_seen_at timestamptz,

    created_by uuid
        references public.profiles(id)
        on delete set null,

    updated_by uuid
        references public.profiles(id)
        on delete set null,

    created_at timestamptz
        not null
        default now(),

    updated_at timestamptz
        not null
        default now(),

    deleted_at timestamptz,

    constraint customers_status_check
        check (
            status in (
                'active',
                'inactive',
                'blocked'
            )
        )

);

comment on table public.customers is
'Clients appartenant à un commerce.';

comment on column public.customers.favorite is
'Permet de mettre un client en favori.';

-- ==========================================================
-- Customer Loyalty Accounts
--
-- Progression d'un client dans un programme de fidélité.
--
-- Cette table permet à un même client de participer à
-- plusieurs programmes sans mélanger ses progressions.
-- ==========================================================

create table public.customer_loyalty_accounts (

    id uuid primary key
        default gen_random_uuid(),

    business_id uuid
        not null
        references public.businesses(id)
        on delete cascade,

    customer_id uuid
        not null
        references public.customers(id)
        on delete cascade,

    loyalty_program_id uuid
        not null
        references public.loyalty_programs(id)
        on delete cascade,

    current_visits integer
        not null
        default 0,

    current_points integer
        not null
        default 0,

    lifetime_visits integer
        not null
        default 0,

    lifetime_points integer
        not null
        default 0,

    completed_cycles integer
        not null
        default 0,

    last_activity_at timestamptz,

    created_at timestamptz
        not null
        default now(),

    updated_at timestamptz
        not null
        default now(),

    deleted_at timestamptz,

    constraint customer_loyalty_accounts_unique
        unique (
            customer_id,
            loyalty_program_id
        ),

    constraint customer_loyalty_accounts_values_check
        check (
            current_visits >= 0
            and current_points >= 0
            and lifetime_visits >= 0
            and lifetime_points >= 0
            and completed_cycles >= 0
        )

);

comment on table public.customer_loyalty_accounts is
'Progression des clients dans chaque programme de fidélité.';

comment on column
    public.customer_loyalty_accounts.completed_cycles is
'Nombre de cycles de fidélité terminés par le client dans ce programme.';

-- ==========================================================
-- Visits
--
-- Historique complet des visites.
--
-- Aucune visite n'est supprimée afin de conserver
-- l'historique du commerce.
-- ==========================================================

create table public.visits (

    id uuid primary key
        default gen_random_uuid(),

    business_id uuid
        not null
        references public.businesses(id)
        on delete cascade,

    customer_id uuid
        not null
        references public.customers(id)
        on delete cascade,

    employee_id uuid
        references public.profiles(id)
        on delete set null,

    loyalty_program_id uuid
        references public.loyalty_programs(id)
        on delete set null,

    points_earned integer
        not null
        default 0,

    visit_number integer,

    visit_source text
        not null
        default 'dashboard',

    notes text,

    created_at timestamptz
        not null
        default now(),

    constraint visits_source_check
        check (
            visit_source in (
                'dashboard',
                'qr_code',
                'mobile',
                'import',
                'api'
            )
        )

);

comment on table public.visits is
'Historique des visites des clients.';

-- ==========================================================
-- Reward Claims
--
-- Historique des récompenses gagnées par les clients.
--
-- Une récompense reste historisée même après son utilisation
-- afin de conserver un historique complet.
-- ==========================================================

create table public.reward_claims (

    id uuid primary key
        default gen_random_uuid(),

    business_id uuid
        not null
        references public.businesses(id)
        on delete cascade,

    customer_id uuid
        not null
        references public.customers(id)
        on delete cascade,

    reward_template_id uuid
        not null
        references public.reward_templates(id)
        on delete restrict,

    loyalty_program_id uuid
        references public.loyalty_programs(id)
        on delete set null,

    visit_id uuid
        references public.visits(id)
        on delete set null,

    status text
        not null
        default 'available',

    expires_at timestamptz,

    redeemed_at timestamptz,

    created_at timestamptz
        not null
        default now(),

    updated_at timestamptz
        not null
        default now(),

    deleted_at timestamptz,

    constraint reward_claims_status_check
        check (
            status in (
                'available',
                'redeemed',
                'expired',
                'cancelled'
            )
        )

);

comment on table public.reward_claims is
'Historique des récompenses obtenues par les clients.';

-- ==========================================================
-- Activity Logs
--
-- Journal interne des événements du commerce.
--
-- Cette table servira notamment à :
--
-- • Journal du commerce
-- • Hall of Fame
-- • IA
-- • Statistiques
-- • Audit
-- ==========================================================

create table public.activity_logs (

    id uuid primary key
        default gen_random_uuid(),

    business_id uuid
        not null
        references public.businesses(id)
        on delete cascade,

    profile_id uuid
        references public.profiles(id)
        on delete set null,

    customer_id uuid
        references public.customers(id)
        on delete set null,

    entity text
        not null,

    entity_id uuid,

    action text
        not null,

    title text
        not null,

    description text,

    metadata jsonb
        not null
        default '{}'::jsonb,

    severity text
        not null
        default 'info',

    visible boolean
        not null
        default true,

    created_at timestamptz
        not null
        default now(),

    constraint activity_logs_severity_check
        check (
            severity in (
                'info',
                'success',
                'warning',
                'error'
            )
        )

);

comment on table public.activity_logs is
'Journal des événements du commerce.';

-- ==========================================================
-- Customer Tags
--
-- Tags personnalisés créés par un commerce.
-- ==========================================================

create table public.customer_tags (

    id uuid primary key
        default gen_random_uuid(),

    business_id uuid
        not null
        references public.businesses(id)
        on delete cascade,

    name text
        not null,

    color text
        not null
        default '#6366F1',

    icon text,

    created_at timestamptz
        not null
        default now(),

    updated_at timestamptz
        not null
        default now(),

    deleted_at timestamptz,

    constraint customer_tags_unique
        unique (business_id, name)

);

comment on table public.customer_tags is
'Tags personnalisés des clients.';


-- ==========================================================
-- Customer Tag Assignments
--
-- Relation plusieurs-à-plusieurs entre les clients
-- et les tags d'un commerce.
-- ==========================================================

create table public.customer_tag_assignments (

    customer_id uuid
        not null
        references public.customers(id)
        on delete cascade,

    tag_id uuid
        not null
        references public.customer_tags(id)
        on delete cascade,

    created_at timestamptz
        not null
        default now(),

    primary key (
        customer_id,
        tag_id
    )

);

comment on table public.customer_tag_assignments is
'Association entre les clients et leurs tags.';