<?php
/**
 * Student Information — single student profile (web student/view subset).
 * GET: student_id (required). Excludes password. Uses current session enrollment.
 */

header('Content-Type: application/json; charset=utf-8');

function si_send_json($data) {
    $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    if ($json === false) {
        echo json_encode(['success' => false, 'error' => 'Failed to encode', 'student' => null]);
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

    $student_id = isset($_REQUEST['student_id']) ? (int) $_REQUEST['student_id'] : 0;
    if ($student_id <= 0) {
        throw new Exception('Missing or invalid student_id.');
    }

    $sr = $mysqli->query("SELECT session_id FROM sch_settings ORDER BY id ASC LIMIT 1");
    if (!$sr || $sr->num_rows === 0) {
        throw new Exception('Could not resolve current session.');
    }
    $session_id = (int) $sr->fetch_assoc()['session_id'];

    $sql = "SELECT
        st.id AS student_id,
        ss.id AS student_session_id,
        st.admission_no,
        st.roll_no,
        st.admission_date,
        st.firstname,
        st.middlename,
        st.lastname,
        st.image,
        st.mobileno,
        st.email,
        st.state,
        st.city,
        st.pincode,
        st.religion,
        st.cast,
        st.dob,
        st.current_address,
        st.permanent_address,
        st.previous_school,
        st.category_id,
        IFNULL(cat.category, '') AS category,
        st.blood_group,
        st.gender,
        st.is_active,
        st.father_name,
        st.father_phone,
        st.father_occupation,
        st.mother_name,
        st.mother_phone,
        st.mother_occupation,
        st.guardian_is,
        st.guardian_name,
        st.guardian_relation,
        st.guardian_phone,
        st.guardian_email,
        st.guardian_address,
        st.guardian_occupation,
        st.rte,
        st.dis_reason,
        st.dis_note,
        st.disable_at,
        st.about,
        c.id AS class_id,
        c.class AS class_name,
        sec.id AS section_id,
        sec.section AS section_name,
        IFNULL(sh.house_name, '') AS house_name,
        u.username AS login_username
        FROM students st
        INNER JOIN student_session ss ON ss.student_id = st.id AND ss.session_id = " . $session_id . "
        INNER JOIN classes c ON c.id = ss.class_id
        INNER JOIN sections sec ON sec.id = ss.section_id
        LEFT JOIN categories cat ON cat.id = st.category_id
        LEFT JOIN school_houses sh ON sh.id = st.school_house_id
        LEFT JOIN users u ON u.user_id = st.id AND u.role = 'student'
        WHERE st.id = " . $student_id . "
        ORDER BY ss.id DESC
        LIMIT 1";

    $result = $mysqli->query($sql);
    if (!$result) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }
    if ($result->num_rows === 0) {
        $mysqli->close();
        si_send_json(['success' => false, 'error' => 'Student not found for current session.', 'student' => null]);
        exit;
    }
    $row = $result->fetch_assoc();

    $out = [
        'student_id' => (int) $row['student_id'],
        'student_session_id' => (int) $row['student_session_id'],
        'admission_no' => $row['admission_no'] ?? '',
        'roll_no' => $row['roll_no'] ?? '',
        'admission_date' => $row['admission_date'] ?? '',
        'firstname' => $row['firstname'] ?? '',
        'middlename' => $row['middlename'] ?? '',
        'lastname' => $row['lastname'] ?? '',
        'image' => $row['image'] ?? '',
        'mobileno' => $row['mobileno'] ?? '',
        'email' => $row['email'] ?? '',
        'state' => $row['state'] ?? '',
        'city' => $row['city'] ?? '',
        'pincode' => $row['pincode'] ?? '',
        'religion' => $row['religion'] ?? '',
        'cast' => $row['cast'] ?? '',
        'dob' => $row['dob'] ?? '',
        'current_address' => $row['current_address'] ?? '',
        'permanent_address' => $row['permanent_address'] ?? '',
        'previous_school' => $row['previous_school'] ?? '',
        'category_id' => isset($row['category_id']) ? (int) $row['category_id'] : 0,
        'category' => $row['category'] ?? '',
        'blood_group' => $row['blood_group'] ?? '',
        'gender' => $row['gender'] ?? '',
        'is_active' => $row['is_active'] ?? '',
        'father_name' => $row['father_name'] ?? '',
        'father_phone' => $row['father_phone'] ?? '',
        'father_occupation' => $row['father_occupation'] ?? '',
        'mother_name' => $row['mother_name'] ?? '',
        'mother_phone' => $row['mother_phone'] ?? '',
        'mother_occupation' => $row['mother_occupation'] ?? '',
        'guardian_is' => $row['guardian_is'] ?? '',
        'guardian_name' => $row['guardian_name'] ?? '',
        'guardian_relation' => $row['guardian_relation'] ?? '',
        'guardian_phone' => $row['guardian_phone'] ?? '',
        'guardian_email' => $row['guardian_email'] ?? '',
        'guardian_address' => $row['guardian_address'] ?? '',
        'guardian_occupation' => $row['guardian_occupation'] ?? '',
        'rte' => $row['rte'] ?? '',
        'dis_reason' => $row['dis_reason'] ?? '',
        'dis_note' => $row['dis_note'] ?? '',
        'disable_at' => $row['disable_at'] ?? '',
        'about' => $row['about'] ?? '',
        'class_id' => (int) $row['class_id'],
        'class_name' => $row['class_name'] ?? '',
        'section_id' => (int) $row['section_id'],
        'section_name' => $row['section_name'] ?? '',
        'house_name' => $row['house_name'] ?? '',
        'login_username' => $row['login_username'] ?? '',
    ];

    $mysqli->close();
    si_send_json(['success' => true, 'student' => $out, 'session_id' => $session_id]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    si_send_json(['success' => false, 'error' => $e->getMessage(), 'student' => null]);
}
