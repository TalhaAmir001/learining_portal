-- =====================================================
-- Parent self-link children — schema additions for the
-- "Mobile app parent linking" model (code-based linking).
-- =====================================================
--
-- Expected base tables (created separately, NOT by this file):
--   • `app_parents`         — mobile-side parent profiles (email UNIQUE).
--   • `app_parent_students` — many-to-many parent ↔ student link.
--
-- This file adds the bits the mobile flow needs on top of those:
--
--   1. Per-student one-time code columns on `students`:
--        mobile_app_code                CHAR(6) UNIQUE  — admin-issued code
--        mobile_app_code_used           TINYINT(1)      — 1 = consumed
--        mobile_app_code_used_at        DATETIME        — when consumed
--        mobile_app_code_used_by_parent_id INT          — app_parents.id
--
--   2. The "active child" the guardian last picked on mobile:
--        app_parents.active_child_id    INT NULL        — students.id
--
-- Every ALTER is wrapped in a stored procedure that checks
-- information_schema first, so this file is idempotent across MySQL
-- 5.x and 8.0+ (no need for `ALTER TABLE … ADD COLUMN IF NOT EXISTS`).

-- ---------- 1. students.mobile_app_code* ---------------------------------
DELIMITER $$
DROP PROCEDURE IF EXISTS `pl_add_students_mobile_code_cols` $$
CREATE PROCEDURE `pl_add_students_mobile_code_cols`()
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME   = 'students'
      AND COLUMN_NAME  = 'mobile_app_code'
  ) THEN
    ALTER TABLE `students`
      ADD COLUMN `mobile_app_code` CHAR(6) DEFAULT NULL
        COMMENT '6-char one-time code admins issue to parents on mobile';
    ALTER TABLE `students`
      ADD UNIQUE KEY `uniq_students_mobile_app_code` (`mobile_app_code`);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME   = 'students'
      AND COLUMN_NAME  = 'mobile_app_code_used'
  ) THEN
    ALTER TABLE `students`
      ADD COLUMN `mobile_app_code_used` TINYINT(1) NOT NULL DEFAULT 0
        COMMENT '1 = code has been claimed by a parent on mobile';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME   = 'students'
      AND COLUMN_NAME  = 'mobile_app_code_used_at'
  ) THEN
    ALTER TABLE `students`
      ADD COLUMN `mobile_app_code_used_at` DATETIME DEFAULT NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME   = 'students'
      AND COLUMN_NAME  = 'mobile_app_code_used_by_parent_id'
  ) THEN
    ALTER TABLE `students`
      ADD COLUMN `mobile_app_code_used_by_parent_id` INT(11) DEFAULT NULL
        COMMENT 'app_parents.id that consumed this code';
  END IF;
END $$
DELIMITER ;

CALL `pl_add_students_mobile_code_cols`();
DROP PROCEDURE IF EXISTS `pl_add_students_mobile_code_cols`;

-- ---------- 2. app_parents.active_child_id -------------------------------
DELIMITER $$
DROP PROCEDURE IF EXISTS `pl_add_app_parents_active_child_id` $$
CREATE PROCEDURE `pl_add_app_parents_active_child_id`()
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME   = 'app_parents'
      AND COLUMN_NAME  = 'active_child_id'
  ) THEN
    ALTER TABLE `app_parents`
      ADD COLUMN `active_child_id` INT(11) NULL DEFAULT NULL
        COMMENT 'students.id last picked by this parent on mobile';
  END IF;
END $$
DELIMITER ;

CALL `pl_add_app_parents_active_child_id`();
DROP PROCEDURE IF EXISTS `pl_add_app_parents_active_child_id`;







-- Mobile app parent linking: per-student codes + parent accounts (run on MySQL/MariaDB)
-- Safe to run multiple times if your client supports IF NOT EXISTS for columns (MySQL 8.0.12+).
-- For older MySQL, run ALTERs manually once or use ensure_schema in Student_mobile_app_model.

