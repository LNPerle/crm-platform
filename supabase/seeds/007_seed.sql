-- ==========================================================
-- Lumeni
-- 007_seed.sql
--
-- Jeu de données de démonstration LOCAL.
--
-- Emplacement recommandé :
--   supabase/seeds/007_seed.sql
--
-- IMPORTANT :
--   - prévu pour `supabase db reset` en local ;
--   - ne pas pousser ce seed vers la production ;
--   - les comptes de démonstration utilisent le Magic Link.
-- ==========================================================

begin;

set local timezone = 'Europe/Paris';
set local client_min_messages = warning;

-- ==========================================================
-- 1. Utilisateurs Supabase Auth de démonstration
--
-- Connexion locale recommandée :
--   owner@lumeni.local
--   admin@lumeni.local
--   employee@lumeni.local
--
-- Demander un Magic Link puis l'ouvrir dans Mailpit.
-- ==========================================================

insert into auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
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
    'd1000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'owner@lumeni.local',
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"first_name":"Hélène","last_name":"Perle"}'::jsonb,
    now(),
    now(),
    '',
    '',
    '',
    ''
),
(
    '00000000-0000-0000-0000-000000000000',
    'd1000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'admin@lumeni.local',
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"first_name":"Camille","last_name":"Admin"}'::jsonb,
    now(),
    now(),
    '',
    '',
    '',
    ''
),
(
    '00000000-0000-0000-0000-000000000000',
    'd1000000-0000-0000-0000-000000000003',
    'authenticated',
    'authenticated',
    'employee@lumeni.local',
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"first_name":"Alex","last_name":"Équipe"}'::jsonb,
    now(),
    now(),
    '',
    '',
    '',
    ''
);

-- Une identité email est nécessaire pour que GoTrue retrouve
-- correctement les utilisateurs lors d'une connexion.
insert into auth.identities (
    id,
    user_id,
    provider_id,
    identity_data,
    provider,
    last_sign_in_at,
    created_at,
    updated_at
)
values
(
    'e1000000-0000-0000-0000-000000000001',
    'd1000000-0000-0000-0000-000000000001',
    'd1000000-0000-0000-0000-000000000001',
    jsonb_build_object(
        'sub', 'd1000000-0000-0000-0000-000000000001',
        'email', 'owner@lumeni.local',
        'email_verified', true
    ),
    'email',
    now(),
    now(),
    now()
),
(
    'e1000000-0000-0000-0000-000000000002',
    'd1000000-0000-0000-0000-000000000002',
    'd1000000-0000-0000-0000-000000000002',
    jsonb_build_object(
        'sub', 'd1000000-0000-0000-0000-000000000002',
        'email', 'admin@lumeni.local',
        'email_verified', true
    ),
    'email',
    now(),
    now(),
    now()
),
(
    'e1000000-0000-0000-0000-000000000003',
    'd1000000-0000-0000-0000-000000000003',
    'd1000000-0000-0000-0000-000000000003',
    jsonb_build_object(
        'sub', 'd1000000-0000-0000-0000-000000000003',
        'email', 'employee@lumeni.local',
        'email_verified', true
    ),
    'email',
    now(),
    now(),
    now()
);

-- Les triggers métier utilisent auth.uid(). On simule ici
-- l'owner pendant le chargement du seed.
select set_config(
    'request.jwt.claim.sub',
    'd1000000-0000-0000-0000-000000000001',
    true
);

select set_config(
    'request.jwt.claims',
    '{"sub":"d1000000-0000-0000-0000-000000000001","role":"authenticated"}',
    true
);

-- ==========================================================
-- 2. Commerce et équipe
-- ==========================================================

insert into public.businesses (
    id,
    name,
    slug,
    industry,
    timezone,
    currency,
    plan,
    subscription_status,
    trial_ends_at,
    logo_url
)
values (
    'd2000000-0000-0000-0000-000000000001',
    'Escale à Saigon — Démo',
    'escale-a-saigon-demo',
    'restaurant',
    'Europe/Paris',
    'EUR',
    'starter',
    'trial',
    now() + interval '14 days',
    null
);

insert into public.memberships (
    profile_id,
    business_id,
    role,
    accepted_at
)
values
(
    'd1000000-0000-0000-0000-000000000001',
    'd2000000-0000-0000-0000-000000000001',
    'owner',
    now()
),
(
    'd1000000-0000-0000-0000-000000000002',
    'd2000000-0000-0000-0000-000000000001',
    'admin',
    now()
),
(
    'd1000000-0000-0000-0000-000000000003',
    'd2000000-0000-0000-0000-000000000001',
    'employee',
    now()
);

-- ==========================================================
-- 3. Récompenses et programmes
-- ==========================================================

