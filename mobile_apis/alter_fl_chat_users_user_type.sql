-- Extend fl_chat_users.user_type to match UserType enum: student, guardian, teacher, admin, staff (staff = Support only).
-- Run this once. If your column is ENUM('staff','student'), change it to allow the new values.
-- MySQL: use VARCHAR to avoid enum migration issues.

ALTER TABLE `fl_chat_users`
  MODIFY COLUMN `user_type` VARCHAR(20) NOT NULL DEFAULT 'student'
  COMMENT 'UserType: student, guardian, teacher, admin; or staff for Support (staff_id=0)';
