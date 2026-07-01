-- ==========================================================
-- Lumeni
-- 006_tests.sql
--
-- Tests d'intégration PostgreSQL avec pgTAP.
--
-- IMPORTANT
-- ---------
-- Ce fichier est destiné à l'environnement local/de test.
-- Il ne doit pas être appliqué comme une migration de
-- production.
--
-- Il vérifie notamment :
--   - la synchronisation auth.users -> profiles ;
--   - l'isolation entre commerces ;
--   - les droits owner / admin / employee ;
--   - les index uniques insensibles à la casse ;
--   - la création de visites ;
--   - la progression fidélité ;
--   - la génération et l'utilisation des récompenses ;
--   - les RPC du dashboard ;
--   - la confidentialité du Journal du commerce.
--
-- Toutes les données de test sont annulées par ROLLBACK.
-- ==========================================================

begin;

set local client_min_messages = warning;
set local timezone = 'UTC';

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

-- Les droits suivants sont temporaires : la transaction sera
-- annulée à la fin du fichier.
grant usage on schema extensions to authenticated, anon;
grant execute on all functions in schema extensions
to authenticated, anon;

set local search_path = extensions, public, auth, private;

select plan(56);

-- ==========================================================
-- 1. Utilisateurs de test
-- ==========================================================

insert into auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    recovery_token,
    email_change_token_new,
    email_change
)
values
(
    '00000000-0000-0000-0000-000000000000',
    '10000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'owner.alpha@lumeni.test',
    'test-password',
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"first_name":"Olivia","last_name":"Owner"}'::jsonb,
    now(),
    now(),
    '',
    '',
    '',
    ''
),
(
    '00000000-0000-0000-0000-000000000000',
    '10000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'admin.alpha@lumeni.test',
    'test-password',
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"first_name":"Alice","last_name":"Admin"}'::jsonb,
    now(),
    now(),
    '',
    '',
    '',
    ''
),
(
    '00000000-0000-0000-0000-000000000000',
    '10000000-0000-0000-0000-000000000003',
    'authenticated',
    'authenticated',
    'employee.alpha@lumeni.test',
    'test-password',
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"first_name":"Emma","last_name":"Employee"}'::jsonb,
    now(),
    now(),
    '',
    '',
    '',
    ''
),
(
    '00000000-0000-0000-0000-000000000000',
    '10000000-0000-0000-0000-000000000004',
    'authenticated',
    'authenticated',
    'owner.beta@lumeni.test',
    'test-password',
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"first_name":"Basile","last_name":"Owner"}'::jsonb,
    now(),
    now(),
    '',
    '',
    '',
    ''
),
(
    '00000000-0000-0000-0000-000000000000',
    '10000000-0000-0000-0000-000000000005',
    'authenticated',
    'authenticated',
    'employee.beta@lumeni.test',
    'test-password',
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"first_name":"Béatrice","last_name":"Employee"}'::jsonb,
    now(),
    now(),
    '',
    '',
    '',
    ''
),
(
    '00000000-0000-0000-0000-000000000000',
    '10000000-0000-0000-0000-000000000006',
    'authenticated',
    'authenticated',
    'new.owner@lumeni.test',
    'test-password',
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"first_name":"Nora","last_name":"New"}'::jsonb,
    now(),
    now(),
    '',
    '',
    '',
    ''
);

select is(
    (
        select count(*)::integer
        from public.profiles
        where id in (
            '10000000-0000-0000-0000-000000000001',
            '10000000-0000-0000-0000-000000000002',
            '10000000-0000-0000-0000-000000000003',
            '10000000-0000-0000-0000-000000000004',
            '10000000-0000-0000-0000-000000000005',
            '10000000-0000-0000-0000-000000000006'
        )
    ),
    6,
    'Le trigger Auth crée les six profils.'
);

select is(
    (
        select first_name
        from public.profiles
        where id = '10000000-0000-0000-0000-000000000001'
    ),
    'Olivia',
    'Les métadonnées Auth sont copiées dans le profil.'
);

-- ==========================================================
-- 2. Données de deux commerces indépendants
-- ==========================================================

insert into public.businesses (
    id,
    name,
    slug,
    industry,
    timezone,
    currency
)
values
(
    '20000000-0000-0000-0000-000000000001',
    'Commerce Alpha',
    'commerce-alpha',
    'restaurant',
    'UTC',
    'EUR'
),
(
    '20000000-0000-0000-0000-000000000002',
    'Commerce Bêta',
    'commerce-beta',
    'coiffure',
    'UTC',
    'EUR'
);

