<?php
/**
 * Parent Self-Link Children — list a guardian's currently linked children.
 *
 * Linkage source: `app_parent_students` (parent_id → student_id), filtered
 * by `student_session` for the current academic session so each row carries
 * the right class + section.
 *
 * POST/GET (JSON or form):
 *   caller_user_type : 'guardian' (or 'parent')
 *   caller_user_id   : users.id of the guardian
 *   api_secret?      : optional, required when PL_API_SECRET is configured
 *
 * Response shape (matches Flutter ParentChildrenPayload):
 *   {
 *     success: bool,
 *     children: [ParentChild...],
 *     active_child_id: int | null,
 *     error?: string
 *   }
 */

require_once __DIR__ . '/pl_bootstrap.php';

$mysqli = pl_mysqli_connect();

try {
    $body = pl_read_json_body();
    pl_require_api_secret($body);

    $parent     = pl_resolve_app_parent($mysqli, $body);
    $parent_id  = (int) $parent['id'];
    $session_id = pl_current_session_id($mysqli);

    if ($session_id < 1) {
        pl_json_out([
            'success'         => false,
            'error'           => 'Could not resolve current session.',
            'children'        => [],
            'active_child_id' => null,
        ]);
    }

    $sql = "SELECT
                st.id           AS student_id,
                st.firstname,
                st.middlename,
                st.lastname,
                st.admission_no,
                st.dob,
                st.is_active,
                c.class         AS class_name,
                sec.section     AS section_name
            FROM app_parent_students aps
            INNER JOIN students  st  ON st.id = aps.student_id
            INNER JOIN student_session ss ON ss.student_id = st.id AND ss.session_id = $session_id
            INNER JOIN classes   c   ON c.id  = ss.class_id
            INNER JOIN sections  sec ON sec.id = ss.section_id
            WHERE aps.parent_id = $parent_id
            ORDER BY st.firstname ASC, st.lastname ASC";

    $res = $mysqli->query($sql);
    if (!$res) {
        throw new Exception('Children query failed: ' . $mysqli->error);
    }

    $children = [];
    while ($row = $res->fetch_assoc()) {
        $children[] = pl_map_child_row($row);
    }
    $res->free();

    // Active child: read from app_parents.active_child_id. Self-heal if the
    // stored id is no longer in the linked list (e.g. unlinked elsewhere).
    $active_child_id = null;
    if (pl_table_has_column($mysqli, 'app_parents', 'active_child_id')) {
        $raw = $parent['active_child_id'] ?? null;
        if ($raw !== null && $raw !== '') {
            $candidate = (int) $raw;
            if ($candidate > 0) {
                $still_linked = false;
                foreach ($children as $c) {
                    if ((int) $c['student_id'] === $candidate) {
                        $still_linked = true;
                        break;
                    }
                }
                if ($still_linked) {
                    $active_child_id = $candidate;
                } else {
                    // Stale: drop it.
                    $mysqli->query("UPDATE app_parents SET active_child_id = NULL WHERE id = $parent_id");
                }
            }
        }
    }

    $mysqli->close();
    pl_json_out([
        'success'         => true,
        'children'        => $children,
        'active_child_id' => $active_child_id,
    ]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    pl_json_out([
        'success'         => false,
        'error'           => $e->getMessage(),
        'children'        => [],
        'active_child_id' => null,
    ]);
}
