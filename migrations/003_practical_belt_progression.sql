BEGIN;

UPDATE belt_levels
SET is_active = false,
    sort_order = CASE name
      WHEN 'Yellow 1' THEN 201
      WHEN 'Yellow 2' THEN 202
      WHEN 'Orange 1' THEN 203
      WHEN 'Orange 2' THEN 204
    END
WHERE organization_id = (SELECT id FROM organizations WHERE slug = 'chung-do-kwan')
  AND name IN ('Yellow 1', 'Yellow 2', 'Orange 1', 'Orange 2');

INSERT INTO belt_levels (organization_id, name, gup, sort_order, is_active)
SELECT id, v.name, NULL, v.sort_order, true
FROM organizations
CROSS JOIN (VALUES
  ('Yellow', 20),
  ('Orange', 30),
  ('Green', 40),
  ('Blue', 50),
  ('Brown', 60),
  ('Black', 70)
) AS v(name, sort_order)
WHERE organizations.slug = 'chung-do-kwan'
ON CONFLICT (organization_id, sort_order)
DO UPDATE SET name = EXCLUDED.name, gup = NULL, is_active = true;

CREATE TABLE IF NOT EXISTS curriculum_stages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  belt_level_id uuid NOT NULL REFERENCES belt_levels(id) ON DELETE RESTRICT,
  name text NOT NULL,
  sort_order integer NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  UNIQUE (organization_id, name),
  UNIQUE (organization_id, sort_order)
);

INSERT INTO curriculum_stages (organization_id, belt_level_id, name, sort_order)
SELECT o.id, bl.id, v.stage_name, v.sort_order
FROM organizations o
JOIN (VALUES
  ('White', 'White', 10),
  ('Yellow 1', 'Yellow', 20),
  ('Yellow 2', 'Yellow', 30),
  ('Orange 1', 'Orange', 40),
  ('Orange 2', 'Orange', 50)
) AS v(stage_name, belt_name, sort_order) ON true
JOIN belt_levels bl ON bl.organization_id = o.id AND bl.name = v.belt_name AND bl.is_active = true
WHERE o.slug = 'chung-do-kwan'
ON CONFLICT (organization_id, name)
DO UPDATE SET belt_level_id = EXCLUDED.belt_level_id, sort_order = EXCLUDED.sort_order, is_active = true;

COMMIT;
