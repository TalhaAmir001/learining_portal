<?php
require_once __DIR__ . '/zlc_bootstrap.php';

try {
    $body = zlc_read_json_body();
    zlc_require_api_secret($body);
    $conference_id = isset($body['conference_id']) ? (int) $body['conference_id'] : 0;
    $status = isset($body['status']) ? (int) $body['status'] : -1;
    if ($conference_id <= 0 || $status < 0 || $status > 2) {
        throw new Exception('conference_id and status (0–2) required');
    }
    $mysqli = zlc_mysqli_connect();
    if (!$mysqli->query('UPDATE conferences SET status = ' . (int) $status . ' WHERE id = ' . (int) $conference_id)) {
        throw new Exception('Update failed: ' . $mysqli->error);
    }
    zlc_json_out(array('success' => true));
} catch (Exception $e) {
    zlc_json_out(array('success' => false, 'error' => $e->getMessage()));
}
