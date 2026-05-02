<?php
/**
 * Student Information — single online admission record.
 * GET: id (online_admissions.id, required).
 */

header('Content-Type: application/json; charset=utf-8');

function si_send_json($data) {
    $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    if ($json === false) {
        echo json_encode(['success' => false, 'error' => 'Failed to encode', 'application' => null]);
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

    $id = isset($_REQUEST['id']) ? (int) $_REQUEST['id'] : 0;
    if ($id <= 0) {
        throw new Exception('Missing or invalid id.');
    }

    $sql = "SELECT
        oa.*,
        IFNULL(c.id, 0) AS class_id,
        IFNULL(c.class, '') AS class_name,
        IFNULL(s.id, 0) AS section_id,
        IFNULL(s.section, '') AS section_name,
        IFNULL(cat.category, '') AS category
        FROM online_admissions oa
        LEFT JOIN class_sections cs ON cs.id = oa.class_section_id
        LEFT JOIN classes c ON c.id = cs.class_id
        LEFT JOIN sections s ON s.id = cs.section_id
        LEFT JOIN categories cat ON cat.id = oa.category_id
        WHERE oa.id = " . $id . "
        LIMIT 1";

    $result = $mysqli->query($sql);
    if (!$result) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }
    if ($result->num_rows === 0) {
        $mysqli->close();
        si_send_json(['success' => false, 'error' => 'Application not found.', 'application' => null]);
        exit;
    }
    $row = $result->fetch_assoc();
    // Never expose raw password fields if present
    unset($row['password'], $row['user_password']);

    $mysqli->close();
    si_send_json(['success' => true, 'application' => $row]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    si_send_json(['success' => false, 'error' => $e->getMessage(), 'application' => null]);
}
