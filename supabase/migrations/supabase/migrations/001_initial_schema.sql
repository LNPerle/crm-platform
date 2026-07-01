-- ==========================================================
-- Lumeni - Initial Schema
-- Version : 1.0
-- ==========================================================

create extension if not exists "pgcrypto";

-- ==========================================================
-- Profiles
-- ==========================================================

create table public.profiles (

    id uuid primary key references auth.users(id) on delete cascade,

    first_name text,

    last_name text,

    email text not null unique,

    avatar_url text,

    last_login_at timestamptz,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    deleted_at timestamptz

);

-- ==========================================================
-- Businesses
-- ==========================================================

create table public.businesses (

    id uuid primary key default gen_random_uuid(),

    name text not null,

    slug text not null unique,

    industry text not null default 'restaurant',

    theme_color text default '#4F46E5',

    logo_url text,

    email text,

    phone text,

    address text,

    city text,

    postal_code text,

    country text default 'France',

    timezone text default 'Europe/Paris',

    currency text default 'EUR',

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    deleted_at timestamptz

);

-- ==========================================================
-- Memberships
-- ==========================================================

create table public.memberships (

    id uuid primary key default gen_random_uuid(),

    profile_id uuid not null references profiles(id) on delete cascade,

    business_id uuid not null references businesses(id) on delete cascade,

    role text not null default 'owner',

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    constraint memberships_unique unique(profile_id, business_id),

    constraint memberships_role_check
        check (role in ('owner','manager','employee'))

);

-- ==========================================================
-- Reward Templates
-- ==========================================================

create table public.reward_templates (

    id uuid primary key default gen_random_uuid(),

    business_id uuid not null references businesses(id) on delete cascade,

    name text not null,

    description text,

    validity_days integer not null default 90,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    deleted_at timestamptz,

    constraint reward_validity_check
        check (validity_days > 0)

);

-- ==========================================================
-- Loyalty Programs
-- ==========================================================

create table public.loyalty_programs (

    id uuid primary key default gen_random_uuid(),

    business_id uuid not null references businesses(id) on delete cascade,

    reward_template_id uuid references reward_templates(id),

    name text not null,

    mode text not null,

    target integer not null,

    active boolean not null default true,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    deleted_at timestamptz,

    constraint loyalty_mode_check
        check (mode in ('visits','points')),

    constraint loyalty_target_check
        check (target > 0)

);
-- ==========================================================
-- Customers
-- ==========================================================

create table public.customers (

    id uuid primary key default gen_random_uuid(),

    business_id uuid not null
        references businesses(id)
        on delete cascade,

    qr_token uuid not null
        default gen_random_uuid()
        unique,

    first_name text not null,

    last_name text,

    email text,

    phone text,

    birth_date date,

    notes text,

    marketing_email boolean not null default false,

    marketing_sms boolean not null default false,

    created_at timestamptz not null default now(),

    updated_at timestamptz not null default now(),

    deleted_at timestamptz

    status text not null default 'active'

    source text

    customer_number bigint generated always as identity

);
-- ==========================================================
-- Visits
-- ==========================================================

create table public.visits (

    id uuid primary key default gen_random_uuid(),

    customer_id uuid not null
        references customers(id)
        on delete cascade,

    employee_id uuid
        references profiles(id),

    created_at timestamptz not null default now()

);
-- ==========================================================
-- Reward Claims
-- ==========================================================

create table public.reward_claims (

    id uuid primary key default gen_random_uuid(),

    customer_id uuid not null
        references customers(id)
        on delete cascade,

    reward_template_id uuid not null
        references reward_templates(id),

    expires_at timestamptz not null,

    redeemed_at timestamptz,

    created_at timestamptz not null default now()

    status text not null default 'available'
    check (status in ('available', 'redeemed', 'expired'))

);
-- ==========================================================
-- Activity Logs
-- ==========================================================

create table public.activity_logs (

    id uuid primary key default gen_random_uuid(),

    business_id uuid not null
        references businesses(id)
        on delete cascade,

    profile_id uuid
        references profiles(id),

    action text not null,

    entity text not null,

    entity_id uuid,

    metadata jsonb default '{}'::jsonb,

    created_at timestamptz not null default now()

);
