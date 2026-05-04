<?php
/**
 * Share Content — shared content batches (share_contents + staff).
 * GET: optional created_by (staff id) — only shares created by that staff (matches web “my shares”).
 *       optional list_all=1 — skip created_by filter (e.g. admin sees all).
 */

header('Content-Type: application/json; charset=utf-8');

/**
 * Staff id for filtering "my shares" — only returns [requested] if it exists in staff (no fallback).
 */
function dc_share_staff_id_for_filter(mysqli $mysqli, int $requested): int {
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
        echo json_encode(['success' => false, 'error' => 'Failed to encode', 'shares' => []]);
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
    if ($limit > 400) {
        $limit = 400;
    }

    $listAll = isset($_REQUEST['list_all']) && (string) $_REQUEST['list_all'] === '1';
    $createdByReq = isset($_REQUEST['created_by']) ? (int) $_REQUEST['created_by'] : 0;
    $whereMine = '';
    if (!$listAll) {
        if ($createdByReq <= 0) {
            $mysqli->close();
            dc_send_json(['success' => true, 'shares' => [], 'filter_note' => 'created_by_required']);
            exit;
        }
        $sid = dc_share_staff_id_for_filter($mysqli, $createdByReq);
        if ($sid > 0) {
            $whereMine = ' WHERE sc.created_by = ' . $sid . ' ';
        } else {
            $mysqli->close();
            dc_send_json(['success' => true, 'shares' => [], 'filter_note' => 'invalid_created_by_not_a_staff_id']);
            exit;
        }
    }

    $sql = "SELECT sc.id, sc.send_to, sc.title, sc.share_date, sc.valid_upto, sc.description,
            sc.created_by, sc.created_at, sc.updated_at,
            TRIM(CONCAT(IFNULL(s.name, ''), ' ', IFNULL(s.surname, ''))) AS created_by_name,
            IFNULL(s.employee_id, '') AS employee_id
        FROM share_contents sc
        LEFT JOIN staff s ON s.id = sc.created_by
        $whereMine
        ORDER BY sc.id DESC
        LIMIT " . $limit;

    $result = $mysqli->query($sql);
    if (!$result) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }
    $rows = [];
    while ($row = $result->fetch_assoc()) {
        $rows[] = [
            'id' => (int) $row['id'],
            'send_to' => $row['send_to'] ?? '',
            'title' => $row['title'] ?? '',
            'share_date' => $row['share_date'] ?? '',
            'valid_upto' => $row['valid_upto'] ?? '',
            'description' => $row['description'] ?? '',
            'created_by' => (int) $row['created_by'],
            'created_by_name' => trim($row['created_by_name'] ?? ''),
            'employee_id' => $row['employee_id'] ?? '',
            'created_at' => $row['created_at'] ?? '',
            'updated_at' => $row['updated_at'] ?? '',
        ];
    }
    $mysqli->close();
    dc_send_json(['success' => true, 'shares' => $rows]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    dc_send_json(['success' => false, 'error' => $e->getMessage(), 'shares' => []]);
}
