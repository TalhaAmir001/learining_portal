<?php
/**
 * GET: conference_id, type=student|staff, class_id (for student list), section_id
 */
require_once __DIR__ . '/zlc_bootstrap.php';

try {
    $conference_id = isset($_GET['conference_id']) ? (int) $_GET['conference_id'] : 0;
    $type = isset($_GET['type']) ? strtolower(trim((string) $_GET['type'])) : 'student';
    if ($conference_id <= 0) {
        throw new Exception('conference_id required');
    }
    $mysqli = zlc_mysqli_connect();
    $session_id = zlc_current_session_id($mysqli);
    $rows = array();
    if ($type === 'staff') {
        $sql = 'SELECT h.*, s.name as staff_name, s.surname as staff_surname, s.employee_id, r.name as role_name
            FROM conferences_history h
            INNER JOIN staff s ON s.id = h.staff_id
            INNER JOIN staff_roles sr ON sr.staff_id = s.id
            INNER JOIN roles r ON r.id = sr.role_id
            WHERE h.conference_id = ' . (int) $conference_id . ' AND h.staff_id IS NOT NULL
            ORDER BY h.id ASC';
        $res = $mysqli->query($sql);
        if (!$res) {
            throw new Exception('Query failed: ' . $mysqli->error);
        }
        while ($row = $res->fetch_assoc()) {
            $rows[] = $row;
        }
    } else {
        $class_id = isset($_GET['class_id']) ? (int) $_GET['class_id'] : 0;
        $section_id = isset($_GET['section_id']) ? (int) $_GET['section_id'] : 0;
        if ($class_id <= 0 || $section_id <= 0) {
            throw new Exception('class_id and section_id required for student viewers');
        }
        $sql = 'SELECT h.*, ss.class_id, ss.section_id, st.admission_no, st.roll_no, st.firstname, st.middlename, st.lastname, st.image, st.mobileno, st.email, st.father_name
            FROM conferences_history h
            INNER JOIN students st ON st.id = h.student_id
            INNER JOIN student_session ss ON ss.student_id = st.id
            WHERE h.conference_id = ' . (int) $conference_id . '
              AND ss.class_id = ' . (int) $class_id . '
              AND ss.section_id = ' . (int) $section_id . '
              AND ss.session_id = ' . (int) $session_id . '
            ORDER BY h.id ASC';
        $res = $mysqli->query($sql);
        if (!$res) {
            throw new Exception('Query failed: ' . $mysqli->error);
        }
        while ($row = $res->fetch_assoc()) {
            $rows[] = $row;
        }
    }
    zlc_json_out(array('success' => true, 'viewers' => $rows));
} catch (Exception $e) {
    zlc_json_out(array('success' => false, 'error' => $e->getMessage(), 'viewers' => array()));
}
