<?php
require_once __DIR__ . '/zlc_bootstrap.php';

try {
    $mysqli = zlc_mysqli_connect();
    $session_id = zlc_current_session_id($mysqli);
    if ($session_id <= 0) {
        throw new Exception('Could not resolve session');
    }
    $sql = "SELECT conferences.*,(SELECT COUNT(*) FROM conferences_history WHERE conferences_history.conference_id=conferences.id) as total_viewers,
        create_by.name as create_by_name, create_by.surname as create_by_surname, create_by.employee_id, staff_roles.role_id, create_by.employee_id as create_by_employee_id
        FROM conferences
        JOIN staff as create_by ON create_by.id = conferences.created_id
        JOIN staff_roles on staff_roles.staff_id=create_by.id
        WHERE purpose='meeting' AND status=2
        ORDER BY DATE(conferences.date) DESC, conferences.date ASC";
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
