-- Blocks Learning Portal *mobile app* sign-in only (requests with X-Learning-Portal-App).
-- Web browser logins are not affected. Run on the same database as the portal + mobile_apis.

CREATE TABLE IF NOT EXISTS `mobile_app_access_revocation` (
  `id` int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
  `actor_type` varchar(32) NOT NULL COMMENT 'staff|portal_user|app_parent_user',
  `actor_id` int(11) UNSIGNED NOT NULL DEFAULT 0,
  `revoked_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `revoked_by_staff_id` int(11) UNSIGNED DEFAULT NULL COMMENT 'staff.id who applied revocation',
  `reason` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_actor` (`actor_type`, `actor_id`),
  KEY `idx_revoked_at` (`revoked_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
