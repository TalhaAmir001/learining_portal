<?php
/**
 * Delete subject group (admin).
 * JSON: { id: int }
 */
require_once __DIR__ . '/ac_admin_bootstrap.php';

$mysqli = null;
try {
    $mysqli = ac_mysqli_connect();
    $body = ac_read_json_body();
    ac_require_api_secret($body);
    ac_admin_require_fields($body, array('id'));

    $session_id = ac_current_session_id($mysqli);
    if ($session_id <= 0) {
        throw new Exception('Could not resolve current session.');
    }

    $id = (int) $body['id'];
    if ($id <= 0) {
        throw new Exception('Invalid id.');
    }

    $mysqli->begin_transaction();
    $mysqli->query('DELETE FROM subject_group_subjects WHERE subject_group_id=' . $id . ' AND session_id=' . (int) $session_id);
    $mysqli->query('DELETE FROM subject_group_class_sections WHERE subject_group_id=' . $id . ' AND session_id=' . (int) $session_id);
    if (!$mysqli->query('DELETE FROM subject_groups WHERE id=' . $id . ' AND session_id=' . (int) $session_id . ' LIMIT 1')) {
        throw new Exception('Delete failed: ' . $mysqli->error);
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

