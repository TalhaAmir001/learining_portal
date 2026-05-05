<?php
/**
 * Delete an announcement post (admin).
 * JSON: { id: int }
 */
require_once __DIR__ . '/ac_admin_bootstrap.php';

function ann_unlink_file($relative) {
    $relative = (string) $relative;
    if ($relative === '' || strpos($relative, '..') !== false) return;
    $path = __DIR__ . '/../Portal 2/' . $relative;
    if (is_file($path)) {
        @unlink($path);
    }
}

$mysqli = null;
try {
    $mysqli = ac_mysqli_connect();
    $body = ac_read_json_body();
    ac_require_api_secret($body);
    ac_admin_require_fields($body, array('id'));

    $session_id = ac_current_session_id($mysqli);
    if ($session_id <= 0) throw new Exception('Could not resolve current session.');

    $id = (int) $body['id'];
    if ($id <= 0) throw new Exception('Invalid id.');

    $r = $mysqli->query('SELECT media_path FROM announcement_posts WHERE id=' . (int) $id . ' AND session_id=' . (int) $session_id . ' LIMIT 1');
    if ($r && $r->num_rows > 0) {
        $row = $r->fetch_assoc();
        if (!empty($row['media_path'])) {
            ann_unlink_file($row['media_path']);
        }
    }

    if (!$mysqli->query('DELETE FROM announcement_posts WHERE id=' . (int) $id . ' AND session_id=' . (int) $session_id . ' LIMIT 1')) {
        throw new Exception('Delete failed: ' . $mysqli->error);
    }

    $mysqli->close();
    ac_admin_success(array('id' => $id));
} catch (Exception $e) {
    if ($mysqli) $mysqli->close();
    ac_admin_fail($e->getMessage());
}

