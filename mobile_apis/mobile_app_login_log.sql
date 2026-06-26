-- Learning Portal mobile app sign-in audit (optional).
-- Run once on the portal MySQL database. Admin dashboard reads this for
-- weekly / monthly / all-time distinct user counts.

CREATE TABLE IF NOT EXISTS `mobile_app_login_log` (
  `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `actor_type` varchar(32) NOT NULL COMMENT 'staff|portal_user|app_parent_user',
  `actor_id` int(11) UNSIGNED NOT NULL DEFAULT 0 COMMENT 'staff.id, users.id, or app_parent_users.id',
  PRIMARY KEY (`id`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_actor` (`actor_type`, `actor_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
