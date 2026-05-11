<?php
/**
 * Term Feedback – distinct (class, section, period) tuples already saved this session.
 *
 * Admin-only. Mirrors Termfeedback_model::list_distinct_periods_for_session() and matches the
 * "All saved term feedback" table at the top of admin/termfeedback/index.php.
 *
 * POST JSON:
 *   { user_type: "admin"|"teacher", staff_id?: int }
 *
 * Response:
 *   { success: true, items: [
 *       { class_id, section_id, period_start_month, period_end_month, class_name, section_name }, ...
 *   ] }
 *
 * Teachers receive an empty list (history view is intentionally not shown to them, matching the web).
 */

require_once __DIR__ . '/tf_bootstrap.php';

$body = tf_read_json_body();
tf_require_api_secret($body);

$mysqli = tf_mysqli_connect();
try {
    $caller = tf_resolve_caller($mysqli, $body);
    if (!$caller['show_history']) {
        $mysqli->close();
        tf_json_out(['success' => true, 'items' => []]);
    }

    $session_id = (int) $caller['session_id'];
    if ($session_id < 1) {
        $mysqli->close();
        tf_json_out(['success' => true, 'items' => []]);
    }

    $sql = "SELECT tf.class_id, tf.section_id,
                   tf.period_start_month, tf.period_end_month,
                   MAX(c.class)   AS class_name,
                   MAX(sec.section) AS section_name
            FROM term_feedback tf
            LEFT JOIN classes  c   ON c.id   = tf.class_id
            LEFT JOIN sections sec ON sec.id = tf.section_id
            WHERE tf.session_id = $session_id
            GROUP BY tf.class_id, tf.section_id, tf.period_start_month, tf.period_end_month
            ORDER BY class_name ASC, section_name ASC,
                     tf.period_start_month ASC, tf.period_end_month ASC";

    $res = $mysqli->query($sql);
    if (!$res) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }
    $items = [];
    while ($row = $res->fetch_assoc()) {
        $items[] = [
            'class_id'           => (int) ($row['class_id']   ?? 0),
            'section_id'         => (int) ($row['section_id'] ?? 0),
            'period_start_month' => (string) ($row['period_start_month'] ?? ''),
            'period_end_month'   => (string) ($row['period_end_month']   ?? ''),
            'class_name'         => (string) ($row['class_name']   ?? ''),
            'section_name'       => (string) ($row['section_name'] ?? ''),
        ];
    }
    $mysqli->close();
    tf_json_out(['success' => true, 'items' => $items]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    tf_json_out(['success' => false, 'error' => $e->getMessage(), 'items' => []]);
}
