-- =====================================================
-- Complain Reports Table
-- =====================================================
-- Stores user reports/complaints (e.g. report user in chat).
-- Run this query on your database to create the table.
-- =====================================================

CREATE TABLE IF NOT EXISTS `complain_reports` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `reporter_user_id` INT(11) NOT NULL COMMENT 'Staff ID or Student ID of who reported',
  `reporter_type` ENUM('staff', 'student') NOT NULL DEFAULT 'staff' COMMENT 'Type of reporter',
  `reported_user_id` INT(11) NOT NULL COMMENT 'Staff ID or Student ID of reported user',
  `reported_user_type` ENUM('staff', 'student') NOT NULL DEFAULT 'student' COMMENT 'Type of reported user',
  `chat_connection_id` INT(11) NULL DEFAULT NULL COMMENT 'Chat connection where report was made (optional)',
  `reason` TEXT NULL DEFAULT NULL COMMENT 'Reason/description of the report',
  `status` ENUM('pending', 'reviewed', 'resolved', 'dismissed') NOT NULL DEFAULT 'pending',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_reporter` (`reporter_user_id`, `reporter_type`),
  INDEX `idx_reported` (`reported_user_id`, `reported_user_type`),
  INDEX `idx_status` (`status`),
  INDEX `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='User complaint/report records';