insert into public.memberships (
    profile_id,
    business_id,
    role,
    accepted_at
)
values
(
    '10000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    'owner',
    now()
),
(
    '10000000-0000-0000-0000-000000000002',
    '20000000-0000-0000-0000-000000000001',
    'admin',
    now()
),
(
    '10000000-0000-0000-0000-000000000003',
    '20000000-0000-0000-0000-000000000001',
    'employee',
    now()
),
(
    '10000000-0000-0000-0000-000000000004',
    '20000000-0000-0000-0000-000000000002',
    'owner',
    now()
),
(
    '10000000-0000-0000-0000-000000000005',
    '20000000-0000-0000-0000-000000000002',
    'employee',
    now()
);

insert into public.reward_templates (
    id,
    business_id,
    name,
    reward_type,
    validity_days
)
values
(
    '30000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    'Café offert',
    'gift',
    30
),
(
    '30000000-0000-0000-0000-000000000002',
    '20000000-0000-0000-0000-000000000002',
    'Coupe offerte',
    'gift',
    30
);

insert into public.loyalty_programs (
    id,
    business_id,
    reward_template_id,
    name,
    mode,
    target,
    active,
    priority
)
values
(
    '40000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    'Deux visites',
    'visits',
    2,
    true,
    10
),
(
    '40000000-0000-0000-0000-000000000002',
    '20000000-0000-0000-0000-000000000002',
    '30000000-0000-0000-0000-000000000002',
    'Cinq visites',
    'visits',
    5,
    true,
    10
);

insert into public.customers (
    id,
    business_id,
    first_name,
    last_name,
    email,
    birth_date,
    source
)
values
(
    '50000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    'Anniversaire',
    'Alpha',
    'client.alpha@lumeni.test',
    (now() at time zone 'UTC')::date,
    'test'
),
(
    '50000000-0000-0000-0000-000000000002',
    '20000000-0000-0000-0000-000000000002',
    'Client',
    'Bêta',
    'client.beta@lumeni.test',
    null,
    'test'
);

insert into public.customer_tags (
    id,
    business_id,
    name,
    color
)
values
(
    '60000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    'VIP Alpha',
    '#6366F1'
),
(
    '60000000-0000-0000-0000-000000000002',
    '20000000-0000-0000-0000-000000000002',
    'VIP Bêta',
    '#6366F1'
);

insert into public.activity_logs (
    id,
    business_id,
    entity,
    entity_id,
    action,
    title,
    visible,
    severity
)
values (
    '70000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    'test',
    null,
    'hidden',
    'Événement réservé aux responsables',
    false,
    'info'
);

select throws_ok(
    $$
        insert into public.businesses (
            name,
            slug,
            industry
        )
        values (
            'Doublon Alpha',
            'COMMERCE-ALPHA',
            'restaurant'
        )
    $$,
    '23505',
    'Le slug d’un commerce est unique sans distinction de casse.'
);

-- ==========================================================
-- 3. RPC de création initiale d'un commerce
-- ==========================================================

select set_config(
    'request.jwt.claim.sub',
    '10000000-0000-0000-0000-000000000006',
    true
);
select set_config(
    'request.jwt.claims',
    '{"sub":"10000000-0000-0000-0000-000000000006","role":"authenticated"}',
    true
);
set local role authenticated;

select lives_ok(
    $$
        select public.lumeni_create_business(
            p_name => 'Commerce créé par RPC',
            p_industry => 'restaurant',
            p_program_name => 'Programme RPC',
            p_mode => 'visits',
            p_target => 3,
            p_reward_name => 'Cadeau RPC'
        )
    $$,
    'Un utilisateur authentifié peut créer son commerce via la RPC.'
);

reset role;

select is(
    (
        select count(*)::integer
        from public.businesses
        where name = 'Commerce créé par RPC'
    ),
    1,
    'La RPC crée exactement un commerce.'
);

select is(
    (
        select count(*)::integer
        from public.memberships m
        join public.businesses b
          on b.id = m.business_id
        where b.name = 'Commerce créé par RPC'
          and m.profile_id =
              '10000000-0000-0000-0000-000000000006'
          and m.role = 'owner'
          and m.deleted_at is null
    ),
    1,
    'La RPC attribue le rôle owner au créateur.'
);

