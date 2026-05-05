<?php
/**
 * Delete one subject_timetable row for current session.
 * JSON: id (int).
 */

require_once __DIR__ . '/ac_bootstrap.php';

$mysqli = null;
try {
    $mysqli = ac_mysqli_connect();
    $body = ac_read_json_body();
    ac_require_api_secret($body);

    $session_id = ac_current_session_id($mysqli);
    if ($session_id <= 0) {
        throw new Exception('Could not resolve current session.');
    }

    $id = isset($body['id']) ? (int) $body['id'] : 0;
    if ($id <= 0) {
        throw new Exception('id is required.');
    }

    $res = $mysqli->query(
        'DELETE FROM subject_timetable WHERE id = ' . $id . ' AND session_id = ' . (int) $session_id . ' LIMIT 1'
    );
    if (!$res) {
        throw new Exception('Delete failed: ' . $mysqli->error);
    }
    if ($mysqli->affected_rows < 1) {
        throw new Exception('Row not found or wrong session.');
    }

    $mysqli->close();
    ac_json_out(array('success' => true, 'message' => 'Deleted.'));
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    ac_json_out(array('success' => false, 'error' => $e->getMessage()));
}
