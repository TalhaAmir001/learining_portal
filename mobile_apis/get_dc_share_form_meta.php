<?php
/**
 * Download center — metadata for building a "share" like web admin:
 * roles (for group targeting) + whether guardian/parent group option applies.
 */

header('Content-Type: application/json; charset=utf-8');

function dc_meta_send_json($data) {
    $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    if ($json === false) {
        echo json_encode(['success' => false, 'error' => 'Failed to encode', 'roles' => []]);
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

    $guardian_option = false;
    $sr = $mysqli->query('SELECT guardian_name FROM sch_settings ORDER BY id ASC LIMIT 1');
    if ($sr && $row = $sr->fetch_assoc()) {
        $g = $row['guardian_name'] ?? 0;
        $guardian_option = ((int) $g === 1);
    }

    $roles = [];
    $rr = $mysqli->query("SELECT id, name FROM roles ORDER BY name ASC");
    if ($rr) {
        while ($row = $rr->fetch_assoc()) {
            $name = trim((string) ($row['name'] ?? ''));
            if (strcasecmp($name, 'Super Admin') === 0) {
                continue;
            }
            $roles[] = [
                'id' => (int) $row['id'],
                'name' => $name,
            ];
        }
    }

    $mysqli->close();
    dc_meta_send_json([
        'success' => true,
        'guardian_option' => $guardian_option,
        'roles' => $roles,
    ]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    dc_meta_send_json(['success' => false, 'error' => $e->getMessage(), 'roles' => []]);
}