select is(
    (
        select count(*)::integer
        from public.loyalty_programs p
        join public.businesses b
          on b.id = p.business_id
        where b.name = 'Commerce créé par RPC'
          and p.name = 'Programme RPC'
          and p.active = true
          and p.deleted_at is null
    ),
    1,
    'La RPC crée le programme de fidélité initial.'
);

-- ==========================================================
-- 4. Accès owner
-- ==========================================================

select set_config(
    'request.jwt.claim.sub',
    '10000000-0000-0000-0000-000000000001',
    true
);
select set_config(
    'request.jwt.claims',
    '{"sub":"10000000-0000-0000-0000-000000000001","role":"authenticated"}',
    true
);
set local role authenticated;

select is(
    (select count(*)::integer from public.businesses),
    1,
    'Un owner ne voit que son propre commerce.'
);

select is(
    (select name from public.businesses limit 1),
    'Commerce Alpha',
    'Le commerce visible est bien celui de l’owner.'
);

select is(
    (
        with changed as (
            update public.businesses
            set name = 'Commerce Alpha mis à jour'
            where id = '20000000-0000-0000-0000-000000000001'
            returning 1
        )
        select count(*)::integer
        from changed
    ),
    1,
    'Un owner peut modifier son commerce.'
);

reset role;

-- ==========================================================
-- 5. Accès employee et admin
-- ==========================================================

select set_config(
    'request.jwt.claim.sub',
    '10000000-0000-0000-0000-000000000003',
    true
);
select set_config(
    'request.jwt.claims',
    '{"sub":"10000000-0000-0000-0000-000000000003","role":"authenticated"}',
    true
);
set local role authenticated;

select is(
    (select count(*)::integer from public.businesses),
    1,
    'Un employee ne voit que son commerce.'
);

select is(
    (
        with changed as (
            update public.businesses
            set name = 'Modification interdite'
            where id = '20000000-0000-0000-0000-000000000001'
            returning 1
        )
        select count(*)::integer
        from changed
    ),
    0,
    'Un employee ne peut pas modifier le commerce.'
);

select throws_ok(
    $$
        insert into public.reward_templates (
            business_id,
            name
        )
        values (
            '20000000-0000-0000-0000-000000000001',
            'Récompense interdite'
        )
    $$,
    '42501',
    'Un employee ne peut pas créer de récompense.'
);

select throws_ok(
    $$
        insert into public.customer_tags (
            business_id,
            name
        )
        values (
            '20000000-0000-0000-0000-000000000001',
            'Tag interdit'
        )
    $$,
    '42501',
    'Un employee ne peut pas créer un tag.'
);

reset role;

select set_config(
    'request.jwt.claim.sub',
    '10000000-0000-0000-0000-000000000002',
    true
);
select set_config(
    'request.jwt.claims',
    '{"sub":"10000000-0000-0000-0000-000000000002","role":"authenticated"}',
    true
);
set local role authenticated;

select lives_ok(
    $$
        insert into public.customer_tags (
            business_id,
            name,
            color
        )
        values (
            '20000000-0000-0000-0000-000000000001',
            'VIP Test',
            '#111111'
        )
    $$,
    'Un admin peut créer un tag.'
);

select throws_ok(
    $$
        insert into public.customer_tags (
            business_id,
            name,
            color
        )
        values (
            '20000000-0000-0000-0000-000000000001',
            'vip test',
            '#222222'
        )
    $$,
    '23505',
    'Le nom d’un tag est unique sans distinction de casse.'
);

reset role;

-- ==========================================================
-- 6. Clients et tags
-- ==========================================================

select set_config(
    'request.jwt.claim.sub',
    '10000000-0000-0000-0000-000000000003',
    true
);
select set_config(
    'request.jwt.claims',
    '{"sub":"10000000-0000-0000-0000-000000000003","role":"authenticated"}',
    true
);
set local role authenticated;

select lives_ok(
    $$
        insert into public.customers (
            business_id,
            first_name,
            last_name,
            email,
            source
        )
        values (
            '20000000-0000-0000-0000-000000000001',
            'Nina',
            'Nouvelle',
            'new.alpha@lumeni.test',
            'dashboard'
        )
    $$,
    'Un employee peut créer un client dans son commerce.'
);

select is(
    (
        select created_by
        from public.customers
        where email = 'new.alpha@lumeni.test'
    ),
    '10000000-0000-0000-0000-000000000003'::uuid,
    'Le trigger renseigne automatiquement created_by.'
);

