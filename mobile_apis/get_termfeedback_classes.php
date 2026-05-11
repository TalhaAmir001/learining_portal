<?php
/**
 * Term Feedback – list of classes the caller may load feedback for.
 *
 * POST JSON:
 *   { user_type: "admin"|"teacher", staff_id?: int }
 *
 * Response: { success: bool, classes: [{ id, class_name }, ...], error? }
 *
 * Admin sees all classes; teacher sees only the classes from their lesson scope
 * (class_teacher + subject_timetable for the current session).
 */

require_once __DIR__ . '/tf_bootstrap.php';

$body = tf_read_json_body();
tf_require_api_secret($body);

$mysqli = tf_mysqli_connect();
try {
    $caller = tf_resolve_caller($mysqli, $body);
    $classes = [];

    if ($caller['role'] === 'teacher') {
        $allowed_class_ids = array_keys($caller['scope']);
        if (empty($allowed_class_ids)) {
            tf_json_out(['success' => true, 'classes' => []]);
        }
        $ids_csv = implode(',', array_map('intval', $allowed_class_ids));
        $sql = "SELECT id, class AS class_name FROM classes WHERE id IN ($ids_csv) ORDER BY class ASC";
    } else {
        $sql = "SELECT id, class AS class_name FROM classes ORDER BY class ASC";
    }

    $res = $mysqli->query($sql);
    if (!$res) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }
    while ($row = $res->fetch_assoc()) {
        $classes[] = [
            'id'         => (int) $row['id'],
            'class_name' => (string) ($row['class_name'] ?? ''),
        ];
    }
    $mysqli->close();
    tf_json_out([
        'success'      => true,
        'classes'      => $classes,
        'show_history' => $caller['show_history'],
        'can_save'     => $caller['can_save'],
    ]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    tf_json_out(['success' => false, 'error' => $e->getMessage(), 'classes' => []]);
}
