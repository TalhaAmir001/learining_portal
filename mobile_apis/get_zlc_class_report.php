<?php
/**
 * GET: class_id, section_id
 */
require_once __DIR__ . '/zlc_bootstrap.php';

try {
    $class_id = isset($_GET['class_id']) ? (int) $_GET['class_id'] : 0;
    $section_id = isset($_GET['section_id']) ? (int) $_GET['section_id'] : 0;
    if ($class_id <= 0 || $section_id <= 0) {
        throw new Exception('class_id and section_id required');
    }
    $mysqli = zlc_mysqli_connect();
    $session_id = zlc_current_session_id($mysqli);
    if ($session_id <= 0) {
        throw new Exception('Could not resolve session');
    }
    $cEsc = (int) $class_id;
    $sEsc = (int) $section_id;
    $sql =
        "SELECT conferences.*, conference_sections.id as conferences_section_id, create_by.employee_id as create_bystaffid, for_create.employee_id as for_creatstaffid,
        (SELECT COUNT(*) FROM conferences_history
            INNER JOIN students on students.id=conferences_history.student_id
            INNER JOIN student_session on student_session.student_id=students.id
            WHERE student_session.class_id=" . $cEsc . " AND student_session.section_id=" . $sEsc . " AND student_session.session_id=" . (int) $session_id . "
            AND conferences_history.conference_id=conferences.id) as total_viewers,
        create_by.name as create_by_name, create_by.surname as create_by_surname,
        for_create.name as for_create_name, for_create.surname as for_create_surname,
        roles.name as create_by_role_name, for_create_role.name as create_for_role_name, staff_roles.role_id
        FROM conferences
        JOIN staff as create_by ON create_by.id = conferences.created_id
        JOIN staff as for_create ON for_create.id = conferences.staff_id
        INNER JOIN staff_roles on staff_roles.staff_id=conferences.created_id
        INNER JOIN roles on roles.id =staff_roles.role_id
        INNER JOIN staff_roles as for_create_staff_role on for_create_staff_role.staff_id=conferences.staff_id
        INNER JOIN roles as for_create_role on for_create_role.id =for_create_staff_role.role_id
        INNER JOIN conference_sections on conferences.id=conference_sections.conference_id
        INNER JOIN class_sections on class_sections.id =conference_sections.cls_section_id
        WHERE purpose='class' AND status=2 AND conferences.session_id=" . (int) $session_id . "
        AND class_sections.class_id=" . $cEsc . " AND class_sections.section_id=" . $sEsc . "
        ORDER BY DATE(conferences.date) DESC, conferences.date DESC";
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
