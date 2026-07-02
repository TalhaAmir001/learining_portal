-- Revert to one session per account (from two-device uq_actor_device schema).
-- Keeps the most recently seen session row per actor, then restores uq_actor.
-- Run once via install_mobile_app_active_session_single_device.php

DELETE s1 FROM `mobile_app_active_session` s1
INNER JOIN `mobile_app_active_session` s2
  ON s1.actor_type = s2.actor_type
 AND s1.actor_id = s2.actor_id
 AND (
   s1.last_seen_at < s2.last_seen_at
   OR (s1.last_seen_at = s2.last_seen_at AND s1.id < s2.id)
 );

ALTER TABLE `mobile_app_active_session` DROP INDEX `uq_actor_device`;
ALTER TABLE `mobile_app_active_session` DROP INDEX `idx_actor`;
ALTER TABLE `mobile_app_active_session` ADD UNIQUE KEY `uq_actor` (`actor_type`, `actor_id`);
