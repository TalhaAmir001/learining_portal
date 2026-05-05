<?php
/**
 * GET: conference_id, viewer_staff_id (optional, for staff start rules)
 */
require_once __DIR__ . '/zlc_bootstrap.php';

try {
    $cid = isset($_GET['conference_id']) ? (int) $_GET['conference_id'] : 0;
    $viewer_staff_id = isset($_GET['viewer_staff_id']) ? (int) $_GET['viewer_staff_id'] : 0;
    if ($cid <= 0) {
        throw new Exception('conference_id required');
    }
    $mysqli = zlc_mysqli_connect();
    $row = zlc_conference_row($mysqli, $cid);
    if (!$row) {
        throw new Exception('Conference not found');
    }
    $settings = zlc_zoom_settings($mysqli);
    $resp = array();
    if (!empty($row['return_response'])) {
        $j = json_decode($row['return_response'], true);
        if (is_array($j)) {
            $resp = $j;
        }
    }
    $meeting_id = isset($resp['id']) ? (string) $resp['id'] : '';
    $join_url = isset($resp['join_url']) ? (string) $resp['join_url'] : '';
    $start_url = isset($resp['start_url']) ? (string) $resp['start_url'] : '';
    $created_id = isset($row['created_id']) ? (int) $row['created_id'] : 0;
    $host_staff_id = isset($row['staff_id']) ? (int) $row['staff_id'] : 0;
    $can_start = false;
    if ($viewer_staff_id > 0 && ($viewer_staff_id === $created_id || $viewer_staff_id === $host_staff_id)) {
        $can_start = true;
    }
    $host_label = '';
    $hs = $mysqli->query('SELECT name, surname, employee_id FROM staff WHERE id = ' . (int) $host_staff_id . ' LIMIT 1');
    if ($hs && $hs->num_rows > 0) {
        $h = $hs->fetch_assoc();
        $host_label = trim(($h['name'] ?? '') . ' ' . ($h['surname'] ?? '')) . ' (' . ($h['employee_id'] ?? '') . ')';
    }
    zlc_json_out(array(
        'success' => true,
        'conference_id' => $cid,
        'title' => $row['title'] ?? '',
        'date' => $row['date'] ?? '',
        'duration' => isset($row['duration']) ? (int) $row['duration'] : 0,
        'password' => $row['password'] ?? '',
        'purpose' => $row['purpose'] ?? '',
        'meeting_id' => $meeting_id,
        'join_url' => $join_url,
        'start_url' => $can_start ? $start_url : '',
        'host_display_name' => $host_label,
        'use_zoom_app' => $settings ? (int) $settings['use_zoom_app'] : 0,
        'use_zoom_app_user' => $settings ? (int) $settings['use_zoom_app_user'] : 0,
    ));
} catch (Exception $e) {
    zlc_json_out(array('success' => false, 'error' => $e->getMessage()));
}
