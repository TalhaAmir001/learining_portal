-- =====================================================
-- Add teacher_id and parent_id to fl_chat_users
-- =====================================================
-- Communications: Admins–Student, Admins–Teachers, Admins–Parents.
-- Each chat identity uses exactly one of: staff_id (admins + Support), student_id, teacher_id, parent_id.
--
-- Run this once. Then run the optional data migration if you have existing teacher/guardian rows.
-- =====================================================

-- Add columns (allow NULL; one of staff_id, student_id, teacher_id, parent_id is set per row)
ALTER TABLE `fl_chat_users`
  ADD COLUMN `teacher_id` INT(11) NULL DEFAULT NULL COMMENT 'Reference to staff table (teacher)' AFTER `student_id`,
  ADD COLUMN `parent_id` INT(11) NULL DEFAULT NULL COMMENT 'Reference to parents/guardians (e.g. students.id or guardian table)' AFTER `teacher_id`;

-- Indexes for lookups
ALTER TABLE `fl_chat_users`
  ADD INDEX `idx_teacher_id` (`teacher_id`),
  ADD INDEX `idx_parent_id` (`parent_id`);

-- Optional: migrate existing rows so teachers use teacher_id instead of staff_id
-- Uncomment and run if you have teachers currently stored with staff_id set:
--
-- UPDATE fl_chat_users SET teacher_id = staff_id, staff_id = NULL, user_type = 'teacher'
-- WHERE user_type = 'teacher' AND staff_id IS NOT NULL AND staff_id != 0;
--
-- Optional: migrate guardians to parent_id (if you stored them with student_id and user_type guardian)
-- UPDATE fl_chat_users SET parent_id = student_id, student_id = NULL, user_type = 'guardian'
-- WHERE user_type IN ('guardian', 'parent') AND student_id IS NOT NULL;
