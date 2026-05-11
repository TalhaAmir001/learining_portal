<?php
/**
 * Parent Self-Link Children — claim a child by one-time `mobile_app_code`.
 *
 * Flow:
 *   1. Resolve the calling guardian's `app_parents` row (auto-create on
 *      first call, keyed by `users.email` with a synthetic fallback).
 *   2. Look up the student by `students.mobile_app_code`.
 *   3. Insert a row in `app_parent_students(parent_id, student_id)` and
 *      mark the code as consumed.
 *
 * POST (JSON or form):
 *   caller_user_type : 'guardian' (or 'parent')
 *   caller_user_id   : users.id of the guardian
 *   mobile_app_code  : 6-char code printed/sent by the school admin
 *   api_secret?      : optional, required when PL_API_SECRET is configured
 *
 * Outcomes (mirrors LinkChildOutcome on the Flutter side):
 *   linked         — code valid + unused → row created in app_parent_students.
 *   already_linked — caller already has a row for this student.
 *   rejected       — code already consumed by a different parent.
 *   unmatched      — no student row carries that code.
 *
 * Response shape:
 *   { success: bool, status: <one of above>, error?: string, child?: {...} }
 *
 * Note: with code-based linking there is no "pending_approval" branch.
 * Codes are admin-issued, so any valid+unused code links instantly.
 */

require_once __DIR__ . '/pl_bootstrap.php';

$mysqli = pl_mysqli_connect();

try {
    $body = pl_read_json_body();
    pl_require_api_secret($body);

    $parent    = pl_resolve_app_parent($mysqli, $body);
    $parent_id = (int) $parent['id'];

    // Hard-stop if the schema isn't migrated. Better than a cryptic SQL error.
    if (!pl_table_has_column($mysqli, 'students', 'mobile_app_code')) {
        pl_json_out([
            'success' => false,
            'status'  => 'rejected',
            'error'   => 'mobile_app_code column missing on students. Run parent_link_tables.sql.',
        ]);
    }

    $raw_code = isset($body['mobile_app_code']) ? $body['mobile_app_code'] : '';
    $code     = pl_normalise_code($raw_code);
    if ($code === '') {
        pl_json_out([
            'success' => false,
            'status'  => 'rejected',
            'error'   => 'Please enter the 6-character code your school sent you.',
        ]);
    }

    $session_id = pl_current_session_id($mysqli);

    $student = pl_find_student_by_code($mysqli, $code, $session_id);

    // 1) Code doesn't exist at all → unmatched.
    if ($student === null) {
        pl_json_out([
            'success' => true,
            'status'  => 'unmatched',
            'error'   => 'This code is not recognised. Please double-check or contact your school admin.',
        ]);
    }

    $student_id = (int) $student['student_id'];
    $used       = (int) ($student['mobile_app_code_used'] ?? 0) === 1;
    $used_by    = (int) ($student['mobile_app_code_used_by_parent_id'] ?? 0);

    // 2) Already linked to this caller (idempotent re-submit)?
    $r = $mysqli->query(
        "SELECT id FROM app_parent_students
         WHERE parent_id = $parent_id AND student_id = $student_id
         LIMIT 1"
    );
    if ($r && $r->num_rows > 0) {
        $r->free();
        $child_row = pl_get_child_for_active_session($mysqli, $student_id, $session_id);
        $mysqli->close();
        pl_json_out([
            'success' => true,
            'status'  => 'already_linked',
            'child'   => $child_row !== null ? pl_map_child_row($child_row) : pl_map_child_row($student),
        ]);
    }
    if ($r) {
        $r->free();
    }

    // 3) Code already used by another parent → reject.
    if ($used && $used_by > 0 && $used_by !== $parent_id) {
        pl_json_out([
            'success' => false,
            'status'  => 'rejected',
            'error'   => 'This code has already been used. Please ask your school admin for a new one.',
        ]);
    }

    // 4) Strong path: link the student now.
    $mysqli->begin_transaction();
    try {
        $ins = $mysqli->query(
            "INSERT INTO app_parent_students (parent_id, student_id, created_at)
             VALUES ($parent_id, $student_id, NOW())"
        );
        if (!$ins) {
            // Race with a parallel "already_linked" insert is fine; treat as linked.
            if ($mysqli->errno !== 1062) { // 1062 = duplicate key
                throw new Exception('Insert failed: ' . $mysqli->error);
            }
        }

        $upd = $mysqli->query(
            "UPDATE students
                SET mobile_app_code_used = 1,
                    mobile_app_code_used_at = NOW(),
                    mobile_app_code_used_by_parent_id = $parent_id
              WHERE id = $student_id
              LIMIT 1"
        );
        if (!$upd) {
            throw new Exception('Update failed: ' . $mysqli->error);
        }

        $mysqli->commit();
    } catch (Exception $tx) {
        $mysqli->rollback();
        throw $tx;
    }

    $child_row = pl_get_child_for_active_session($mysqli, $student_id, $session_id);
    $mysqli->close();
    pl_json_out([
        'success' => true,
        'status'  => 'linked',
        'child'   => $child_row !== null ? pl_map_child_row($child_row) : pl_map_child_row($student),
    ]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    pl_json_out([
        'success' => false,
        'status'  => 'rejected',
        'error'   => $e->getMessage(),
    ]);
}
