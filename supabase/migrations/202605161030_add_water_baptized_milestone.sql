INSERT INTO milestone_definitions (code, label, is_active)
VALUES ('WATER_BAPTIZED', 'Water Baptized', true)
ON CONFLICT (code) DO NOTHING;
