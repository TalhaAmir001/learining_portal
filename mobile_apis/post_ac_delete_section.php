<?php
/**
 * Delete section (admin).
 * JSON: { id: int }
 */
require_once __DIR__ . '/ac_admin_bootstrap.php';

$mysqli = null;
try {
    $mysqli = ac_mysqli_connect();
    $body = ac_read_json_body();
    ac_require_api_secret($body);
    ac_admin_require_fields($body, array('id'));

    $id = (int) $body['id'];
    if ($id <= 0) {
        throw new Exception('Invalid id.');
    }

    if (!$mysqli->query('DELETE FROM sections WHERE id=' . $id . ' LIMIT 1')) {
        throw new Exception('Delete failed: ' . $mysqli->error);
    }
    $mysqli->close();
    ac_admin_success(array('id' => $id));
} catch (Exception $e) {
    if ($mysqli) $mysqli->close();
    ac_admin_fail($e->getMessage());
}

