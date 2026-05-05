<?php
/**
 * Academics — timetable meta: classes, sections, subject groups, subjects, rooms, teachers.
 * GET (optional): api_secret when AC_API_SECRET is set.
 */

require_once __DIR__ . '/ac_bootstrap.php';

$mysqli = null;
try {
    $mysqli = ac_mysqli_connect();
    ac_require_api_secret(array_merge($_GET, array()));

    $session_id = ac_current_session_id($mysqli);
    if ($session_id <= 0) {
        throw new Exception('Could not resolve current session.');
    }

    $day_order = ac_ordered_weekday_keys($mysqli);

    $classes = array();
    $r = $mysqli->query('SELECT id, class FROM classes ORDER BY class ASC');
    if ($r) {
        while ($row = $r->fetch_assoc()) {
            $classes[] = array(
                'id' => (int) $row['id'],
                'name' => (string) ($row['class'] ?? ''),
            );
        }
    }

    $sections = array();
    $r = $mysqli->query(
        'SELECT cs.class_id, cs.section_id, s.section AS name
        FROM class_sections cs
        INNER JOIN sections s ON s.id = cs.section_id
        ORDER BY cs.class_id ASC, s.section ASC'
    );
    if ($r) {
        while ($row = $r->fetch_assoc()) {
            $sections[] = array(
                'class_id' => (int) $row['class_id'],
                'section_id' => (int) $row['section_id'],
                'name' => (string) ($row['name'] ?? ''),
            );
        }
    }

    $subject_groups = array();
    $r = $mysqli->query(
        'SELECT DISTINCT sg.id, sg.name
        FROM subject_groups sg
        INNER JOIN subject_timetable st ON st.subject_group_id = sg.id
        WHERE st.session_id = ' . (int) $session_id . '
        ORDER BY sg.name ASC'
    );
    if ($r) {
        while ($row = $r->fetch_assoc()) {
            $subject_groups[] = array(
                'id' => (int) $row['id'],
                'name' => (string) ($row['name'] ?? ''),
            );
        }
    }

    $class_section_groups = array();
    $r = $mysqli->query(
        'SELECT DISTINCT st.class_id, st.section_id, st.subject_group_id
        FROM subject_timetable st
        WHERE st.session_id = ' . (int) $session_id . '
        ORDER BY st.class_id, st.section_id, st.subject_group_id'
    );
    if ($r) {
        while ($row = $r->fetch_assoc()) {
            $class_section_groups[] = array(
                'class_id' => (int) $row['class_id'],
                'section_id' => (int) $row['section_id'],
                'subject_group_id' => (int) $row['subject_group_id'],
            );
        }
    }

    $subject_group_subjects = array();
    $r = $mysqli->query(
        'SELECT sgs.id AS subject_group_subject_id, sgs.subject_group_id, sgs.subject_id,
            sub.name AS subject_name, sub.code AS subject_code
        FROM subject_group_subjects sgs
        INNER JOIN subjects sub ON sub.id = sgs.subject_id
        WHERE sgs.session_id = ' . (int) $session_id . '
        ORDER BY sub.name ASC'
    );
    if ($r) {
        while ($row = $r->fetch_assoc()) {
            $subject_group_subjects[] = array(
                'subject_group_subject_id' => (int) $row['subject_group_subject_id'],
                'subject_group_id' => (int) $row['subject_group_id'],
                'subject_id' => (int) $row['subject_id'],
                'subject_name' => (string) ($row['subject_name'] ?? ''),
                'subject_code' => (string) ($row['subject_code'] ?? ''),
            );
        }
    }

    $rooms = array();
    $r = $mysqli->query(
        "SELECT DISTINCT TRIM(room_no) AS r FROM subject_timetable
        WHERE session_id = " . (int) $session_id . "
          AND room_no IS NOT NULL AND TRIM(room_no) <> ''
        ORDER BY r ASC"
    );
    if ($r) {
        while ($row = $r->fetch_assoc()) {
            $rooms[] = (string) $row['r'];
        }
    }

    $staff_teachers = array();
    $r = $mysqli->query(
        'SELECT DISTINCT s.id, s.name, s.surname, s.employee_id
        FROM staff s
        WHERE s.is_active = 1
          AND s.id IN (SELECT DISTINCT staff_id FROM subject_timetable WHERE session_id = ' . (int) $session_id . ')
        ORDER BY s.name ASC, s.surname ASC'
    );
    if ($r) {
        while ($row = $r->fetch_assoc()) {
            $staff_teachers[] = array(
                'id' => (int) $row['id'],
                'name' => (string) ($row['name'] ?? ''),
                'surname' => (string) ($row['surname'] ?? ''),
                'employee_id' => (string) ($row['employee_id'] ?? ''),
            );
        }
    }

    $mysqli->close();
    ac_json_out(array(
        'success' => true,
        'session_id' => $session_id,
        'day_order' => $day_order,
        'classes' => $classes,
        'sections' => $sections,
        'subject_groups' => $subject_groups,
        'class_section_subject_groups' => $class_section_groups,
        'subject_group_subjects' => $subject_group_subjects,
        'rooms' => $rooms,
        'staff_teachers' => $staff_teachers,
    ));
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    ac_json_out(array(
        'success' => false,
        'error' => $e->getMessage(),
        'session_id' => 0,
        'day_order' => array(),
        'classes' => array(),
        'sections' => array(),
        'subject_groups' => array(),
        'class_section_subject_groups' => array(),
        'subject_group_subjects' => array(),
        'rooms' => array(),
        'staff_teachers' => array(),
    ));
}