select throws_ok(
    $$
        insert into public.customers (
            business_id,
            first_name,
            email
        )
        values (
            '20000000-0000-0000-0000-000000000002',
            'Intrus',
            'intrus.beta@lumeni.test'
        )
    $$,
    '42501',
    'Un employee ne peut pas créer un client dans un autre commerce.'
);

select throws_ok(
    $$
        insert into public.customers (
            business_id,
            first_name,
            email
        )
        values (
            '20000000-0000-0000-0000-000000000001',
            'Doublon',
            'CLIENT.ALPHA@LUMENI.TEST'
        )
    $$,
    '23505',
    'L’email client est unique par commerce sans distinction de casse.'
);

select lives_ok(
    $$
        insert into public.customer_tag_assignments (
            customer_id,
            tag_id
        )
        values (
            (
                select id
                from public.customers
                where email = 'new.alpha@lumeni.test'
            ),
            '60000000-0000-0000-0000-000000000001'
        )
    $$,
    'Un employee peut attribuer un tag de son commerce.'
);

select throws_ok(
    $$
        insert into public.customer_tag_assignments (
            customer_id,
            tag_id
        )
        values (
            (
                select id
                from public.customers
                where email = 'new.alpha@lumeni.test'
            ),
            '60000000-0000-0000-0000-000000000002'
        )
    $$,
    '23514',
    'Un tag d’un autre commerce ne peut pas être attribué.'
);

select lives_ok(
    $$
        delete from public.customer_tag_assignments
        where customer_id = (
            select id
            from public.customers
            where email = 'new.alpha@lumeni.test'
        )
          and tag_id =
              '60000000-0000-0000-0000-000000000001'
    $$,
    'Un employee peut retirer un tag attribué.'
);

-- ==========================================================
-- 7. Visites, progression et récompenses
-- ==========================================================

select lives_ok(
    $$
        insert into public.visits (
            customer_id,
            employee_id,
            points_earned,
            visit_source
        )
        values (
            (
                select id
                from public.customers
                where email = 'new.alpha@lumeni.test'
            ),
            '10000000-0000-0000-0000-000000000003',
            0,
            'dashboard'
        )
    $$,
    'La première visite peut être enregistrée.'
);

select is(
    (
        select visit_number
        from public.visits
        where customer_id = (
            select id
            from public.customers
            where email = 'new.alpha@lumeni.test'
        )
        order by visit_number desc
        limit 1
    ),
    1,
    'La première visite reçoit le numéro 1.'
);

select is(
    (
        select loyalty_program_id
        from public.visits
        where customer_id = (
            select id
            from public.customers
            where email = 'new.alpha@lumeni.test'
        )
        order by visit_number desc
        limit 1
    ),
    '40000000-0000-0000-0000-000000000001'::uuid,
    'Le programme actif prioritaire est sélectionné automatiquement.'
);

select is(
    (
        select total_visits
        from public.customers
        where email = 'new.alpha@lumeni.test'
    ),
    1,
    'Le compteur total_visits est incrémenté.'
);

select is(
    (
        select current_visits
        from public.customer_loyalty_accounts
        where customer_id = (
            select id
            from public.customers
            where email = 'new.alpha@lumeni.test'
        )
          and loyalty_program_id =
              '40000000-0000-0000-0000-000000000001'
    ),
    1,
    'La progression contient une visite après le premier passage.'
);

select is(
    (
        select count(*)::integer
        from public.reward_claims
        where customer_id = (
            select id
            from public.customers
            where email = 'new.alpha@lumeni.test'
        )
    ),
    0,
    'Aucune récompense n’est créée avant l’objectif.'
);

select lives_ok(
    $$
        insert into public.visits (
            customer_id,
            employee_id,
            points_earned,
            visit_source
        )
        values (
            (
                select id
                from public.customers
                where email = 'new.alpha@lumeni.test'
            ),
            '10000000-0000-0000-0000-000000000003',
            0,
            'dashboard'
        )
    $$,
    'La deuxième visite peut être enregistrée.'
);

select is(
    (
        select max(visit_number)
        from public.visits
        where customer_id = (
            select id
            from public.customers
            where email = 'new.alpha@lumeni.test'
        )
    ),
    2,
    'La deuxième visite reçoit le numéro 2.'
);