CREATE TABLE IF NOT EXISTS `app_parents` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(191) NOT NULL,
  `email` varchar(191) NOT NULL,
  `phone` varchar(64) NOT NULL DEFAULT '',
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_app_parents_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `app_parent_students` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `parent_id` int(11) NOT NULL,
  `student_id` int(11) NOT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_parent_student` (`parent_id`,`student_id`),
  KEY `idx_student` (`student_id`),
  CONSTRAINT `fk_app_parent_students_parent` FOREIGN KEY (`parent_id`) REFERENCES `app_parents` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Optional: if FK to students fails on your DB, drop the next line and keep KEY only.
-- ALTER TABLE `app_parent_students` ADD CONSTRAINT `fk_app_parent_students_student` FOREIGN KEY (`student_id`) REFERENCES `students` (`id`) ON DELETE CASCADE;

-- Student columns (run separately if CREATE TABLE already applied)
-- ALTER TABLE `students` ADD COLUMN `mobile_app_code` char(6) DEFAULT NULL AFTER `parent_app_key`;
-- ALTER TABLE `students` ADD COLUMN `mobile_app_code_used` tinyint(1) NOT NULL DEFAULT 0;
-- ALTER TABLE `students` ADD COLUMN `mobile_app_code_used_at` datetime DEFAULT NULL;
-- ALTER TABLE `students` ADD COLUMN `mobile_app_code_used_by_parent_id` int(11) DEFAULT NULL;
-- ALTER TABLE `students` ADD UNIQUE KEY `uniq_students_mobile_app_code` (`mobile_app_code`);





CREATE TABLE IF NOT EXISTS `app_parent_users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `app_parent_id` int(11) NOT NULL,
  `username` varchar(64) NOT NULL,
  `password` varchar(255) NOT NULL,
  `email` varchar(191) NOT NULL,
  `welcome_email_sent_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_app_parent_users_parent` (`app_parent_id`),
  UNIQUE KEY `uniq_app_parent_users_username` (`username`),
  KEY `idx_app_parent_users_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------- Leaving notices (4-week notice policy) -----------------------
-- A parent can submit one or more leaving notices from the mobile app
-- (before logging in). Each submission captures the credentials used
-- (resolved to app_parent_id), the typed reason, and the requested
-- leaving date — which the server validates is at least 28 days in the
-- future before accepting. Audit trail: we keep every submission rather
-- than overwriting, so admins can see retraction / re-submission history.
CREATE TABLE IF NOT EXISTS `app_parent_leaving_notices` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `app_parent_id` int(11) NOT NULL,
  `app_parent_user_id` int(11) DEFAULT NULL,
  `identifier_used` varchar(191) NOT NULL DEFAULT ''
    COMMENT 'username or email the parent typed when submitting',
  `reason` text NOT NULL,
  `leaving_date` date NOT NULL
    COMMENT 'requested last day of access (server enforces >= today + 28d)',
  `submitted_at` datetime NOT NULL,
  `submission_ip` varchar(64) DEFAULT NULL,
  `status` varchar(32) NOT NULL DEFAULT 'submitted'
    COMMENT 'submitted | acknowledged | cancelled — admin-managed lifecycle',
  `active_student_id` int(11) DEFAULT NULL
    COMMENT 'students.id the parent had active when submitting (nullable)',
  `active_student_label` varchar(191) NOT NULL DEFAULT ''
    COMMENT 'frozen "First Last (ADM-1234)" snapshot for the audit trail',
  PRIMARY KEY (`id`),
  KEY `idx_app_parent_leaving_parent` (`app_parent_id`),
  KEY `idx_app_parent_leaving_date` (`leaving_date`),
  KEY `idx_app_parent_leaving_student` (`active_student_id`),
  CONSTRAINT `fk_app_parent_leaving_parent`
    FOREIGN KEY (`app_parent_id`) REFERENCES `app_parents` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------- Idempotent column adds for existing deployments --------------
-- For installs that already have `app_parent_leaving_notices` without the
-- new active-student columns, add them in-place. Same pattern as the other
-- pl_* migration procs in this file.
DELIMITER $$
DROP PROCEDURE IF EXISTS `pl_add_leaving_notice_active_child_cols` $$
CREATE PROCEDURE `pl_add_leaving_notice_active_child_cols`()
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME   = 'app_parent_leaving_notices'
      AND COLUMN_NAME  = 'active_student_id'
  ) THEN
    ALTER TABLE `app_parent_leaving_notices`
      ADD COLUMN `active_student_id` INT(11) DEFAULT NULL
        COMMENT 'students.id the parent had active when submitting (nullable)';
    ALTER TABLE `app_parent_leaving_notices`
      ADD KEY `idx_app_parent_leaving_student` (`active_student_id`);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME   = 'app_parent_leaving_notices'
      AND COLUMN_NAME  = 'active_student_label'
  ) THEN
    ALTER TABLE `app_parent_leaving_notices`
      ADD COLUMN `active_student_label` VARCHAR(191) NOT NULL DEFAULT ''
        COMMENT 'frozen "First Last (ADM-1234)" snapshot for the audit trail';
  END IF;
END $$
DELIMITER ;

CALL `pl_add_leaving_notice_active_child_cols`();
DROP PROCEDURE IF EXISTS `pl_add_leaving_notice_active_child_cols`;