insert into public.reward_templates (
    id,
    business_id,
    name,
    description,
    reward_type,
    reward_value,
    validity_days,
    active
)
values
(
    'd3000000-0000-0000-0000-000000000001',
    'd2000000-0000-0000-0000-000000000001',
    'Boisson maison offerte',
    'Une boisson maison au choix.',
    'free_product',
    null,
    30,
    true
),
(
    'd3000000-0000-0000-0000-000000000002',
    'd2000000-0000-0000-0000-000000000001',
    '10 % de réduction',
    'Réduction valable sur la prochaine commande.',
    'discount',
    10,
    45,
    true
);

insert into public.loyalty_programs (
    id,
    business_id,
    reward_template_id,
    name,
    description,
    mode,
    target,
    active,
    priority
)
values
(
    'd4000000-0000-0000-0000-000000000001',
    'd2000000-0000-0000-0000-000000000001',
    'd3000000-0000-0000-0000-000000000001',
    '5 visites = une boisson',
    'Programme principal appliqué automatiquement.',
    'visits',
    5,
    true,
    10
),
(
    'd4000000-0000-0000-0000-000000000002',
    'd2000000-0000-0000-0000-000000000001',
    'd3000000-0000-0000-0000-000000000002',
    '100 points = 10 %',
    'Programme secondaire utilisé explicitement.',
    'points',
    100,
    true,
    5
);

-- ==========================================================
-- 4. Clients
-- ==========================================================

insert into public.customers (
    id,
    business_id,
    first_name,
    last_name,
    email,
    phone,
    birth_date,
    preferred_language,
    marketing_email,
    marketing_sms,
    status,
    favorite,
    source,
    notes_private,
    created_by,
    updated_by,
    created_at
)
values
(
    'd5000000-0000-0000-0000-000000000001',
    'd2000000-0000-0000-0000-000000000001',
    'Marie',
    'Dupont',
    'marie.dupont@example.test',
    '+33600000001',
    (current_date - interval '32 years')::date,
    'fr',
    true,
    true,
    'active',
    true,
    'dashboard',
    'Cliente historique, adore le café vietnamien.',
    'd1000000-0000-0000-0000-000000000001',
    'd1000000-0000-0000-0000-000000000001',
    now() - interval '18 months'
),
(
    'd5000000-0000-0000-0000-000000000002',
    'd2000000-0000-0000-0000-000000000001',
    'Lucas',
    'Martin',
    'lucas.martin@example.test',
    '+33600000002',
    date '1988-10-14',
    'fr',
    true,
    false,
    'active',
    false,
    'qr_code',
    null,
    'd1000000-0000-0000-0000-000000000003',
    'd1000000-0000-0000-0000-000000000003',
    now() - interval '10 months'
),
(
    'd5000000-0000-0000-0000-000000000003',
    'd2000000-0000-0000-0000-000000000001',
    'Sofia',
    'Nguyen',
    'sofia.nguyen@example.test',
    '+33600000003',
    date '1995-04-08',
    'fr',
    true,
    false,
    'active',
    true,
    'dashboard',
    'Participe au programme par points.',
    'd1000000-0000-0000-0000-000000000002',
    'd1000000-0000-0000-0000-000000000002',
    now() - interval '8 months'
),
(
    'd5000000-0000-0000-0000-000000000004',
    'd2000000-0000-0000-0000-000000000001',
    'Karim',
    'Benali',
    'karim.benali@example.test',
    '+33600000004',
    date '1990-12-02',
    'fr',
    false,
    false,
    'active',
    false,
    'import',
    null,
    'd1000000-0000-0000-0000-000000000003',
    'd1000000-0000-0000-0000-000000000003',
    now() - interval '6 months'
),
(
    'd5000000-0000-0000-0000-000000000005',
    'd2000000-0000-0000-0000-000000000001',
    'Emma',
    'Petit',
    'emma.petit@example.test',
    '+33600000005',
    date '2001-09-21',
    'fr',
    true,
    true,
    'active',
    false,
    'mobile',
    'Nouvelle cliente.',
    'd1000000-0000-0000-0000-000000000003',
    'd1000000-0000-0000-0000-000000000003',
    now() - interval '3 days'
),
(
    'd5000000-0000-0000-0000-000000000006',
    'd2000000-0000-0000-0000-000000000001',
    'Julien',
    'Bernard',
    'julien.bernard@example.test',
    '+33600000006',
    date '1983-02-17',
    'fr',
    false,
    false,
    'inactive',
    false,
    'import',
    'À relancer lors de la prochaine campagne.',
    'd1000000-0000-0000-0000-000000000002',
    'd1000000-0000-0000-0000-000000000002',
    now() - interval '14 months'
),
(
    'd5000000-0000-0000-0000-000000000007',
    'd2000000-0000-0000-0000-000000000001',
    'Chloé',
    'Moreau',
    'chloe.moreau@example.test',
    '+33600000007',
    date '1998-07-11',
    'fr',
    false,
    false,
    'blocked',
    false,
    'dashboard',
    'Compte bloqué pour démontrer les règles métier.',
    'd1000000-0000-0000-0000-000000000001',
    'd1000000-0000-0000-0000-000000000001',
    now() - interval '12 months'
),
(
    'd5000000-0000-0000-0000-000000000008',
    'd2000000-0000-0000-0000-000000000001',
    'Noah',
    'Garcia',
    'noah.garcia@example.test',
    '+33600000008',
    date '1992-11-29',
    'fr',
    true,
    false,
    'active',
    true,
    'qr_code',
    'Ambassadeur du commerce.',
    'd1000000-0000-0000-0000-000000000001',
    'd1000000-0000-0000-0000-000000000001',
    now() - interval '24 months'
);

