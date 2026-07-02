<?php
/**
 * Run mobile-app schema migrations via HTTP (for FTP-only server access).
 *
 * Idempotent: safe to run more than once (uses CREATE TABLE IF NOT EXISTS).
 *
 * ── URLs (after upload to mobile_apis/ on the server) ─────────────────────
 *
 *   Active session table only (single-device login):
 *     GET /mobile_apis/install_mobile_app_active_session.php?install_key=YOUR_KEY
 *
 *   All mobile-app control tables (login log + revocation + active session):
 *     GET /mobile_apis/install_mobile_app_tables.php?install_key=YOUR_KEY
 *
 *   Browser-friendly output:
 *     append &format=html
 *
 * ── Security ────────────────────────────────────────────────────────────────
 *
 *   1. Preferred: set PL_API_SECRET on the server, then use ?api_secret=...
 *   2. Otherwise: edit PL_INSTALL_KEY below before uploading via FTP.
 *   3. Delete these install_*.php files from the server after a successful run.
 *
 * POST/GET:
 *   api_secret?  — when PL_API_SECRET env var is configured
 *   install_key? — when PL_INSTALL_KEY is set in this file (see below)
 *   format?      — json (default) | html
 */

require_once __DIR__ . '/pl_install_helper.php';

pl_install_require_secret();

$format = isset($_GET['format']) ? strtolower(trim((string) $_GET['format'])) : 'json';
$result = pl_install_run_sql_file(__DIR__ . '/mobile_app_active_session.sql');

if ($format === 'html') {
    pl_install_html_response($result, 'install_mobile_app_active_session');
}

pl_install_json_response($result);
