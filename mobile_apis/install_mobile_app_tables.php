<?php
/**
 * Install all Learning Portal mobile-app database tables in one request.
 *
 * Creates (if missing):
 *   • mobile_app_login_log
 *   • mobile_app_access_revocation
 *   • mobile_app_active_session
 *
 * URL:
 *   GET /mobile_apis/install_mobile_app_tables.php?install_key=YOUR_KEY
 *   GET /mobile_apis/install_mobile_app_tables.php?install_key=YOUR_KEY&format=html
 *
 * See install_mobile_app_active_session.php for security notes.
 * Delete this file from the server after migrations succeed.
 */

require_once __DIR__ . '/pl_install_helper.php';

pl_install_require_secret();

$format = isset($_GET['format']) ? strtolower(trim((string) $_GET['format'])) : 'json';

$migrations = array(
    'mobile_app_login_log'        => __DIR__ . '/mobile_app_login_log.sql',
    'mobile_app_access_revocation' => __DIR__ . '/mobile_app_access_revocation.sql',
    'mobile_app_active_session'   => __DIR__ . '/mobile_app_active_session.sql',
    'mobile_app_device_transfer_otp' => __DIR__ . '/mobile_app_device_transfer_otp.sql',
);

$results = array();
$all_ok  = true;

foreach ($migrations as $name => $path) {
    $step = pl_install_run_sql_file($path);
    $step['table'] = $name;
    $results[] = $step;
    if (empty($step['success'])) {
        $all_ok = false;
    }
}

$result = array(
    'success' => $all_ok,
    'message' => $all_ok
        ? 'All mobile app tables are installed (or were already present).'
        : 'One or more migrations failed. See results.',
    'results' => $results,
);

if ($format === 'html') {
    pl_install_html_response($result, 'install_mobile_app_tables');
}

pl_install_json_response($result);
