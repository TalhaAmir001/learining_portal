<?php
/**
 * Install mobile_app_device_transfer_otp table (device transfer codes).
 *
 * URL:
 *   GET /mobile_apis/install_mobile_app_device_transfer_otp.php?install_key=YOUR_KEY&format=html
 */

require_once __DIR__ . '/pl_install_helper.php';

pl_install_require_secret();

$format = isset($_GET['format']) ? strtolower(trim((string) $_GET['format'])) : 'json';
$result = pl_install_run_sql_file(__DIR__ . '/mobile_app_device_transfer_otp.sql');

if (!empty($result['success'])) {
    $alter = pl_install_run_sql_file(__DIR__ . '/mobile_app_device_transfer_otp_no_expiry.sql');
    if (!empty($alter['steps'])) {
        $result['steps'] = array_merge($result['steps'] ?? array(), $alter['steps']);
    }
}

if ($format === 'html') {
    pl_install_html_response($result, 'install_mobile_app_device_transfer_otp');
}

pl_install_json_response($result);
