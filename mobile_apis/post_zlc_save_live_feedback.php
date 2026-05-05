<?php
require_once __DIR__ . '/zlc_bootstrap.php';

try {
    $body = zlc_read_json_body();
    zlc_require_api_secret($body);
    $student_id = isset($body['student_id']) ? (int) $body['student_id'] : 0;
    $conference_id = isset($body['conference_id']) ? (int) $body['conference_id'] : 0;
    $rating = isset($body['behavior_rating']) ? (int) $body['behavior_rating'] : 0;
    $comment = isset($body['comment']) ? trim((string) $body['comment']) : '';
    if ($student_id <= 0 || $conference_id <= 0 || $rating < 1 || $rating > 5) {
        throw new Exception('student_id, conference_id, behavior_rating 1–5 required');
    }
    if (strlen($comment) > 8000) {
        $comment = substr($comment, 0, 8000);
    }
    $mysqli = zlc_mysqli_connect();
    $session_id = zlc_current_session_id($mysqli);
    if (!zlc_student_can_access_conference($mysqli, $student_id, $conference_id, $session_id)) {
        throw new Exception('You cannot submit feedback for this class.');
    }
    $live = zlc_conference_row($mysqli, $conference_id);
    if (!$live) {
        throw new Exception('Live class not found');
    }
    $class_id = !empty($live['class_id']) ? (int) $live['class_id'] : 0;
    $section_id = !empty($live['section_id']) ? (int) $live['section_id'] : 0;
    if ($class_id === 0 || $section_id === 0) {
        $secs = zlc_conference_sections($mysqli, $conference_id);
        if (!empty($secs)) {
            $class_id = (int) $secs[0]['class_id'];
            $section_id = (int) $secs[0]['section_id'];
        }
    }
    $class_date = date('Y-m-d');
    if (!empty($live['date'])) {
        $class_date = date('Y-m-d', strtotime($live['date']));
    }
    $staff_id = !empty($live['staff_id']) ? (int) $live['staff_id'] : (int) ($live['created_id'] ?? 0);
    $now = date('Y-m-d H:i:s');
    $commentEsc = $mysqli->real_escape_string($comment);
    $res = $mysqli->query('SELECT id FROM live_class_feedback WHERE student_id=' . (int) $student_id . ' AND conference_id=' . (int) $conference_id . ' LIMIT 1');
    if ($res && $res->num_rows > 0) {
        $id = (int) $res->fetch_assoc()['id'];
        $sql = "UPDATE live_class_feedback SET session_id=" . (int) $session_id . ', class_id=' . (int) $class_id . ', section_id=' . (int) $section_id . ', staff_id=' . (int) $staff_id . ", class_date='" . $mysqli->real_escape_string($class_date) . "', behavior_rating=" . (int) $rating . ", comment='" . $commentEsc . "', updated_at='" . $now . "' WHERE id=" . $id;
        if (!$mysqli->query($sql)) {
            throw new Exception('Update failed: ' . $mysqli->error);
        }
    } else {
        $sql = "INSERT INTO live_class_feedback (conference_id, student_id, session_id, class_id, section_id, staff_id, class_date, behavior_rating, comment, created_at, updated_at)
            VALUES (" . (int) $conference_id . ',' . (int) $student_id . ',' . (int) $session_id . ',' . (int) $class_id . ',' . (int) $section_id . ',' . (int) $staff_id . ",'" . $mysqli->real_escape_string($class_date) . "'," . (int) $rating . ",'" . $commentEsc . "','" . $now . "','" . $now . "')";
        if (!$mysqli->query($sql)) {
            throw new Exception('Insert failed: ' . $mysqli->error);
        }
    }
    $out = null;
    $r2 = $mysqli->query('SELECT * FROM live_class_feedback WHERE student_id=' . (int) $student_id . ' AND conference_id=' . (int) $conference_id . ' LIMIT 1');
    if ($r2 && $r2->num_rows > 0) {
        $out = $r2->fetch_assoc();
    }
    zlc_json_out(array('success' => true, 'feedback' => $out));
} catch (Exception $e) {
    zlc_json_out(array('success' => false, 'error' => $e->getMessage()));
}
