<?php
/**
 * Admin Academics meta for Flutter admin screens.
 * GET (optional): api_secret when AC_API_SECRET is set.
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

    $classes = array();
    $r = $mysqli->query('SELECT id, class AS name FROM classes ORDER BY id ASC');
    if ($r) {
        while ($row = $r->fetch_assoc()) {
            $classes[] = array('id' => (int) $row['id'], 'name' => (string) $row['name']);
        }
    }

    $sections = array();
    $r = $mysqli->query('SELECT id, section AS name FROM sections ORDER BY id ASC');
    if ($r) {
        while ($row = $r->fetch_assoc()) {
            $sections[] = array('id' => (int) $row['id'], 'name' => (string) $row['name']);
        }
    }

    $class_sections = array();
    $r = $mysqli->query(
        'SELECT cs.id, cs.class_id, cs.section_id, c.class AS class_name, s.section AS section_name
         FROM class_sections cs
         INNER JOIN classes c ON c.id = cs.class_id
         INNER JOIN sections s ON s.id = cs.section_id
         ORDER BY cs.class_id ASC, cs.section_id ASC'
    );
    if ($r) {
        while ($row = $r->fetch_assoc()) {
            $class_sections[] = array(
                'id' => (int) $row['id'],
                'class_id' => (int) $row['class_id'],
                'section_id' => (int) $row['section_id'],
                'class_name' => (string) $row['class_name'],
                'section_name' => (string) $row['section_name'],
            );
        }
    }

    $subjects = array();
    $r = $mysqli->query('SELECT id, name, code, type FROM subjects ORDER BY id ASC');
    if ($r) {
        while ($row = $r->fetch_assoc()) {
            $subjects[] = array(
                'id' => (int) $row['id'],
                'name' => (string) ($row['name'] ?? ''),
                'code' => (string) ($row['code'] ?? ''),
                'type' => (string) ($row['type'] ?? ''),
            );
        }
    }

    $teachers = array();
    $r = $mysqli->query("SELECT id, name, surname, employee_id FROM staff WHERE is_active = 1 ORDER BY name ASC, surname ASC");
    if ($r) {
        while ($row = $r->fetch_assoc()) {
            $teachers[] = array(
                'id' => (int) $row['id'],
                'name' => (string) ($row['name'] ?? ''),
                'surname' => (string) ($row['surname'] ?? ''),
                'employee_id' => (string) ($row['employee_id'] ?? ''),
            );
        }
    }

    $sessions = array();
    // Standard Smart School table is usually `sessions` (id, session).
    $r = $mysqli->query('SELECT id, session FROM sessions ORDER BY id DESC');
    if ($r) {
        while ($row = $r->fetch_assoc()) {
            $sessions[] = array(
                'id' => (int) $row['id'],
                'name' => (string) ($row['session'] ?? ''),
            );
        }
    }

    $mysqli->close();
    ac_admin_success(array(
        'current_session_id' => $session_id,
        'classes' => $classes,
        'sections' => $sections,
        'class_sections' => $class_sections,
        'subjects' => $subjects,
        'teachers' => $teachers,
        'sessions' => $sessions,
    ));
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    ac_admin_fail($e->getMessage(), array(
        'current_session_id' => 0,
        'classes' => array(),
        'sections' => array(),
        'class_sections' => array(),
        'subjects' => array(),
        'teachers' => array(),
        'sessions' => array(),
    ));
}

