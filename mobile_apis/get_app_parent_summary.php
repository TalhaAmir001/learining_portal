<?php
/**
 * Parent profile snapshot for *staff-side* lookups.
 *
 * Used by the chat screen so a teacher/admin chatting with a parent (e.g.
 * a claimed Support thread) can see which child the conversation is about.
 * The endpoint never reveals more than name + active child basics.
 *
 * POST/GET (JSON or form):
 *   parent_id  : int       (required)
 *               Either `app_parents.id` (preferred, from parent_login.php) or
 *               the legacy `users.id`. The server tries both — see resolution
 *               order below.
 *   api_secret : optional  (required when PL_API_SECRET is configured)
 *
 * Resolution order for parent_id:
 *   1. SELECT FROM app_parents WHERE id = parent_id  ← happy path
 *   2. SELECT FROM users WHERE id = parent_id        ← legacy `users` flow
 *      → bridge via LOWER(email) to app_parents.
 *
 * Response — success:
 *   {
 *     "success": true,
 *     "parent":  { "id": 7, "name": "...", "email": "..." },
 *     "active_child": ParentChild | null
 *   }
 *
 * Response — failure:
 *   { "success": false, "error": "..." }
 *
 * Notes:
 *   • Read-only. Never mutates any row.
 *   • Safe to call from any authenticated mobile client because the only
 *     additional surface area is "given an id, here is one child name +
 *     admission no.", which staff can already see in the portal anyway.
 */

require_once __DIR__ . '/pl_bootstrap.php';

$mysqli = pl_mysqli_connect();

try {
    $body = pl_read_json_body();
    pl_require_api_secret($body);

    $parent_id_raw = $body['parent_id']
        ?? $body['app_parent_id']
        ?? $_GET['parent_id']
        ?? $_GET['app_parent_id']
        ?? null;
    $parent_id = (int) $parent_id_raw;
    if ($parent_id < 1) {
        pl_json_out(['success' => false, 'error' => 'Missing or invalid parent_id.']);
    }

    // ── Resolve to an app_parents row ─────────────────────────────────────
    $parent = null;
    $r = $mysqli->query("SELECT * FROM app_parents WHERE id = $parent_id LIMIT 1");
    if ($r && $r->num_rows > 0) {
        $parent = $r->fetch_assoc();
    }
    if ($r) {
        $r->free();
    }

    // Legacy fallback: id might be a portal `users.id`; bridge by email.
    if ($parent === null) {
        $ur = $mysqli->query(
            "SELECT id, username, email, role FROM users WHERE id = $parent_id LIMIT 1"
        );
        if ($ur && $ur->num_rows > 0) {
            $user = $ur->fetch_assoc();
            $ur->free();
            $role = strtolower(trim((string) ($user['role'] ?? '')));
            if ($role === 'parent' || $role === 'guardian') {
                $email_lc = pl_email_for_user($user);
                $email_esc = $mysqli->real_escape_string($email_lc);
                $pr = $mysqli->query(
                    "SELECT * FROM app_parents WHERE LOWER(email) = '$email_esc' LIMIT 1"
                );
                if ($pr && $pr->num_rows > 0) {
                    $parent = $pr->fetch_assoc();
                }
                if ($pr) {
                    $pr->free();
                }
            }
        } else if ($ur) {
            $ur->free();
        }
    }

    if ($parent === null) {
        // Quiet failure: returning success=true with no active child means
        // the chat bar just stays hidden, instead of flashing an error toast
        // for chats that happen to involve a non-parent counterparty.
        $mysqli->close();
        pl_json_out([
            'success'      => true,
            'parent'       => null,
            'active_child' => null,
        ]);
    }

    // ── Active child (current academic session) ───────────────────────────
    $active_child = null;
    $active_id = 0;
    if (pl_table_has_column($mysqli, 'app_parents', 'active_child_id')) {
        $raw = $parent['active_child_id'] ?? null;
        if ($raw !== null && $raw !== '') {
            $active_id = (int) $raw;
        }
    }

    if ($active_id > 0) {
        $session_id = pl_current_session_id($mysqli);
        if ($session_id > 0) {
            // Make sure the active child is still linked to this parent.
            $pid_for_check = (int) $parent['id'];
            $link_q = $mysqli->query(
                "SELECT 1 FROM app_parent_students
                 WHERE parent_id = $pid_for_check AND student_id = $active_id
                 LIMIT 1"
            );
            $is_linked = ($link_q && $link_q->num_rows > 0);
            if ($link_q) {
                $link_q->free();
            }

            if ($is_linked) {
                $row = pl_get_child_for_active_session($mysqli, $active_id, $session_id);
                if ($row !== null) {
                    $active_child = pl_map_child_row($row);
                }
            }
        }
    }

    $mysqli->close();
    pl_json_out([
        'success' => true,
        'parent'  => [
            'id'    => (int) $parent['id'],
            'name'  => (string) ($parent['name'] ?? ''),
            'email' => (string) ($parent['email'] ?? ''),
        ],
        'active_child' => $active_child,
    ]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    pl_json_out([
        'success'      => false,
        'error'        => $e->getMessage(),
        'parent'       => null,
        'active_child' => null,
    ]);
}