select is(
    (
        select current_visits
        from public.customer_loyalty_accounts
        where customer_id = (
            select id
            from public.customers
            where email = 'new.alpha@lumeni.test'
        )
          and loyalty_program_id =
              '40000000-0000-0000-0000-000000000001'
    ),
    0,
    'La progression recommence à zéro après un cycle complet.'
);

select is(
    (
        select completed_cycles
        from public.customer_loyalty_accounts
        where customer_id = (
            select id
            from public.customers
            where email = 'new.alpha@lumeni.test'
        )
          and loyalty_program_id =
              '40000000-0000-0000-0000-000000000001'
    ),
    1,
    'Un cycle terminé est enregistré.'
);

select is(
    (
        select count(*)::integer
        from public.reward_claims
        where customer_id = (
            select id
            from public.customers
            where email = 'new.alpha@lumeni.test'
        )
          and status = 'available'
    ),
    1,
    'Une récompense disponible est créée à l’objectif.'
);

select is(
    (
        select total_rewards
        from public.customers
        where email = 'new.alpha@lumeni.test'
    ),
    1,
    'Le compteur total_rewards est incrémenté.'
);

select ok(
    (
        select expires_at > created_at
        from public.reward_claims
        where customer_id = (
            select id
            from public.customers
            where email = 'new.alpha@lumeni.test'
        )
        limit 1
    ),
    'La récompense possède une date d’expiration future.'
);

select lives_ok(
    $$
        update public.reward_claims
        set status = 'redeemed'
        where customer_id = (
            select id
            from public.customers
            where email = 'new.alpha@lumeni.test'
        )
          and status = 'available'
    $$,
    'Un employee peut utiliser une récompense disponible.'
);

select ok(
    (
        select redeemed_at is not null
        from public.reward_claims
        where customer_id = (
            select id
            from public.customers
            where email = 'new.alpha@lumeni.test'
        )
        limit 1
    ),
    'La date redeemed_at est renseignée automatiquement.'
);

select throws_ok(
    $$
        update public.reward_claims
        set status = 'available'
        where customer_id = (
            select id
            from public.customers
            where email = 'new.alpha@lumeni.test'
        )
          and status = 'redeemed'
    $$,
    '23514',
    'Une récompense utilisée ne peut pas redevenir disponible.'
);

select throws_ok(
    $$
        update public.visits
        set notes = 'Modification interdite'
        where customer_id = (
            select id
            from public.customers
            where email = 'new.alpha@lumeni.test'
        )
    $$,
    '42501',
    'Une visite est immuable depuis l’API cliente.'
);

select throws_ok(
    $$
        select private.lumeni_create_activity(
            '20000000-0000-0000-0000-000000000001',
            '10000000-0000-0000-0000-000000000003',
            (
                select id
                from public.customers
                where email = 'new.alpha@lumeni.test'
            ),
            'test',
            null,
            'created',
            'Écriture directe interdite',
            null,
            '{}'::jsonb,
            'info'
        )
    $$,
    '42501',
    'Un utilisateur ne peut pas écrire directement dans le Journal.'
);

-- ==========================================================
-- 8. Fonctions RPC de lecture
-- ==========================================================

select is(
    (
        public.lumeni_dashboard_stats(
            '20000000-0000-0000-0000-000000000001'
        ) ->> 'customers'
    )::integer,
    2,
    'Le dashboard compte les deux clients du commerce Alpha.'
);

select is(
    (
        public.lumeni_dashboard_stats(
            '20000000-0000-0000-0000-000000000001'
        ) ->> 'visitsToday'
    )::integer,
    2,
    'Le dashboard compte les deux visites du jour.'
);

select is(
    (
        public.lumeni_dashboard_stats(
            '20000000-0000-0000-0000-000000000001'
        ) ->> 'availableRewards'
    )::integer,
    0,
    'Le dashboard ne compte plus la récompense utilisée comme disponible.'
);

select is(
    (
        select customer_id
        from public.lumeni_top_customers(
            '20000000-0000-0000-0000-000000000001',
            10
        )
        order by customer_rank
        limit 1
    ),
    (
        select id
        from public.customers
        where email = 'new.alpha@lumeni.test'
    ),
    'Le client ayant deux visites arrive en tête du classement.'
);

select is(
    (
        public.lumeni_customer_progress(
            (
                select id
                from public.customers
                where email = 'new.alpha@lumeni.test'
            ),
            '40000000-0000-0000-0000-000000000001'
        ) ->> 'current'
    )::integer,
    0,
    'La RPC de progression retourne le reliquat courant.'
);

