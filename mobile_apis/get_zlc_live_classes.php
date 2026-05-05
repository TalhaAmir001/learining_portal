<?php
/**
 * GET: role=admin|teacher|student|guardian, staff_id (admin/teacher), student_id (student/guardian)
 */
require_once __DIR__ . '/zlc_bootstrap.php';

try {
    $mysqli = zlc_mysqli_connect();
    $session_id = zlc_current_session_id($mysqli);
    if ($session_id <= 0) {
        throw new Exception('Could not resolve session');
    }
    $role = isset($_GET['role']) ? strtolower(trim((string) $_GET['role'])) : '';
    $staff_id = isset($_GET['staff_id']) ? (int) $_GET['staff_id'] : 0;
    $student_id = isset($_GET['student_id']) ? (int) $_GET['student_id'] : 0;

    $list = array();
    if ($role === 'teacher' && $staff_id > 0) {
        $sql = 'SELECT c.* FROM conferences c
            WHERE c.session_id = ' . (int) $session_id . " AND c.purpose = 'class' AND c.staff_id = " . (int) $staff_id . '
            ORDER BY DATE(c.date) DESC, c.date DESC';
    } elseif ($role === 'admin' && $staff_id > 0) {
        $sql = 'SELECT c.* FROM conferences c
            WHERE c.session_id = ' . (int) $session_id . " AND c.purpose = 'class' AND c.staff_id = " . (int) $staff_id . '
            ORDER BY DATE(c.date) DESC, c.date DESC';
    } elseif ($role === 'admin') {
        $sql = 'SELECT c.* FROM conferences c
            WHERE c.session_id = ' . (int) $session_id . " AND c.purpose = 'class'
            ORDER BY DATE(c.date) DESC, c.date DESC";
    } elseif (($role === 'student' || $role === 'guardian') && $student_id > 0) {
        $sql = 'SELECT DISTINCT c.* FROM conferences c
            INNER JOIN conference_sections cs ON cs.conference_id = c.id
            INNER JOIN class_sections cs2 ON cs2.id = cs.cls_section_id
            INNER JOIN student_session ss ON ss.class_id = cs2.class_id AND ss.section_id = cs2.section_id
            WHERE ss.student_id = ' . (int) $student_id . ' AND ss.session_id = ' . (int) $session_id . '
              AND c.session_id = ' . (int) $session_id . " AND c.purpose = 'class'
            ORDER BY DATE(c.date) DESC, c.date DESC";
    } else {
        throw new Exception('role and staff_id/student_id required');
    }
    $res = $mysqli->query($sql);
    if (!$res) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }
    while ($row = $res->fetch_assoc()) {
        $cid = (int) $row['id'];
        $list[] = array(
            'conference' => $row,
            'sections' => zlc_conference_sections($mysqli, $cid),
        );
    }
    zlc_json_out(array('success' => true, 'items' => $list, 'session_id' => $session_id));
} catch (Exception $e) {
    zlc_json_out(array('success' => false, 'error' => $e->getMessage(), 'items' => array()));
}
