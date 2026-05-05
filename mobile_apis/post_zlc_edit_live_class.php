<?php
require_once __DIR__ . '/zlc_bootstrap.php';

try {
    $body = zlc_read_json_body();
    zlc_require_api_secret($body);
    $id = isset($body['id']) ? (int) $body['id'] : 0;
    $title = isset($body['title']) ? trim((string) $body['title']) : '';
    $date = isset($body['date']) ? trim((string) $body['date']) : '';
    $start_time = isset($body['start_time']) ? trim((string) $body['start_time']) : '';
    $duration = isset($body['duration']) ? (int) $body['duration'] : 0;
    $staff_id = isset($body['staff_id']) ? (int) $body['staff_id'] : 0;
    $description = isset($body['description']) ? (string) $body['description'] : '';
    $section_ids = isset($body['section_ids']) && is_array($body['section_ids']) ? $body['section_ids'] : null;
    if ($id <= 0 || $title === '' || $date === '' || $start_time === '' || $duration <= 0 || $staff_id <= 0) {
        throw new Exception('id, title, date, start_time, duration, staff_id required');
    }
    $ts = strtotime($date . ' ' . $start_time);
    if ($ts === false) {
        throw new Exception('Invalid datetime');
    }
    $datetime = date('Y-m-d H:i:s', $ts);
    $mysqli = zlc_mysqli_connect();
    $titleEsc = $mysqli->real_escape_string($title);
    $descEsc = $mysqli->real_escape_string($description);
    $sql = "UPDATE conferences SET title='" . $titleEsc . "', `date`='" . $datetime . "', duration=" . (int) $duration . ', staff_id=' . (int) $staff_id . ", description='" . $descEsc . "' WHERE id=" . (int) $id;
    if (!$mysqli->query($sql)) {
        throw new Exception('Update failed: ' . $mysqli->error);
    }
    if ($section_ids !== null) {
        $mysqli->query('DELETE FROM conference_sections WHERE conference_id=' . (int) $id);
        foreach ($section_ids as $sid) {
            $sid = (int) $sid;
            if ($sid <= 0) {
                continue;
            }
            $mysqli->query('INSERT INTO conference_sections (conference_id, cls_section_id) VALUES (' . (int) $id . ', ' . $sid . ')');
        }
    }
    zlc_json_out(array('success' => true));
} catch (Exception $e) {
    zlc_json_out(array('success' => false, 'error' => $e->getMessage()));
}
