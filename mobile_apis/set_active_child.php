<?php
/**
 * Parent Self-Link Children — set the guardian's currently active child.
 *
 * Stored on `app_parents.active_child_id` (added by parent_link_tables.sql).
 * The mobile app uses this so the rest of the app (chat, ZLC, daily feedback,
 * etc.) can scope to the chosen child when a guardian has more than one.
 *
 * POST (JSON or form):
 *   caller_user_type : 'guardian' (or 'parent')
 *   caller_user_id   : users.id of the guardian
 *   student_id       : students.id to mark as active. Must already be linked
 *                      to this guardian via `app_parent_students`.
 *   api_secret?      : optional, required when PL_API_SECRET is configured
 *
 * Response shape:
 *   { success: bool, error?: string, active_child_id: int|null }
 */

require_once __DIR__ . '/pl_bootstrap.php';

$mysqli = pl_mysqli_connect();

try {
    $body = pl_read_json_body();
    pl_require_api_secret($body);

    $parent    = pl_resolve_app_parent($mysqli, $body);
    $parent_id = (int) $parent['id'];

    $student_id = isset($body['student_id']) ? (int) $body['student_id'] : 0;
    if ($student_id < 1) {
        pl_json_out([
            'success'         => false,
            'error'           => 'Missing or invalid student_id.',
            'active_child_id' => null,
        ]);
    }

    // Must be linked to this guardian.
    $r = $mysqli->query(
        "SELECT id FROM app_parent_students
         WHERE parent_id = $parent_id AND student_id = $student_id
         LIMIT 1"
    );
    if (!$r || $r->num_rows === 0) {
        pl_json_out([
            'success'         => false,
            'error'           => 'Selected student is not linked to this guardian.',
            'active_child_id' => null,
        ]);
    }
    $r->free();

    if (!pl_table_has_column($mysqli, 'app_parents', 'active_child_id')) {
        pl_json_out([
            'success'         => false,
            'error'           => 'active_child_id column missing on app_parents. Run parent_link_tables.sql.',
            'active_child_id' => null,
        ]);
    }

    $upd = $mysqli->query("UPDATE app_parents SET active_child_id = $student_id WHERE id = $parent_id LIMIT 1");
    if (!$upd) {
        throw new Exception('Failed to set active child: ' . $mysqli->error);
    }

    $mysqli->close();
    pl_json_out([
        'success'         => true,
        'active_child_id' => $student_id,
    ]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    pl_json_out([
        'success'         => false,
        'error'           => $e->getMessage(),
        'active_child_id' => null,
    ]);
}
