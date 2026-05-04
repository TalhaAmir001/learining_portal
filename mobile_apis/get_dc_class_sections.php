<?php
/**
 * Class + section pairs with class_sections.id (for share_content_for.class_section_id).
 */

header('Content-Type: application/json; charset=utf-8');

function dc_cs_send_json($data) {
    $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    if ($json === false) {
        echo json_encode(['success' => false, 'error' => 'Failed to encode', 'class_sections' => []]);
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

    $sql = "SELECT cs.id, cs.class_id, cs.section_id,
            CONCAT(c.class, ' — ', s.section) AS label
        FROM class_sections cs
        INNER JOIN classes c ON c.id = cs.class_id
        INNER JOIN sections s ON s.id = cs.section_id
        ORDER BY c.class ASC, s.section ASC";

    $result = $mysqli->query($sql);
    if (!$result) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }
    $rows = [];
    while ($row = $result->fetch_assoc()) {
        $rows[] = [
            'id' => (int) $row['id'],
            'class_id' => (int) $row['class_id'],
            'section_id' => (int) $row['section_id'],
            'label' => $row['label'] ?? '',
        ];
    }
    $mysqli->close();
    dc_cs_send_json(['success' => true, 'class_sections' => $rows]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    dc_cs_send_json(['success' => false, 'error' => $e->getMessage(), 'class_sections' => []]);
}
