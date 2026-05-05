<?php
/**
 * GET: session_id, class_id, section_id, staff_id, date_from, date_to, read_status (read|unread|''), critical_only (0|1), search, start, length
 */
require_once __DIR__ . '/zlc_bootstrap.php';

try {
    $mysqli = zlc_mysqli_connect();
    $session_id = isset($_GET['session_id']) ? (int) $_GET['session_id'] : 0;
    $class_id = isset($_GET['class_id']) ? (int) $_GET['class_id'] : 0;
    $section_id = isset($_GET['section_id']) ? (int) $_GET['section_id'] : 0;
    $staff_id = isset($_GET['staff_id']) ? (int) $_GET['staff_id'] : 0;
    $date_from = isset($_GET['date_from']) ? trim((string) $_GET['date_from']) : '';
    $date_to = isset($_GET['date_to']) ? trim((string) $_GET['date_to']) : '';
    $read_status = isset($_GET['read_status']) ? trim((string) $_GET['read_status']) : '';
    $critical_only = isset($_GET['critical_only']) ? (int) $_GET['critical_only'] : 0;
    $search = isset($_GET['search']) ? trim((string) $_GET['search']) : '';
    $start = isset($_GET['start']) ? max(0, (int) $_GET['start']) : 0;
    $length = isset($_GET['length']) ? min(200, max(1, (int) $_GET['length'])) : 50;

    $where = array('1=1');
    if ($session_id > 0) {
        $where[] = 'lf.session_id = ' . (int) $session_id;
    }
    if ($class_id > 0) {
        $where[] = 'lf.class_id = ' . (int) $class_id;
    }
    if ($section_id > 0) {
        $where[] = 'lf.section_id = ' . (int) $section_id;
    }
    if ($staff_id > 0) {
        $where[] = 'lf.staff_id = ' . (int) $staff_id;
    }
    if ($date_from !== '' && preg_match('/^\\d{4}-\\d{2}-\\d{2}$/', $date_from)) {
        $where[] = "lf.class_date >= '" . $mysqli->real_escape_string($date_from) . "'";
    }
    if ($date_to !== '' && preg_match('/^\\d{4}-\\d{2}-\\d{2}$/', $date_to)) {
        $where[] = "lf.class_date <= '" . $mysqli->real_escape_string($date_to) . "'";
    }
    if ($read_status === 'read') {
        $where[] = 'lf.read_at IS NOT NULL';
    } elseif ($read_status === 'unread') {
        $where[] = 'lf.read_at IS NULL';
    }
    if ($critical_only) {
        $where[] = 'lf.behavior_rating < 3 AND lf.behavior_rating > 0';
    }
    if ($search !== '') {
        $s = $mysqli->real_escape_string($search);
        $where[] = "(st.firstname LIKE '%$s%' OR st.lastname LIKE '%$s%' OR conf.title LIKE '%$s%' OR lf.comment LIKE '%$s%')";
    }
    $wSql = implode(' AND ', $where);
    $sql = "SELECT SQL_CALC_FOUND_ROWS lf.*, st.firstname, st.lastname, st.admission_no,
        c.class, sec.section,
        CONCAT(COALESCE(sf.name,''),' ',COALESCE(sf.surname,'')) AS teacher_name,
        conf.title AS conference_title
        FROM live_class_feedback lf
        INNER JOIN students st ON st.id = lf.student_id
        LEFT JOIN classes c ON c.id = lf.class_id
        LEFT JOIN sections sec ON sec.id = lf.section_id
        LEFT JOIN staff sf ON sf.id = lf.staff_id
        LEFT JOIN conferences conf ON conf.id = lf.conference_id
        WHERE $wSql
        ORDER BY lf.id DESC
        LIMIT " . (int) $start . ', ' . (int) $length;
    $res = $mysqli->query($sql);
    if (!$res) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }
    $rows = array();
    while ($row = $res->fetch_assoc()) {
        $rows[] = $row;
    }
    $totalFiltered = 0;
    $r2 = $mysqli->query('SELECT FOUND_ROWS() AS c');
    if ($r2 && $r2->num_rows > 0) {
        $totalFiltered = (int) $r2->fetch_assoc()['c'];
    }
    zlc_json_out(array('success' => true, 'items' => $rows, 'records_filtered' => $totalFiltered));
} catch (Exception $e) {
    zlc_json_out(array('success' => false, 'error' => $e->getMessage(), 'items' => array()));
}
