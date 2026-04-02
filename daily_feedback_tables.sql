-- =====================================================
-- Daily Feedback (Admin) Tables
-- =====================================================
-- Run this in your MySQL database. Admin staff record daily feedback
-- (written message, optional voice recording, optional attachments).
-- =====================================================

-- Main feedback entries (one per submission)
CREATE TABLE IF NOT EXISTS `fl_daily_feedback` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `staff_id` INT(11) NOT NULL COMMENT 'Admin/staff who created the feedback',
  `message_text` TEXT NULL DEFAULT NULL COMMENT 'Written feedback',
  `voice_url` VARCHAR(512) NULL DEFAULT NULL COMMENT 'URL to uploaded voice recording',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_staff_id` (`staff_id`),
  INDEX `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Admin daily feedback (written + optional voice)';

-- Attachments for each feedback (multiple per feedback)
CREATE TABLE IF NOT EXISTS `fl_daily_feedback_attachments` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `feedback_id` INT(11) NOT NULL,
  `file_url` VARCHAR(512) NOT NULL COMMENT 'Public URL of the file',
  `filename` VARCHAR(255) NULL DEFAULT NULL COMMENT 'Original filename',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_feedback_id` (`feedback_id`),
  FOREIGN KEY (`feedback_id`) REFERENCES `fl_daily_feedback`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Attachments for daily feedback';
