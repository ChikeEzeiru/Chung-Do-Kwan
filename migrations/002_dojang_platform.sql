BEGIN;

CREATE TABLE IF NOT EXISTS organizations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS dojangs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
  name text NOT NULL,
  slug text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_id, slug)
);

CREATE TABLE IF NOT EXISTS profiles (
  clerk_user_id text PRIMARY KEY,
  full_name text NOT NULL,
  email text NOT NULL,
  gender text CHECK (gender IN ('male','female','prefer_not_to_say')),
  account_status text NOT NULL DEFAULT 'active' CHECK (account_status IN ('active','suspended','deleted')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS students (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  clerk_user_id text UNIQUE REFERENCES profiles(clerk_user_id) ON DELETE SET NULL,
  full_name text NOT NULL,
  gender text NOT NULL CHECK (gender IN ('male','female','prefer_not_to_say')),
  date_of_birth date,
  is_minor boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT is_minor OR date_of_birth IS NOT NULL)
);

CREATE TABLE IF NOT EXISTS guardianships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  guardian_user_id text NOT NULL REFERENCES profiles(clerk_user_id) ON DELETE RESTRICT,
  student_id uuid NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  relationship text NOT NULL,
  is_primary boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (guardian_user_id, student_id)
);

CREATE TABLE IF NOT EXISTS parental_consents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  guardianship_id uuid NOT NULL REFERENCES guardianships(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','granted','withdrawn','rejected')),
  consent_version text NOT NULL,
  granted_at timestamptz,
  withdrawn_at timestamptz,
  verified_at timestamptz,
  verified_by_user_id text REFERENCES profiles(clerk_user_id) ON DELETE SET NULL,
  verification_method text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS student_memberships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL REFERENCES students(id) ON DELETE RESTRICT,
  dojang_id uuid NOT NULL REFERENCES dojangs(id) ON DELETE RESTRICT,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','active','suspended','declined','transferred','ended')),
  joined_at date,
  ended_at date,
  approved_at timestamptz,
  approved_by_user_id text REFERENCES profiles(clerk_user_id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS one_current_dojang_per_student
  ON student_memberships(student_id)
  WHERE status IN ('pending','active','suspended');

CREATE TABLE IF NOT EXISTS organization_roles (
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  clerk_user_id text NOT NULL REFERENCES profiles(clerk_user_id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('organization_owner','head_instructor')),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (organization_id, clerk_user_id, role)
);

CREATE TABLE IF NOT EXISTS dojang_roles (
  dojang_id uuid NOT NULL REFERENCES dojangs(id) ON DELETE CASCADE,
  clerk_user_id text NOT NULL REFERENCES profiles(clerk_user_id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('dojang_admin','instructor')),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (dojang_id, clerk_user_id, role)
);

CREATE TABLE IF NOT EXISTS belt_levels (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name text NOT NULL,
  gup integer CHECK (gup BETWEEN 1 AND 10),
  sort_order integer NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  UNIQUE (organization_id, sort_order),
  UNIQUE (organization_id, name, gup)
);

CREATE TABLE IF NOT EXISTS grading_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dojang_id uuid NOT NULL REFERENCES dojangs(id) ON DELETE RESTRICT,
  title text NOT NULL,
  grading_date date NOT NULL,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','completed','results_entered','confirmed','published','cancelled')),
  standards_authority_user_id text REFERENCES profiles(clerk_user_id) ON DELETE SET NULL,
  confirmation_method text CHECK (confirmation_method IN ('in_app','confirmed_in_person','exceptional_direct_approval')),
  confirmation_recorded_by_user_id text REFERENCES profiles(clerk_user_id) ON DELETE SET NULL,
  confirmed_at timestamptz,
  published_at timestamptz,
  created_by_user_id text NOT NULL REFERENCES profiles(clerk_user_id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS grading_results (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  grading_session_id uuid NOT NULL REFERENCES grading_sessions(id) ON DELETE CASCADE,
  student_id uuid NOT NULL REFERENCES students(id) ON DELETE RESTRICT,
  previous_belt_level_id uuid REFERENCES belt_levels(id) ON DELETE RESTRICT,
  proposed_belt_level_id uuid NOT NULL REFERENCES belt_levels(id) ON DELETE RESTRICT,
  result text NOT NULL CHECK (result IN ('passed','failed','deferred','conditional')),
  notes text,
  recorded_by_user_id text NOT NULL REFERENCES profiles(clerk_user_id) ON DELETE RESTRICT,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (grading_session_id, student_id)
);

CREATE TABLE IF NOT EXISTS promotion_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL REFERENCES students(id) ON DELETE RESTRICT,
  belt_level_id uuid NOT NULL REFERENCES belt_levels(id) ON DELETE RESTRICT,
  grading_result_id uuid UNIQUE REFERENCES grading_results(id) ON DELETE RESTRICT,
  effective_date date NOT NULL,
  recorded_by_user_id text NOT NULL REFERENCES profiles(clerk_user_id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS resources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  dojang_id uuid REFERENCES dojangs(id) ON DELETE CASCADE,
  minimum_belt_level_id uuid REFERENCES belt_levels(id) ON DELETE SET NULL,
  title text NOT NULL,
  description text,
  resource_type text NOT NULL CHECK (resource_type IN ('article','document','image','video','link')),
  content text,
  external_url text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published','archived')),
  created_by_user_id text NOT NULL REFERENCES profiles(clerk_user_id) ON DELETE RESTRICT,
  published_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (content IS NOT NULL OR external_url IS NOT NULL)
);

CREATE TABLE IF NOT EXISTS questions (
  id text PRIMARY KEY,
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  category text NOT NULL,
  prompt text NOT NULL,
  answer text NOT NULL,
  options jsonb NOT NULL,
  explanation text,
  difficulty text NOT NULL DEFAULT 'standard' CHECK (difficulty IN ('standard','hard','assessment')),
  minimum_belt_level_id uuid REFERENCES belt_levels(id) ON DELETE SET NULL,
  source_reference text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('draft','active','archived')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (jsonb_typeof(options) = 'array')
);

CREATE TABLE IF NOT EXISTS quizzes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  dojang_id uuid REFERENCES dojangs(id) ON DELETE CASCADE,
  title text NOT NULL,
  quiz_type text NOT NULL DEFAULT 'practice' CHECK (quiz_type IN ('practice','assigned','assessment')),
  passing_score integer CHECK (passing_score BETWEEN 0 AND 100),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published','archived')),
  created_by_user_id text NOT NULL REFERENCES profiles(clerk_user_id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS quiz_questions (
  quiz_id uuid NOT NULL REFERENCES quizzes(id) ON DELETE CASCADE,
  question_id text NOT NULL REFERENCES questions(id) ON DELETE RESTRICT,
  position integer NOT NULL,
  PRIMARY KEY (quiz_id, question_id),
  UNIQUE (quiz_id, position)
);

CREATE TABLE IF NOT EXISTS quiz_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quiz_id uuid REFERENCES quizzes(id) ON DELETE SET NULL,
  student_id uuid NOT NULL REFERENCES students(id) ON DELETE RESTRICT,
  mode text NOT NULL DEFAULT 'practice' CHECK (mode IN ('practice','assigned','assessment','weak_spots')),
  score integer CHECK (score BETWEEN 0 AND 100),
  started_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz
);

CREATE TABLE IF NOT EXISTS student_answers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  attempt_id uuid NOT NULL REFERENCES quiz_attempts(id) ON DELETE CASCADE,
  question_id text NOT NULL REFERENCES questions(id) ON DELETE RESTRICT,
  selected_answer text,
  is_correct boolean NOT NULL,
  answered_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (attempt_id, question_id)
);

CREATE TABLE IF NOT EXISTS announcements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  dojang_id uuid REFERENCES dojangs(id) ON DELETE CASCADE,
  title text NOT NULL,
  body text NOT NULL,
  audience text NOT NULL DEFAULT 'all' CHECK (audience IN ('all','students','parents','instructors')),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published','archived')),
  created_by_user_id text NOT NULL REFERENCES profiles(clerk_user_id) ON DELETE RESTRICT,
  published_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS audit_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  organization_id uuid REFERENCES organizations(id) ON DELETE SET NULL,
  actor_user_id text REFERENCES profiles(clerk_user_id) ON DELETE SET NULL,
  action text NOT NULL,
  entity_type text NOT NULL,
  entity_id text NOT NULL,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE quiz_progress ADD COLUMN IF NOT EXISTS student_id uuid REFERENCES students(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS quiz_progress_student_id_idx ON quiz_progress(student_id);

INSERT INTO organizations (name, slug)
VALUES ('Chung Do Kwan', 'chung-do-kwan')
ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name, updated_at = now();

INSERT INTO dojangs (organization_id, name, slug)
SELECT id, 'Phoenix Dojang', 'phoenix' FROM organizations WHERE slug = 'chung-do-kwan'
ON CONFLICT (organization_id, slug) DO UPDATE SET name = EXCLUDED.name, is_active = true, updated_at = now();

INSERT INTO dojangs (organization_id, name, slug)
SELECT id, 'Fireflow Dojang', 'fireflow' FROM organizations WHERE slug = 'chung-do-kwan'
ON CONFLICT (organization_id, slug) DO UPDATE SET name = EXCLUDED.name, is_active = true, updated_at = now();

INSERT INTO belt_levels (organization_id, name, gup, sort_order)
SELECT id, v.name, v.gup, v.sort_order
FROM organizations
CROSS JOIN (VALUES
  ('White', 9, 10),
  ('Yellow 1', 8, 20),
  ('Yellow 2', 7, 30),
  ('Orange 1', 6, 40),
  ('Orange 2', 5, 50)
) AS v(name, gup, sort_order)
WHERE organizations.slug = 'chung-do-kwan'
ON CONFLICT (organization_id, sort_order) DO NOTHING;

COMMIT;
