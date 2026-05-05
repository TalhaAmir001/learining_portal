<?php
/**
 * GET: staff_id (0 = all meetings for admin-style listing), session implied from sch_settings.
 */
require_once __DIR__ . '/zlc_bootstrap.php';

try {
    $mysqli = zlc_mysqli_connect();
    $session_id = zlc_current_session_id($mysqli);
    if ($session_id <= 0) {
        throw new Exception('Could not resolve session');
    }
    $staff_id = isset($_GET['staff_id']) ? (int) $_GET['staff_id'] : 0;
    if ($staff_id > 0) {
        $sql = "SELECT c.* FROM conferences c
            WHERE c.session_id = " . (int) $session_id . " AND c.purpose = 'meeting' AND (
                c.created_id = " . (int) $staff_id . "
                OR c.id IN (SELECT conference_id FROM conference_staff WHERE staff_id = " . (int) $staff_id . ')
            )
            ORDER BY DATE(c.date) DESC, c.date DESC';
    } else {
        $sql = "SELECT c.* FROM conferences c
            WHERE c.session_id = " . (int) $session_id . " AND c.purpose = 'meeting'
            ORDER BY DATE(c.date) DESC, c.date DESC";
    }
    $res = $mysqli->query($sql);
    if (!$res) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }
    $rows = array();
    while ($row = $res->fetch_assoc()) {
        $rows[] = $row;
    }
    zlc_json_out(array('success' => true, 'items' => $rows, 'session_id' => $session_id));
} catch (Exception $e) {
    zlc_json_out(array('success' => false, 'error' => $e->getMessage(), 'items' => array()));
}
