<?php
/**
 * Student Information — multi class students in a class/section (web: Multi Class Student).
 * GET: class_id, section_id (required). Returns active students enrolled there who have
 *      more than one student_session row in the current school session.
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

    $class_id = isset($_REQUEST['class_id']) ? (int) $_REQUEST['class_id'] : 0;
    $section_id = isset($_REQUEST['section_id']) ? (int) $_REQUEST['section_id'] : 0;
    if ($class_id <= 0 || $section_id <= 0) {
        throw new Exception('class_id and section_id are required.');
    }

    $sr = $mysqli->query("SELECT session_id FROM sch_settings ORDER BY id ASC LIMIT 1");
    if (!$sr || $sr->num_rows === 0) {
        throw new Exception('Could not resolve current session.');
    }
    $session_id = (int) $sr->fetch_assoc()['session_id'];

    $sql = "SELECT
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
        c.id AS class_id,
        c.class AS class_name,
        sec.id AS section_id,
        sec.section AS section_name,
        ss.id AS student_session_id
        FROM students st
        INNER JOIN student_session ss ON ss.student_id = st.id
            AND ss.session_id = " . $session_id . "
            AND ss.class_id = " . $class_id . "
            AND ss.section_id = " . $section_id . "
        INNER JOIN classes c ON c.id = ss.class_id
        INNER JOIN sections sec ON sec.id = ss.section_id
        WHERE st.is_active = 'yes'
          AND (
            SELECT COUNT(*) FROM student_session x
            WHERE x.student_id = st.id AND x.session_id = " . $session_id . "
          ) > 1
        ORDER BY st.admission_no ASC";

    $result = $mysqli->query($sql);
    if (!$result) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }

    $students = [];
    $seen = [];
    while ($row = $result->fetch_assoc()) {
        $sid = (int) $row['student_id'];
        if (isset($seen[$sid])) {
            continue;
        }
        $seen[$sid] = true;
        $sessions = [];
        $q2 = $mysqli->query(
            "SELECT ss.id AS student_session_id, ss.class_id, ss.section_id,
                cl.class AS class_name, se.section AS section_name
             FROM student_session ss
             INNER JOIN classes cl ON cl.id = ss.class_id
             INNER JOIN sections se ON se.id = ss.section_id
             WHERE ss.student_id = " . $sid . " AND ss.session_id = " . $session_id . "
             ORDER BY ss.id ASC"
        );
        if ($q2) {
            while ($s = $q2->fetch_assoc()) {
                $sessions[] = [
                    'student_session_id' => (int) $s['student_session_id'],
                    'class_id' => (int) $s['class_id'],
                    'class_name' => $s['class_name'] ?? '',
                    'section_id' => (int) $s['section_id'],
                    'section_name' => $s['section_name'] ?? '',
                ];
            }
        }
        $students[] = [
            'student_id' => $sid,
            'admission_no' => $row['admission_no'] ?? '',
            'roll_no' => $row['roll_no'] ?? '',
            'firstname' => $row['firstname'] ?? '',
            'middlename' => $row['middlename'] ?? '',
            'lastname' => $row['lastname'] ?? '',
            'image' => $row['image'] ?? '',
            'mobileno' => $row['mobileno'] ?? '',
            'email' => $row['email'] ?? '',
            'gender' => $row['gender'] ?? '',
            'class_id' => (int) $row['class_id'],
            'class_name' => $row['class_name'] ?? '',
            'section_id' => (int) $row['section_id'],
            'section_name' => $row['section_name'] ?? '',
            'student_session_id' => (int) $row['student_session_id'],
            'sessions' => $sessions,
        ];
    }

    $mysqli->close();
    si_send_json(['success' => true, 'students' => $students, 'session_id' => $session_id]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    si_send_json(['success' => false, 'error' => $e->getMessage(), 'students' => []]);
}
