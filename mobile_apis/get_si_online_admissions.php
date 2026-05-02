<?php
/**
 * Student Information — online admission applications (web: Online Admission).
 * GET: optional limit (default 200, max 500).
 */

header('Content-Type: application/json; charset=utf-8');

function si_send_json($data) {
    $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    if ($json === false) {
        echo json_encode(['success' => false, 'error' => 'Failed to encode', 'applications' => []]);
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

    $limit = isset($_REQUEST['limit']) ? (int) $_REQUEST['limit'] : 200;
    if ($limit <= 0) {
        $limit = 200;
    }
    if ($limit > 500) {
        $limit = 500;
    }

    $sql = "SELECT
        oa.id,
        oa.reference_no,
        oa.firstname,
        oa.middlename,
        oa.lastname,
        oa.admission_no,
        oa.roll_no,
        oa.dob,
        oa.gender,
        oa.mobileno,
        oa.email,
        oa.form_status,
        oa.is_enroll,
        oa.paid_status,
        oa.submit_date,
        oa.created_at,
        IFNULL(c.class, '') AS class_name,
        IFNULL(s.section, '') AS section_name
        FROM online_admissions oa
        LEFT JOIN class_sections cs ON cs.id = oa.class_section_id
        LEFT JOIN classes c ON c.id = cs.class_id
        LEFT JOIN sections s ON s.id = cs.section_id
        ORDER BY oa.id DESC
        LIMIT " . $limit;

    $result = $mysqli->query($sql);
    if (!$result) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }
    $rows = [];
    while ($row = $result->fetch_assoc()) {
        $rows[] = [
            'id' => (int) $row['id'],
            'reference_no' => $row['reference_no'] ?? '',
            'firstname' => $row['firstname'] ?? '',
            'middlename' => $row['middlename'] ?? '',
            'lastname' => $row['lastname'] ?? '',
            'admission_no' => $row['admission_no'] ?? '',
            'roll_no' => $row['roll_no'] ?? '',
            'dob' => $row['dob'] ?? '',
            'gender' => $row['gender'] ?? '',
            'mobileno' => $row['mobileno'] ?? '',
            'email' => $row['email'] ?? '',
            'form_status' => isset($row['form_status']) ? (int) $row['form_status'] : 0,
            'is_enroll' => $row['is_enroll'] ?? '',
            'paid_status' => $row['paid_status'] ?? '',
            'submit_date' => $row['submit_date'] ?? '',
            'created_at' => $row['created_at'] ?? '',
            'class_name' => $row['class_name'] ?? '',
            'section_name' => $row['section_name'] ?? '',
        ];
    }
    $mysqli->close();
    si_send_json(['success' => true, 'applications' => $rows]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    si_send_json(['success' => false, 'error' => $e->getMessage(), 'applications' => []]);
}
