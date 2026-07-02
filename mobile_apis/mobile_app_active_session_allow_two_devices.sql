-- Migrate existing mobile_app_active_session from one session per account
-- to up to two concurrent devices (one row per device).
--
-- Run once if your table was created with UNIQUE KEY uq_actor (actor_type, actor_id).
-- Safe to skip on fresh installs that already use uq_actor_device.

ALTER TABLE `mobile_app_active_session` DROP INDEX `uq_actor`;
ALTER TABLE `mobile_app_active_session`
  ADD UNIQUE KEY `uq_actor_device` (`actor_type`, `actor_id`, `device_id`),
  ADD KEY `idx_actor` (`actor_type`, `actor_id`);
