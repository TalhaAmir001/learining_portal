<?php
/**
 * Upsert subject (admin).
 * JSON: { id?: int, name: string, code?: string, type: string }
 */
require_once __DIR__ . '/ac_admin_bootstrap.php';

$mysqli = null;
try {
    $mysqli = ac_mysqli_connect();
    $body = ac_read_json_body();
    ac_require_api_secret($body);
    ac_admin_require_fields($body, array('name', 'type'));

    $id = isset($body['id']) ? (int) $body['id'] : 0;
    $name = trim((string) $body['name']);
    $code = isset($body['code']) ? trim((string) $body['code']) : '';
    $type = trim((string) $body['type']);
    if ($name === '' || $type === '') {
        throw new Exception('Subject name and type are required.');
    }

    // Mirror web validation: name unique; code unique if provided.
    $name_esc = $mysqli->real_escape_string($name);
    $code_esc = $mysqli->real_escape_string($code);
    $type_esc = $mysqli->real_escape_string($type);

    $q = "SELECT id FROM subjects WHERE name='" . $name_esc . "'";
    if ($id > 0) $q .= " AND id <> " . (int) $id;
    $r = $mysqli->query($q);
    if ($r && $r->num_rows > 0) {
        throw new Exception('Name already exists.');
    }
    if ($code !== '') {
        $q = "SELECT id FROM subjects WHERE code='" . $code_esc . "'";
        if ($id > 0) $q .= " AND id <> " . (int) $id;
        $r = $mysqli->query($q);
        if ($r && $r->num_rows > 0) {
            throw new Exception('Code already exists.');
        }
    }

    if ($id > 0) {
        $sql = "UPDATE subjects SET name='" . $name_esc . "', code='" . $code_esc . "', type='" . $type_esc . "'
                WHERE id=" . (int) $id . " LIMIT 1";
        if (!$mysqli->query($sql)) {
            throw new Exception('Update failed: ' . $mysqli->error);
        }
        $mysqli->close();
        ac_admin_success(array('id' => $id));
    } else {
        $sql = "INSERT INTO subjects (name, code, type) VALUES ('" . $name_esc . "', '" . $code_esc . "', '" . $type_esc . "')";
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

