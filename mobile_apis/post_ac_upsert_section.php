<?php
/**
 * Upsert section (admin).
 * JSON: { id?: int, name: string }
 */
require_once __DIR__ . '/ac_admin_bootstrap.php';

$mysqli = null;
try {
    $mysqli = ac_mysqli_connect();
    $body = ac_read_json_body();
    ac_require_api_secret($body);
    ac_admin_require_fields($body, array('name'));

    $id = isset($body['id']) ? (int) $body['id'] : 0;
    $name = trim((string) $body['name']);
    if ($name === '') {
        throw new Exception('Section name is required.');
    }

    $name_esc = $mysqli->real_escape_string($name);

    if ($id > 0) {
        $sql = "UPDATE sections SET section='" . $name_esc . "' WHERE id=" . (int) $id . " LIMIT 1";
        if (!$mysqli->query($sql)) {
            throw new Exception('Update failed: ' . $mysqli->error);
        }
        $mysqli->close();
        ac_admin_success(array('id' => $id));
    } else {
        $sql = "INSERT INTO sections (section) VALUES ('" . $name_esc . "')";
        if (!$mysqli->query($sql)) {
            throw new Exception('Insert failed: ' . $mysqli->error);
        }
        $new_id = (int) $mysqli->insert_id;
        $mysqli->close();
        ac_admin_success(array('id' => $new_id));
    }
} catch (Exception $e) {
    if ($mysqli) $mysqli->close();
    ac_admin_fail($e->getMessage());
}