select is(
    (
        public.lumeni_customer_progress(
            (
                select id
                from public.customers
                where email = 'new.alpha@lumeni.test'
            ),
            '40000000-0000-0000-0000-000000000001'
        ) ->> 'completedCycles'
    )::integer,
    1,
    'La RPC de progression retourne le nombre de cycles terminés.'
);

select is(
    (
        select count(*)::integer
        from public.lumeni_birthdays_today(
            '20000000-0000-0000-0000-000000000001'
        )
        where customer_id =
            '50000000-0000-0000-0000-000000000001'
    ),
    1,
    'La RPC anniversaire retourne le client attendu.'
);

select is(
    (
        select count(*)::integer
        from public.activity_logs
        where id = '70000000-0000-0000-0000-000000000001'
    ),
    0,
    'Un employee ne voit pas les événements internes masqués.'
);

reset role;

-- ==========================================================
-- 9. Visibilité du Journal pour owner
-- ==========================================================

select set_config(
    'request.jwt.claim.sub',
    '10000000-0000-0000-0000-000000000001',
    true
);
select set_config(
    'request.jwt.claims',
    '{"sub":"10000000-0000-0000-0000-000000000001","role":"authenticated"}',
    true
);
set local role authenticated;

select is(
    (
        select count(*)::integer
        from public.activity_logs
        where id = '70000000-0000-0000-0000-000000000001'
    ),
    1,
    'Un owner voit les événements internes masqués.'
);

reset role;

-- ==========================================================
-- 10. Isolation du commerce Bêta
-- ==========================================================

select set_config(
    'request.jwt.claim.sub',
    '10000000-0000-0000-0000-000000000005',
    true
);
select set_config(
    'request.jwt.claims',
    '{"sub":"10000000-0000-0000-0000-000000000005","role":"authenticated"}',
    true
);
set local role authenticated;

select is(
    (select count(*)::integer from public.customers),
    1,
    'L’employee Bêta ne voit que le client de son commerce.'
);

select is(
    (select count(*)::integer from public.visits),
    0,
    'L’employee Bêta ne voit aucune visite du commerce Alpha.'
);

reset role;

-- ==========================================================
-- 11. Administration des rôles
-- ==========================================================

select set_config(
    'request.jwt.claim.sub',
    '10000000-0000-0000-0000-000000000002',
    true
);
select set_config(
    'request.jwt.claims',
    '{"sub":"10000000-0000-0000-0000-000000000002","role":"authenticated"}',
    true
);
set local role authenticated;

select throws_ok(
    $$
        update public.memberships
        set role = 'owner'
        where profile_id =
            '10000000-0000-0000-0000-000000000003'
          and business_id =
            '20000000-0000-0000-0000-000000000001'
    $$,
    '42501',
    'Un admin ne peut pas promouvoir un membre au rôle owner.'
);

reset role;

select set_config(
    'request.jwt.claim.sub',
    '10000000-0000-0000-0000-000000000001',
    true
);
select set_config(
    'request.jwt.claims',
    '{"sub":"10000000-0000-0000-0000-000000000001","role":"authenticated"}',
    true
);
set local role authenticated;

select is(
    (
        with changed as (
            update public.memberships
            set role = 'admin'
            where profile_id =
                '10000000-0000-0000-0000-000000000003'
              and business_id =
                '20000000-0000-0000-0000-000000000001'
            returning 1
        )
        select count(*)::integer
        from changed
    ),
    1,
    'Un owner peut promouvoir un employee au rôle admin.'
);

select is(
    (
        with changed as (
            update public.memberships
            set role = 'employee'
            where profile_id =
                '10000000-0000-0000-0000-000000000003'
              and business_id =
                '20000000-0000-0000-0000-000000000001'
            returning 1
        )
        select count(*)::integer
        from changed
    ),
    1,
    'Un owner peut rétablir le rôle employee.'
);

reset role;

-- ==========================================================
-- 12. Accès anonyme
-- ==========================================================

select set_config('request.jwt.claim.sub', '', true);
select set_config(
    'request.jwt.claims',
    '{"role":"anon"}',
    true
);
set local role anon;

select throws_ok(
    $$
        select count(*)
        from public.businesses
    $$,
    '42501',
    'Le rôle anon ne peut pas lire les données métier.'
);

reset role;

-- ==========================================================
-- Résultat et nettoyage
-- ==========================================================

select * from finish();

rollback;
