<?php
/**
 * Set class teachers for one class + section (admin).
 *
 * JSON: { class_id: int, section_id: int, staff_ids: int[] }
 */
require_once __DIR__ . '/ac_admin_bootstrap.php';

$mysqli = null;
try {
    $mysqli = ac_mysqli_connect();
    $body = ac_read_json_body();
    ac_require_api_secret($body);
    ac_admin_require_fields($body, array('class_id', 'section_id', 'staff_ids'));

    $session_id = ac_current_session_id($mysqli);
    if ($session_id <= 0) {
        throw new Exception('Could not resolve current session.');
    }

    $class_id = (int) $body['class_id'];
    $section_id = (int) $body['section_id'];
    $staff_ids = is_array($body['staff_ids']) ? $body['staff_ids'] : array();

    if ($class_id <= 0 || $section_id <= 0) {
        throw new Exception('Invalid class_id / section_id.');
    }

    // Normalize staff ids
    $clean = array();
    foreach ($staff_ids as $sid) {
        $v = (int) $sid;
        if ($v > 0) $clean[] = $v;
    }
    $clean = array_values(array_unique($clean));

    $mysqli->begin_transaction();

    // Replace-all semantics keeps client logic simple and matches final state.
    if (!$mysqli->query(
        'DELETE FROM class_teacher WHERE class_id=' . $class_id . ' AND section_id=' . $section_id . ' AND session_id=' . (int) $session_id
    )) {
        throw new Exception('Delete existing failed: ' . $mysqli->error);
    }

    foreach ($clean as $staff_id) {
        // Validate staff active
        $r = $mysqli->query('SELECT id FROM staff WHERE id=' . (int) $staff_id . ' AND is_active=1 LIMIT 1');
        if (!$r || $r->num_rows === 0) {
            throw new Exception('Invalid or inactive staff_id: ' . $staff_id);
        }
        $sql = 'INSERT INTO class_teacher (class_id, section_id, staff_id, session_id)
                VALUES (' . $class_id . ', ' . $section_id . ', ' . (int) $staff_id . ', ' . (int) $session_id . ')';
        if (!$mysqli->query($sql)) {
            throw new Exception('Insert failed: ' . $mysqli->error);
        }
    }

    $mysqli->commit();
    $mysqli->close();
    ac_admin_success(array(
        'current_session_id' => $session_id,
        'class_id' => $class_id,
        'section_id' => $section_id,
        'staff_ids' => $clean,
    ));
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->rollback();
        $mysqli->close();
    }
    ac_admin_fail($e->getMessage());
}

