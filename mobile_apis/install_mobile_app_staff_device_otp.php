<?php
/**
 * Install mobile_app_staff_device_otp table (staff mobile transfer codes).
 *
 * URL:
 *   GET /mobile_apis/install_mobile_app_staff_device_otp.php?install_key=YOUR_KEY&format=html
 */

require_once __DIR__ . '/pl_install_helper.php';

pl_install_require_secret();

$format = isset($_GET['format']) ? strtolower(trim((string) $_GET['format'])) : 'json';
$result = pl_install_run_sql_file(__DIR__ . '/mobile_app_staff_device_otp.sql');

$mysqli = pl_mysqli_connect();
if ($mysqli && pl_mobile_app_staff_device_otp_table_exists($mysqli)) {
    $col = $mysqli->query("SHOW COLUMNS FROM `mobile_app_staff_device_otp` LIKE 'registered_device_id'");
    $needs_device_cols = ($col && $col->num_rows === 0);
    if ($col) {
        $col->free();
    }
    if ($needs_device_cols) {
        $alter = pl_install_run_sql_file(__DIR__ . '/mobile_app_staff_device_otp_add_device.sql');
        if (!empty($alter['steps'])) {
            $result['steps'] = array_merge($result['steps'] ?? array(), $alter['steps']);
        }
        if (empty($alter['success'])) {
            $result['success'] = false;
            $result['message'] = 'Table created but device column migration failed.';
        }
    }
}
if ($mysqli) {
    $mysqli->close();
}

if ($format === 'html') {
    pl_install_html_response($result, 'install_mobile_app_staff_device_otp');
}

pl_install_json_response($result);
