<?php
/**
 * Student Information — disabled students (web: Disabled Students).
 * GET: mode = filter | full
 *   filter: class_id (required), section_id (optional, 0 = all sections in class)
 *   full: search_text (min 2 chars)
 */

header('Content-Type: application/json; charset=utf-8');

function si_send_json($data) {
    $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    if ($json === false) {
        echo json_encode(['success' => false, 'error' => 'Failed to encode', 'students' => []]);
    } else {
        echo $json;
    }
}

$mysqli = null;
try {
    $mysqli = new mysqli(
        'localhost',
        'portal_beta',
        'X7&?C%Yx5[L-QyiL',
        'portal_beta'
    );
    if ($mysqli->connect_error) {
        throw new Exception('Database connection failed: ' . $mysqli->connect_error);
    }
    $mysqli->set_charset('utf8mb4');

    $sr = $mysqli->query("SELECT session_id FROM sch_settings ORDER BY id ASC LIMIT 1");
    if (!$sr || $sr->num_rows === 0) {
        throw new Exception('Could not resolve current session.');
    }
    $session_id = (int) $sr->fetch_assoc()['session_id'];

    $mode = isset($_REQUEST['mode']) ? trim((string) $_REQUEST['mode']) : 'filter';
    $students = [];

    if ($mode === 'filter') {
        $class_id = isset($_REQUEST['class_id']) ? (int) $_REQUEST['class_id'] : 0;
        if ($class_id <= 0) {
            throw new Exception('filter mode requires class_id.');
        }
        $section_id = isset($_REQUEST['section_id']) ? (int) $_REQUEST['section_id'] : 0;

        $sql = "SELECT
            ss.id AS student_session_id,
            st.id AS student_id,
            st.admission_no,
            st.roll_no,
            st.firstname,
            st.middlename,
            st.lastname,
            st.image,
            st.mobileno,
            st.email,
            st.gender,
            st.is_active,
            st.dis_reason,
            st.dis_note,
            c.id AS class_id,
            c.class AS class_name,
            sec.id AS section_id,
            sec.section AS section_name,
            IFNULL(cat.category, '') AS category
            FROM students st
            INNER JOIN student_session ss ON ss.student_id = st.id
            INNER JOIN classes c ON c.id = ss.class_id
            INNER JOIN sections sec ON sec.id = ss.section_id
            LEFT JOIN categories cat ON cat.id = st.category_id
            WHERE ss.session_id = " . $session_id . "
              AND st.is_active = 'no'
              AND ss.class_id = " . $class_id;
        if ($section_id > 0) {
            $sql .= " AND ss.section_id = " . $section_id;
        }
        $sql .= " ORDER BY st.id ASC";

        $result = $mysqli->query($sql);
        if (!$result) {
            throw new Exception('Query failed: ' . $mysqli->error);
        }
        while ($row = $result->fetch_assoc()) {
            $students[] = si_map_disabled_row($row);
        }
    } elseif ($mode === 'full') {
        $search_text = isset($_REQUEST['search_text']) ? trim((string) $_REQUEST['search_text']) : '';
        if (strlen($search_text) < 2) {
            throw new Exception('full mode requires search_text (at least 2 characters).');
        }
        $like = '%' . $mysqli->real_escape_string($search_text) . '%';

        $sql = "SELECT DISTINCT
            ss.id AS student_session_id,
            st.id AS student_id,
            st.admission_no,
            st.roll_no,
            st.firstname,
            st.middlename,
            st.lastname,
            st.image,
            st.mobileno,
            st.email,
            st.gender,
            st.is_active,
            st.dis_reason,
            st.dis_note,
            c.id AS class_id,
            c.class AS class_name,
            sec.id AS section_id,
            sec.section AS section_name,
            IFNULL(cat.category, '') AS category
            FROM students st
            INNER JOIN student_session ss ON ss.student_id = st.id
            INNER JOIN classes c ON c.id = ss.class_id
            INNER JOIN sections sec ON sec.id = ss.section_id
            LEFT JOIN categories cat ON cat.id = st.category_id
            LEFT JOIN school_houses sh ON sh.id = st.school_house_id
            WHERE ss.session_id = " . $session_id . "
              AND st.is_active = 'no'
              AND (
                st.firstname LIKE '" . $like . "'
                OR st.middlename LIKE '" . $like . "'
                OR st.lastname LIKE '" . $like . "'
                OR st.admission_no LIKE '" . $like . "'
                OR st.roll_no LIKE '" . $like . "'
                OR st.guardian_name LIKE '" . $like . "'
                OR st.mobileno LIKE '" . $like . "'
                OR st.email LIKE '" . $like . "'
                OR sh.house_name LIKE '" . $like . "'
              )
            ORDER BY st.id ASC
            LIMIT 500";

        $result = $mysqli->query($sql);
        if (!$result) {
            throw new Exception('Query failed: ' . $mysqli->error);
        }
        while ($row = $result->fetch_assoc()) {
            $students[] = si_map_disabled_row($row);
        }
    } else {
        throw new Exception('Invalid mode. Use filter or full.');
    }

    $mysqli->close();
    si_send_json(['success' => true, 'students' => $students, 'session_id' => $session_id]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    si_send_json(['success' => false, 'error' => $e->getMessage(), 'students' => []]);
}

function si_map_disabled_row($row) {
    return [
        'student_session_id' => (int) $row['student_session_id'],
        'student_id' => (int) $row['student_id'],
        'admission_no' => $row['admission_no'] ?? '',
        'roll_no' => $row['roll_no'] ?? '',
        'firstname' => $row['firstname'] ?? '',
        'middlename' => $row['middlename'] ?? '',
        'lastname' => $row['lastname'] ?? '',
        'image' => $row['image'] ?? '',
        'mobileno' => $row['mobileno'] ?? '',
        'email' => $row['email'] ?? '',
        'gender' => $row['gender'] ?? '',
        'is_active' => $row['is_active'] ?? '',
        'dis_reason' => $row['dis_reason'] ?? '',
        'dis_note' => $row['dis_note'] ?? '',
        'class_id' => (int) $row['class_id'],
        'class_name' => $row['class_name'] ?? '',
        'section_id' => (int) $row['section_id'],
        'section_name' => $row['section_name'] ?? '',
        'category' => $row['category'] ?? '',
    ];
}
