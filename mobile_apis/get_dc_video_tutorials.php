<?php
/**
 * Download Center / Share Content — video tutorials (web: Video Tutorial).
 */

header('Content-Type: application/json; charset=utf-8');

function dc_send_json($data) {
    $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    if ($json === false) {
        echo json_encode(['success' => false, 'error' => 'Failed to encode', 'tutorials' => []]);
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

    $limit = isset($_REQUEST['limit']) ? (int) $_REQUEST['limit'] : 150;
    if ($limit <= 0) {
        $limit = 150;
    }
    if ($limit > 300) {
        $limit = 300;
    }

    $sql = "SELECT vt.id, vt.title, vt.vid_title, vt.description, vt.thumb_path, vt.dir_path,
            vt.img_name, vt.thumb_name, vt.video_link, vt.created_by, vt.created_at, vt.updated_at,
            TRIM(CONCAT(IFNULL(s.name, ''), ' ', IFNULL(s.surname, ''))) AS created_by_name
        FROM video_tutorial vt
        LEFT JOIN staff s ON s.id = vt.created_by
        ORDER BY vt.id DESC
        LIMIT " . $limit;

    $result = $mysqli->query($sql);
    if (!$result) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }
    $rows = [];
    while ($row = $result->fetch_assoc()) {
        $rows[] = [
            'id' => (int) $row['id'],
            'title' => $row['title'] ?? '',
            'vid_title' => $row['vid_title'] ?? '',
            'description' => $row['description'] ?? '',
            'thumb_path' => $row['thumb_path'] ?? '',
            'dir_path' => $row['dir_path'] ?? '',
            'img_name' => $row['img_name'] ?? '',
            'thumb_name' => $row['thumb_name'] ?? '',
            'video_link' => $row['video_link'] ?? '',
            'created_by' => (int) $row['created_by'],
            'created_by_name' => trim($row['created_by_name'] ?? ''),
            'created_at' => $row['created_at'] ?? '',
            'updated_at' => $row['updated_at'] ?? '',
        ];
    }
    $mysqli->close();
    dc_send_json(['success' => true, 'tutorials' => $rows]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    dc_send_json(['success' => false, 'error' => $e->getMessage(), 'tutorials' => []]);
}
