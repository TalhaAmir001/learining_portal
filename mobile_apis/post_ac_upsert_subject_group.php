<?php
/**
 * Upsert subject group (admin).
 *
 * JSON:
 * {
 *   id?: int,
 *   name: string,
 *   description?: string,
 *   subject_ids: int[],
 *   class_section_ids: int[]
 * }
 */
require_once __DIR__ . '/ac_admin_bootstrap.php';

$mysqli = null;
try {
    $mysqli = ac_mysqli_connect();
    $body = ac_read_json_body();
    ac_require_api_secret($body);
    ac_admin_require_fields($body, array('name', 'subject_ids', 'class_section_ids'));

    $session_id = ac_current_session_id($mysqli);
    if ($session_id <= 0) {
        throw new Exception('Could not resolve current session.');
    }

    $id = isset($body['id']) ? (int) $body['id'] : 0;
    $name = trim((string) $body['name']);
    $description = isset($body['description']) ? trim((string) $body['description']) : '';
    $subject_ids = is_array($body['subject_ids']) ? $body['subject_ids'] : array();
    $class_section_ids = is_array($body['class_section_ids']) ? $body['class_section_ids'] : array();

    if ($name === '') {
        throw new Exception('Name is required.');
    }

    $sub = array_values(array_unique(array_filter(array_map('intval', $subject_ids), function ($v) { return $v > 0; })));
    $cs = array_values(array_unique(array_filter(array_map('intval', $class_section_ids), function ($v) { return $v > 0; })));
    if (empty($sub)) {
        throw new Exception('At least one subject is required.');
    }
    if (empty($cs)) {
        throw new Exception('At least one class section is required.');
    }

    $name_esc = $mysqli->real_escape_string($name);
    $desc_esc = $mysqli->real_escape_string($description);

    // Name uniqueness within session.
    $q = "SELECT id FROM subject_groups WHERE session_id=" . (int) $session_id . " AND name='" . $name_esc . "'";
    if ($id > 0) $q .= " AND id <> " . (int) $id;
    $r = $mysqli->query($q);
    if ($r && $r->num_rows > 0) {
        throw new Exception('Already exists.');
    }

    // Section uniqueness: a class_section may belong to only one group per session.
    $in = implode(',', array_map('intval', $cs));
    $q = "SELECT subject_group_id, class_section_id FROM subject_group_class_sections
          WHERE session_id=" . (int) $session_id . "
            AND class_section_id IN (" . $in . ")";
    if ($id > 0) $q .= " AND subject_group_id <> " . (int) $id;
    $r = $mysqli->query($q);
    if ($r && $r->num_rows > 0) {
        throw new Exception('Subjects already assigned.');
    }

    $mysqli->begin_transaction();

    if ($id > 0) {
        $sql = "UPDATE subject_groups SET name='" . $name_esc . "', description='" . $desc_esc . "'
                WHERE id=" . (int) $id . " AND session_id=" . (int) $session_id . " LIMIT 1";
        if (!$mysqli->query($sql)) {
            throw new Exception('Update failed: ' . $mysqli->error);
        }

        // Replace subjects and sections (simpler, deterministic).
        if (!$mysqli->query("DELETE FROM subject_group_subjects WHERE subject_group_id=" . (int) $id . " AND session_id=" . (int) $session_id)) {
            throw new Exception('Delete subject links failed: ' . $mysqli->error);
        }
        if (!$mysqli->query("DELETE FROM subject_group_class_sections WHERE subject_group_id=" . (int) $id . " AND session_id=" . (int) $session_id)) {
            throw new Exception('Delete section links failed: ' . $mysqli->error);
        }
        $gid = $id;
    } else {
        $sql = "INSERT INTO subject_groups (name, session_id, description)
                VALUES ('" . $name_esc . "', " . (int) $session_id . ", '" . $desc_esc . "')";
        if (!$mysqli->query($sql)) {
            throw new Exception('Insert failed: ' . $mysqli->error);
        }
        $gid = (int) $mysqli->insert_id;
    }

    foreach ($sub as $sid) {
        $sql = "INSERT INTO subject_group_subjects (subject_group_id, subject_id, session_id)
                VALUES (" . (int) $gid . ", " . (int) $sid . ", " . (int) $session_id . ")";
        if (!$mysqli->query($sql)) {
            throw new Exception('Insert subject link failed: ' . $mysqli->error);
        }
    }
    foreach ($cs as $cid) {
        $sql = "INSERT INTO subject_group_class_sections (subject_group_id, class_section_id, session_id)
                VALUES (" . (int) $gid . ", " . (int) $cid . ", " . (int) $session_id . ")";
        if (!$mysqli->query($sql)) {
            throw new Exception('Insert section link failed: ' . $mysqli->error);
        }
    }

    $mysqli->commit();
    $mysqli->close();
    ac_admin_success(array('id' => $gid));
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->rollback();
        $mysqli->close();
    }
    ac_admin_fail($e->getMessage());
}

