-- One active mobile-app session per account (staff, portal_user, app_parent_user).
-- Run once on the same database as the portal + mobile_apis.

CREATE TABLE IF NOT EXISTS `mobile_app_active_session` (
  `id` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `actor_type` varchar(32) NOT NULL COMMENT 'staff|portal_user|app_parent_user',
  `actor_id` int(11) UNSIGNED NOT NULL,
  `device_id` varchar(64) NOT NULL COMMENT 'client install UUID',
  `session_token` varchar(64) NOT NULL COMMENT 'server-issued secret',
  `device_label` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_seen_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_actor` (`actor_type`, `actor_id`),
  KEY `idx_last_seen` (`last_seen_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