-- ==========================================================
-- 5. Tags et segmentation
-- ==========================================================

insert into public.customer_tags (
    id,
    business_id,
    name,
    color,
    icon
)
values
(
    'd6000000-0000-0000-0000-000000000001',
    'd2000000-0000-0000-0000-000000000001',
    'VIP',
    '#F59E0B',
    'star'
),
(
    'd6000000-0000-0000-0000-000000000002',
    'd2000000-0000-0000-0000-000000000001',
    'Étudiant',
    '#3B82F6',
    'graduation-cap'
),
(
    'd6000000-0000-0000-0000-000000000003',
    'd2000000-0000-0000-0000-000000000001',
    'À relancer',
    '#EF4444',
    'bell'
),
(
    'd6000000-0000-0000-0000-000000000004',
    'd2000000-0000-0000-0000-000000000001',
    'Végétarien',
    '#22C55E',
    'leaf'
),
(
    'd6000000-0000-0000-0000-000000000005',
    'd2000000-0000-0000-0000-000000000001',
    'Ambassadeur',
    '#8B5CF6',
    'crown'
);

insert into public.customer_tag_assignments (
    customer_id,
    tag_id
)
values
(
    'd5000000-0000-0000-0000-000000000001',
    'd6000000-0000-0000-0000-000000000001'
),
(
    'd5000000-0000-0000-0000-000000000001',
    'd6000000-0000-0000-0000-000000000004'
),
(
    'd5000000-0000-0000-0000-000000000003',
    'd6000000-0000-0000-0000-000000000004'
),
(
    'd5000000-0000-0000-0000-000000000005',
    'd6000000-0000-0000-0000-000000000002'
),
(
    'd5000000-0000-0000-0000-000000000006',
    'd6000000-0000-0000-0000-000000000003'
),
(
    'd5000000-0000-0000-0000-000000000008',
    'd6000000-0000-0000-0000-000000000001'
),
(
    'd5000000-0000-0000-0000-000000000008',
    'd6000000-0000-0000-0000-000000000005'
);

-- ==========================================================
-- 6. Visites historiques
--
-- Les triggers calculent automatiquement :
--   - visit_number ;
--   - total_visits ;
--   - dates de première et dernière visite ;
--   - progression ;
--   - cycles ;
--   - récompenses ;
--   - Journal du commerce.
-- ==========================================================

-- Marie : 7 visites, 1 récompense, progression 2/5.
insert into public.visits (
    customer_id, employee_id, visit_source, created_at
) values
('d5000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000003', 'import', now() - interval '90 days'),
('d5000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000003', 'import', now() - interval '75 days'),
('d5000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000003', 'import', now() - interval '60 days'),
('d5000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000003', 'import', now() - interval '45 days'),
('d5000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000003', 'import', now() - interval '30 days'),
('d5000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000003', 'dashboard', now() - interval '10 days'),
('d5000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000003', 'dashboard', now() - interval '2 hours');

-- Lucas : 5 visites, récompense disponible.
insert into public.visits (
    customer_id, employee_id, visit_source, created_at
) values
('d5000000-0000-0000-0000-000000000002', 'd1000000-0000-0000-0000-000000000003', 'import', now() - interval '40 days'),
('d5000000-0000-0000-0000-000000000002', 'd1000000-0000-0000-0000-000000000003', 'import', now() - interval '30 days'),
('d5000000-0000-0000-0000-000000000002', 'd1000000-0000-0000-0000-000000000003', 'qr_code', now() - interval '20 days'),
('d5000000-0000-0000-0000-000000000002', 'd1000000-0000-0000-0000-000000000003', 'qr_code', now() - interval '10 days'),
('d5000000-0000-0000-0000-000000000002', 'd1000000-0000-0000-0000-000000000003', 'qr_code', now() - interval '1 day');

