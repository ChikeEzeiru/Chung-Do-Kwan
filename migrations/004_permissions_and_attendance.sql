BEGIN;

CREATE TABLE IF NOT EXISTS permissions (
  key text PRIMARY KEY,
  description text NOT NULL
);

CREATE TABLE IF NOT EXISTS organization_role_permissions (
  role text NOT NULL CHECK (role IN ('organization_owner','head_instructor')),
  permission_key text NOT NULL REFERENCES permissions(key) ON DELETE CASCADE,
  PRIMARY KEY (role, permission_key)
);

CREATE TABLE IF NOT EXISTS dojang_role_permissions (
  role text NOT NULL CHECK (role IN ('dojang_admin','instructor')),
  permission_key text NOT NULL REFERENCES permissions(key) ON DELETE CASCADE,
  PRIMARY KEY (role, permission_key)
);

INSERT INTO permissions (key, description) VALUES
  ('organization.manage', 'Manage organization settings'),
  ('instructors.manage', 'Assign and remove instructor roles'),
  ('curriculum.publish_shared', 'Publish shared curriculum'),
  ('members.view', 'View members in scope'),
  ('members.approve', 'Approve membership applications in scope'),
  ('belts.assign_initial', 'Assign a new member initial belt'),
  ('grading.create', 'Create grading sessions'),
  ('grading.record', 'Record grading results'),
  ('grading.confirm', 'Provide final grading confirmation'),
  ('grading.publish', 'Publish confirmed grading results'),
  ('grading.correct', 'Correct published grading results'),
  ('resources.manage', 'Create and publish learning resources'),
  ('quizzes.manage', 'Create and publish quizzes'),
  ('announcements.manage', 'Create and publish announcements'),
  ('audit.view', 'View audit history in scope'),
  ('attendance.record', 'Create sessions and record attendance'),
  ('attendance.correct', 'Correct recorded attendance'),
  ('attendance.view_reports', 'View attendance reports in scope'),
  ('recognition.publish', 'Publish consented attendance recognition')
ON CONFLICT (key) DO UPDATE SET description = EXCLUDED.description;

INSERT INTO organization_role_permissions (role, permission_key)
SELECT 'organization_owner', key FROM permissions
ON CONFLICT DO NOTHING;

INSERT INTO organization_role_permissions (role, permission_key)
SELECT 'head_instructor', key FROM permissions
WHERE key <> 'organization.manage'
ON CONFLICT DO NOTHING;

INSERT INTO dojang_role_permissions (role, permission_key) VALUES
  ('dojang_admin', 'members.view'),
  ('dojang_admin', 'members.approve'),
  ('dojang_admin', 'belts.assign_initial'),
  ('dojang_admin', 'grading.create'),
  ('dojang_admin', 'grading.record'),
  ('dojang_admin', 'grading.publish'),
  ('dojang_admin', 'resources.manage'),
  ('dojang_admin', 'quizzes.manage'),
  ('dojang_admin', 'announcements.manage'),
  ('dojang_admin', 'audit.view'),
  ('dojang_admin', 'attendance.record'),
  ('dojang_admin', 'attendance.correct'),
  ('dojang_admin', 'attendance.view_reports'),
  ('dojang_admin', 'recognition.publish'),
  ('instructor', 'members.view'),
  ('instructor', 'grading.create'),
  ('instructor', 'grading.record'),
  ('instructor', 'attendance.record'),
  ('instructor', 'attendance.correct'),
  ('instructor', 'attendance.view_reports')
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS class_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dojang_id uuid NOT NULL REFERENCES dojangs(id) ON DELETE RESTRICT,
  title text NOT NULL,
  starts_at timestamptz NOT NULL,
  ends_at timestamptz,
  status text NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled','completed','cancelled')),
  created_by_user_id text NOT NULL REFERENCES profiles(clerk_user_id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (ends_at IS NULL OR ends_at > starts_at)
);

CREATE INDEX IF NOT EXISTS class_sessions_dojang_starts_at_idx
  ON class_sessions(dojang_id, starts_at DESC);

CREATE TABLE IF NOT EXISTS attendance_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  class_session_id uuid NOT NULL REFERENCES class_sessions(id) ON DELETE CASCADE,
  student_id uuid NOT NULL REFERENCES students(id) ON DELETE RESTRICT,
  status text NOT NULL CHECK (status IN ('present','late','excused','absent')),
  private_note text,
  recorded_by_user_id text NOT NULL REFERENCES profiles(clerk_user_id) ON DELETE RESTRICT,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (class_session_id, student_id)
);

CREATE INDEX IF NOT EXISTS attendance_records_student_idx
  ON attendance_records(student_id, recorded_at DESC);

CREATE TABLE IF NOT EXISTS attendance_recognition_preferences (
  student_id uuid PRIMARY KEY REFERENCES students(id) ON DELETE CASCADE,
  enabled boolean NOT NULL DEFAULT false,
  consent_source text CHECK (consent_source IN ('adult_self','guardian')),
  consented_by_user_id text REFERENCES profiles(clerk_user_id) ON DELETE SET NULL,
  consented_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT enabled OR (consent_source IS NOT NULL AND consented_by_user_id IS NOT NULL AND consented_at IS NOT NULL))
);

COMMIT;
