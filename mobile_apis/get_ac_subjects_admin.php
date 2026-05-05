<?php
/**
 * Subjects (admin) list.
 * GET (optional): api_secret when AC_API_SECRET is set.
 */
require_once __DIR__ . '/ac_admin_bootstrap.php';

$mysqli = null;
try {
    $mysqli = ac_mysqli_connect();
    ac_require_api_secret(array_merge($_GET, array()));

    $rows = array();
    $r = $mysqli->query('SELECT id, name, code, type FROM subjects ORDER BY id ASC');
    if ($r) {
        while ($row = $r->fetch_assoc()) {
            $rows[] = array(
                'id' => (int) $row['id'],
                'name' => (string) ($row['name'] ?? ''),
                'code' => (string) ($row['code'] ?? ''),
                'type' => (string) ($row['type'] ?? ''),
            );
        }
    }
    $mysqli->close();
    ac_admin_success(array('items' => $rows));
} catch (Exception $e) {
    if ($mysqli) $mysqli->close();
    ac_admin_fail($e->getMessage(), array('items' => array()));
}

