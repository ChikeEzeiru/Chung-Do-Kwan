CREATE TABLE IF NOT EXISTS quiz_progress (
  user_id text PRIMARY KEY,
  best integer NOT NULL DEFAULT 0 CHECK (best BETWEEN 0 AND 100),
  missed jsonb NOT NULL DEFAULT '[]'::jsonb,
  answered integer NOT NULL DEFAULT 0 CHECK (answered >= 0),
  updated_at timestamptz NOT NULL DEFAULT now()
);
