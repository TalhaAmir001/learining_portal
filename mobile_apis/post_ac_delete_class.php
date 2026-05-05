<?php
/**
 * Delete class (admin). Also deletes class_sections rows (Portal behavior).
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

    $mysqli->begin_transaction();
    if (!$mysqli->query('DELETE FROM class_sections WHERE class_id=' . $id)) {
        throw new Exception('Delete class_sections failed: ' . $mysqli->error);
    }
    if (!$mysqli->query('DELETE FROM classes WHERE id=' . $id . ' LIMIT 1')) {
        throw new Exception('Delete class failed: ' . $mysqli->error);
    }
    $mysqli->commit();
    $mysqli->close();
    ac_admin_success(array('id' => $id));
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->rollback();
        $mysqli->close();
    }
    ac_admin_fail($e->getMessage());
}

