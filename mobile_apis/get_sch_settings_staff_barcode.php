<?php
/**
 * App gate: staff_barcode from sch_settings (1 = mobile app allowed, 0 = blocked).
 * GET — no auth required; called before login.
 */

header('Content-Type: application/json; charset=utf-8');

function sendJson($data) {
    $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    if ($json === false) {
        echo json_encode(['success' => false, 'error' => 'Failed to encode response', 'staff_barcode' => null]);
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

    $sql = 'SELECT staff_barcode FROM sch_settings LIMIT 1';
    $result = $mysqli->query($sql);
    if (!$result) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }

    $row = $result->fetch_assoc();
    $mysqli->close();

    if ($row === null) {
        sendJson([
            'success' => true,
            'staff_barcode' => 0,
        ]);
        exit;
    }

    $raw = $row['staff_barcode'] ?? null;
    $value = ((int) $raw === 1) ? 1 : 0;

    sendJson([
        'success' => true,
        'staff_barcode' => $value,
    ]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    sendJson([
        'success' => false,
        'error' => $e->getMessage(),
        'staff_barcode' => null,
    ]);
}
