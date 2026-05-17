-- Allow moodle_course_id to be null so placeholder/seed rows can be created
-- before a Moodle course is assigned. Active rows with a null course_id will be
-- skipped by the sync (resolveCourseId returns "" when null).
alter table public.batch_moodle_courses
  alter column moodle_course_id drop not null;
