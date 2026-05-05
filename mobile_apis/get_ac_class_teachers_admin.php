<?php
/**
 * Class teacher assignments (admin).
 * GET (optional): api_secret when AC_API_SECRET is set.
 *
 * Returns grouped assignments per (class_id, section_id) for current session.
 */
require_once __DIR__ . '/ac_admin_bootstrap.php';

$mysqli = null;
try {
    $mysqli = ac_mysqli_connect();
    ac_require_api_secret(array_merge($_GET, array()));

    $session_id = ac_current_session_id($mysqli);
    if ($session_id <= 0) {
        throw new Exception('Could not resolve current session.');
    }

    $sql = "SELECT
            ct.id,
            ct.class_id,
            ct.section_id,
            c.class AS class_name,
            s.section AS section_name,
            ct.staff_id,
            st.name AS staff_name,
            st.surname AS staff_surname,
            st.employee_id
        FROM class_teacher ct
        INNER JOIN classes c ON c.id = ct.class_id
        INNER JOIN sections s ON s.id = ct.section_id
        INNER JOIN staff st ON st.id = ct.staff_id
        WHERE ct.session_id = " . (int) $session_id . "
          AND st.is_active = 1
        ORDER BY ct.class_id ASC, ct.section_id ASC, st.name ASC, st.surname ASC";

    $res = $mysqli->query($sql);
    if (!$res) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }

    $groups = array();
    while ($row = $res->fetch_assoc()) {
        $key = ((int) $row['class_id']) . ':' . ((int) $row['section_id']);
        if (!isset($groups[$key])) {
            $groups[$key] = array(
                'class_id' => (int) $row['class_id'],
                'section_id' => (int) $row['section_id'],
                'class_name' => (string) $row['class_name'],
                'section_name' => (string) $row['section_name'],
                'teachers' => array(),
            );
        }
        $groups[$key]['teachers'][] = array(
            'id' => (int) $row['id'],
            'staff_id' => (int) $row['staff_id'],
            'name' => (string) $row['staff_name'],
            'surname' => (string) $row['staff_surname'],
            'employee_id' => (string) $row['employee_id'],
        );
    }

    $mysqli->close();
    ac_admin_success(array(
        'current_session_id' => $session_id,
        'items' => array_values($groups),
    ));
} catch (Exception $e) {
    if ($mysqli) $mysqli->close();
    ac_admin_fail($e->getMessage(), array('current_session_id' => 0, 'items' => array()));
}

