<?php
/**
 * Get Support Ticket Categories
 * GET: returns all active categories from support_ticket_categories, ordered by sort_order.
 */

header('Content-Type: application/json; charset=utf-8');

function sendJson($data) {
    $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    if ($json === false) {
        echo json_encode(['success' => false, 'error' => 'Failed to encode response', 'categories' => []]);
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

    $sql = "SELECT id, name, slug, sort_order, is_active, created_at, updated_at
            FROM support_ticket_categories
            WHERE is_active = 1
            ORDER BY sort_order ASC, id ASC";
    $result = $mysqli->query($sql);
    if (!$result) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }

    $categories = [];
    while ($row = $result->fetch_assoc()) {
        $categories[] = [
            'id' => (int) $row['id'],
            'name' => $row['name'],
            'slug' => $row['slug'],
            'sort_order' => (int) ($row['sort_order'] ?? 0),
            'is_active' => (int) ($row['is_active'] ?? 1) === 1,
        ];
    }

    $mysqli->close();
    sendJson(['success' => true, 'categories' => $categories]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    sendJson(['success' => false, 'error' => $e->getMessage(), 'categories' => []]);
}
