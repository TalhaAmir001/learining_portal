-- Track when a parent/guardian has played the voice recording for a feedback.
-- One row per (feedback_id, parent_id).
CREATE TABLE IF NOT EXISTS `fl_daily_feedback_voice_played` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `feedback_id` INT(11) NOT NULL,
  `parent_id` INT(11) NOT NULL COMMENT 'Guardian parent_id from students table',
  `played_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_feedback_parent` (`feedback_id`, `parent_id`),
  INDEX `idx_feedback_id` (`feedback_id`),
  INDEX `idx_parent_id` (`parent_id`),
  FOREIGN KEY (`feedback_id`) REFERENCES `fl_daily_feedback`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Voice played by parent for daily feedback';