-- Sofia : 120 points, 1 cycle et 20 points restants.
insert into public.visits (
    customer_id,
    employee_id,
    loyalty_program_id,
    points_earned,
    visit_source,
    created_at
)
values
(
    'd5000000-0000-0000-0000-000000000003',
    'd1000000-0000-0000-0000-000000000002',
    'd4000000-0000-0000-0000-000000000002',
    30,
    'dashboard',
    now() - interval '20 days'
),
(
    'd5000000-0000-0000-0000-000000000003',
    'd1000000-0000-0000-0000-000000000002',
    'd4000000-0000-0000-0000-000000000002',
    40,
    'dashboard',
    now() - interval '10 days'
),
(
    'd5000000-0000-0000-0000-000000000003',
    'd1000000-0000-0000-0000-000000000002',
    'd4000000-0000-0000-0000-000000000002',
    50,
    'dashboard',
    now() - interval '1 day'
);

-- Karim : 3 visites.
insert into public.visits (
    customer_id, employee_id, visit_source, created_at
) values
('d5000000-0000-0000-0000-000000000004', 'd1000000-0000-0000-0000-000000000003', 'import', now() - interval '25 days'),
('d5000000-0000-0000-0000-000000000004', 'd1000000-0000-0000-0000-000000000003', 'dashboard', now() - interval '12 days'),
('d5000000-0000-0000-0000-000000000004', 'd1000000-0000-0000-0000-000000000003', 'dashboard', now() - interval '3 days');

-- Emma : première visite aujourd'hui.
insert into public.visits (
    customer_id, employee_id, visit_source, created_at
)
values (
    'd5000000-0000-0000-0000-000000000005',
    'd1000000-0000-0000-0000-000000000003',
    'mobile',
    now() - interval '30 minutes'
);

-- Noah : 10 visites, donc deux cycles et deux récompenses.
insert into public.visits (
    customer_id, employee_id, visit_source, created_at
) values
('d5000000-0000-0000-0000-000000000008', 'd1000000-0000-0000-0000-000000000003', 'import', now() - interval '180 days'),
('d5000000-0000-0000-0000-000000000008', 'd1000000-0000-0000-0000-000000000003', 'import', now() - interval '160 days'),
('d5000000-0000-0000-0000-000000000008', 'd1000000-0000-0000-0000-000000000003', 'import', now() - interval '140 days'),
('d5000000-0000-0000-0000-000000000008', 'd1000000-0000-0000-0000-000000000003', 'import', now() - interval '120 days'),
('d5000000-0000-0000-0000-000000000008', 'd1000000-0000-0000-0000-000000000003', 'import', now() - interval '100 days'),
('d5000000-0000-0000-0000-000000000008', 'd1000000-0000-0000-0000-000000000003', 'qr_code', now() - interval '80 days'),
('d5000000-0000-0000-0000-000000000008', 'd1000000-0000-0000-0000-000000000003', 'qr_code', now() - interval '60 days'),
('d5000000-0000-0000-0000-000000000008', 'd1000000-0000-0000-0000-000000000003', 'qr_code', now() - interval '40 days'),
('d5000000-0000-0000-0000-000000000008', 'd1000000-0000-0000-0000-000000000003', 'qr_code', now() - interval '20 days'),
('d5000000-0000-0000-0000-000000000008', 'd1000000-0000-0000-0000-000000000003', 'qr_code', now() - interval '4 hours');

-- On marque une récompense de Noah comme utilisée pour
-- alimenter les différents états du dashboard.
update public.reward_claims
set status = 'redeemed'
where id = (
    select r.id
    from public.reward_claims r
    where r.customer_id =
        'd5000000-0000-0000-0000-000000000008'
      and r.status = 'available'
    order by r.created_at asc
    limit 1
);

-- ==========================================================
-- 7. Vérification minimale
--
-- Le reset doit échouer clairement si les triggers n'ont pas
-- produit les agrégats attendus.
-- ==========================================================

do
$$
declare
    v_customers integer;
    v_visits integer;
    v_rewards integer;
begin
    select count(*) into v_customers
    from public.customers
    where business_id =
        'd2000000-0000-0000-0000-000000000001';

    select count(*) into v_visits
    from public.visits
    where business_id =
        'd2000000-0000-0000-0000-000000000001';

    select count(*) into v_rewards
    from public.reward_claims
    where business_id =
        'd2000000-0000-0000-0000-000000000001';

    if v_customers <> 8 then
        raise exception
            'Seed Lumeni invalide : 8 clients attendus, % trouvés.',
            v_customers;
    end if;

    if v_visits <> 29 then
        raise exception
            'Seed Lumeni invalide : 29 visites attendues, % trouvées.',
            v_visits;
    end if;

    if v_rewards <> 5 then
        raise exception
            'Seed Lumeni invalide : 5 récompenses attendues, % trouvées.',
            v_rewards;
    end if;
end;
$$;

commit;
