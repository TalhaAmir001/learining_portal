<?php
/**
 * Download Center / Share Content — uploaded files list (web: Content Share List).
 * GET: optional limit (default 300, max 500).
 *       optional upload_by (staff id): when > 0 and valid in staff, only rows uploaded by that staff.
 */

header('Content-Type: application/json; charset=utf-8');

/**
 * Staff id for filtering "my uploads" — only returns [requested] if it exists in staff (no fallback).
 */
function dc_upload_staff_id_for_filter(mysqli $mysqli, int $requested): int {
    if ($requested <= 0) {
        return 0;
    }
    $st = $mysqli->prepare('SELECT id FROM staff WHERE id = ? LIMIT 1');
    if (!$st) {
        return 0;
    }
    $st->bind_param('i', $requested);
    $st->execute();
    $st->store_result();
    $ok = $st->num_rows > 0;
    $st->close();
    return $ok ? $requested : 0;
}

function dc_send_json($data) {
    $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    if ($json === false) {
        echo json_encode(['success' => false, 'error' => 'Failed to encode', 'items' => []]);
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

    $limit = isset($_REQUEST['limit']) ? (int) $_REQUEST['limit'] : 300;
    if ($limit <= 0) {
        $limit = 300;
    }
    if ($limit > 500) {
        $limit = 500;
    }

    $uploadByReq = isset($_REQUEST['upload_by']) ? (int) $_REQUEST['upload_by'] : 0;
    $filterStaff = dc_upload_staff_id_for_filter($mysqli, $uploadByReq);
    $whereMine = '';
    if ($uploadByReq > 0) {
        if ($filterStaff > 0) {
            $whereMine = ' WHERE uc.upload_by = ' . $filterStaff . ' ';
        } else {
            $mysqli->close();
            dc_send_json(['success' => true, 'items' => [], 'filter_note' => 'invalid_upload_by_not_a_staff_id']);
            exit;
        }
    }

    $sql = "SELECT uc.id, uc.content_type_id, uc.image, uc.thumb_path, uc.dir_path, uc.real_name,
            uc.img_name, uc.thumb_name, uc.file_type, uc.mime_type, uc.file_size,
            uc.vid_url, uc.vid_title, uc.upload_by, uc.created_at, uc.updated_at,
            IFNULL(ct.name, '') AS content_type_name,
            TRIM(CONCAT(IFNULL(s.name, ''), ' ', IFNULL(s.surname, ''))) AS uploaded_by_name
        FROM upload_contents uc
        LEFT JOIN content_types ct ON ct.id = uc.content_type_id
        LEFT JOIN staff s ON s.id = uc.upload_by
        $whereMine
        ORDER BY uc.id DESC
        LIMIT " . $limit;

    $result = $mysqli->query($sql);
    if (!$result) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }
    $items = [];
    while ($row = $result->fetch_assoc()) {
        $items[] = [
            'id' => (int) $row['id'],
            'content_type_id' => (int) $row['content_type_id'],
            'content_type_name' => $row['content_type_name'] ?? '',
            'real_name' => $row['real_name'] ?? '',
            'file_type' => $row['file_type'] ?? '',
            'mime_type' => $row['mime_type'] ?? '',
            'file_size' => $row['file_size'] ?? '',
            'vid_url' => $row['vid_url'] ?? '',
            'vid_title' => $row['vid_title'] ?? '',
            'dir_path' => $row['dir_path'] ?? '',
            'img_name' => $row['img_name'] ?? '',
            'thumb_path' => $row['thumb_path'] ?? '',
            'upload_by' => (int) $row['upload_by'],
            'uploaded_by_name' => trim($row['uploaded_by_name'] ?? ''),
            'created_at' => $row['created_at'] ?? '',
            'updated_at' => $row['updated_at'] ?? '',
        ];
    }
    $mysqli->close();
    dc_send_json(['success' => true, 'items' => $items]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    dc_send_json(['success' => false, 'error' => $e->getMessage(), 'items' => []]);
}
