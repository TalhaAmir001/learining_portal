<?php
/**
 * Leaving Notice submission (4-week notice policy).
 *
 * Invoked from the *logged-in* parent's profile menu in the mobile app, so
 * the request authenticates with the standard parent_link identity scheme
 * (`caller_user_type='app_parent'` + `caller_user_id=app_parents.id`).
 * Server-side guard: the requested leaving date must be at least
 * `LEAVING_NOTICE_MIN_DAYS` (= 28) days from today. The mobile UI hides
 * earlier dates from the date picker, but we enforce the rule here too so
 * the policy can't be bypassed by a hand-crafted request.
 *
 * POST (JSON or form):
 *   caller_user_type   : 'app_parent'   (legacy 'guardian' / 'parent' bridges
 *                                         still work via pl_resolve_app_parent)
 *   caller_user_id     : app_parents.id (or users.id for the legacy bridge)
 *   reason             : string  — non-empty, trimmed; ≤ 4000 chars (DB is TEXT)
 *   leaving_date       : string  — "YYYY-MM-DD"
 *   active_student_id? : int     — students.id the parent currently has
 *                                   active in the mobile app. Validated to
 *                                   belong to this parent via
 *                                   `app_parent_students`. Unlinked / missing
 *                                   ids are silently dropped (the notice
 *                                   still saves, just without the snapshot).
 *   api_secret?        : when PL_API_SECRET is configured
 *
 * Response — success:
 *   {
 *     "success": true,
 *     "id": 12,
 *     "leaving_date": "2026-06-08",
 *     "min_leaving_date": "2026-06-08",
 *     "submitted_at": "2026-05-11 21:00:00",
 *     "active_student_id": 47,
 *     "active_student_label": "Aiden Khan (ADM-2024-031)"
 *   }
 *
 * Response — failure:
 *   { "success": false, "error": "..." }
 */

require_once __DIR__ . '/pl_bootstrap.php';

const LEAVING_NOTICE_MIN_DAYS = 28;
const LEAVING_NOTICE_MAX_REASON_LEN = 4000;

$mysqli = pl_mysqli_connect();

try {
    $body = pl_read_json_body();
    pl_require_api_secret($body);

    $reason       = isset($body['reason'])       ? trim((string) $body['reason'])       : '';
    $leaving_date = isset($body['leaving_date']) ? trim((string) $body['leaving_date']) : '';

    if ($reason === '') {
        pl_json_out([
            'success' => false,
            'error'   => 'Please enter a reason for leaving.',
        ]);
    }
    if (mb_strlen($reason) > LEAVING_NOTICE_MAX_REASON_LEN) {
        $reason = mb_substr($reason, 0, LEAVING_NOTICE_MAX_REASON_LEN);
    }

    // ── Validate leaving_date is a real Y-m-d and ≥ today + 28 days ──────
    $today    = new DateTimeImmutable('today');
    $earliest = $today->modify('+' . LEAVING_NOTICE_MIN_DAYS . ' days');

    $dt = DateTimeImmutable::createFromFormat('Y-m-d', $leaving_date);
    $valid_format = ($dt !== false && $dt->format('Y-m-d') === $leaving_date);
    if (!$valid_format) {
        pl_json_out([
            'success'          => false,
            'error'            => 'Invalid leaving date format. Expected YYYY-MM-DD.',
            'min_leaving_date' => $earliest->format('Y-m-d'),
        ]);
    }
    if ($dt < $earliest) {
        pl_json_out([
            'success'          => false,
            'error'            => 'Leaving date must be at least '
                . LEAVING_NOTICE_MIN_DAYS . ' days from today.',
            'min_leaving_date' => $earliest->format('Y-m-d'),
        ]);
    }

    // ── Authenticate (resolves caller_user_id → app_parents row). The
    // helper terminates the request itself on auth failure, so we don't
    // need extra defensive code around this call.
    $parent        = pl_resolve_app_parent($mysqli, $body);
    $app_parent_id = (int) $parent['id'];
    if ($app_parent_id < 1) {
        $mysqli->close();
        pl_json_out([
            'success' => false,
            'error'   => 'Parent profile is missing. Please contact your school admin.',
        ]);
    }

    // Best-effort lookup of the paired app_parent_users row. Null is fine
    // — column is nullable — but having it helps admins trace who logged
    // in to file the notice.
    $app_parent_user_id_sql = 'NULL';
    $apu = $mysqli->query(
        "SELECT id FROM app_parent_users
         WHERE app_parent_id = $app_parent_id
         LIMIT 1"
    );
    if ($apu && $apu->num_rows > 0) {
        $apu_row = $apu->fetch_assoc();
        $apu_id  = (int) ($apu_row['id'] ?? 0);
        if ($apu_id > 0) {
            $app_parent_user_id_sql = (string) $apu_id;
        }
    }
    if ($apu) {
        $apu->free();
    }

    // For audit / lookup we store whichever human-readable handle is on
    // the resolved row — name or email. Cheap and harmless if blank.
    $identifier_used = '';
    if (isset($parent['email']) && $parent['email'] !== '') {
        $identifier_used = (string) $parent['email'];
    } elseif (isset($parent['name']) && $parent['name'] !== '') {
        $identifier_used = (string) $parent['name'];
    }
    $identifier_used = mb_substr($identifier_used, 0, 191);

    // ── Active child snapshot ────────────────────────────────────────────
    // Optional, audit-only field. The mobile UI shows the parent which child
    // is currently selected in the End Subscription dialog; we record both
    // the id and a human-readable label so admins can read the snapshot
    // even if the students row is later renamed or removed.
    $active_student_id_sql   = 'NULL';
    $active_student_label    = '';
    $active_student_raw      = $body['active_student_id'] ?? null;
    $active_student_id_input = is_numeric($active_student_raw)
        ? (int) $active_student_raw
        : 0;

    if ($active_student_id_input > 0) {
        // Trust-but-verify: only accept the id if this student is actually
        // linked to the authenticated parent. Anything else is silently
        // dropped — the notice itself is the important record.
        $check_sql = "SELECT s.id, s.firstname, s.middlename, s.lastname,
                             s.admission_no
                      FROM app_parent_students aps
                      INNER JOIN students s ON s.id = aps.student_id
                      WHERE aps.parent_id = $app_parent_id
                        AND aps.student_id = $active_student_id_input
                      LIMIT 1";
        $check_res = $mysqli->query($check_sql);
        if ($check_res && $check_res->num_rows > 0) {
            $row              = $check_res->fetch_assoc();
            $active_student_id_sql = (string) ((int) $row['id']);

            $name_parts = [];
            foreach (['firstname', 'middlename', 'lastname'] as $f) {
                $v = isset($row[$f]) ? trim((string) $row[$f]) : '';
                if ($v !== '') {
                    $name_parts[] = $v;
                }
            }
            $name = $name_parts ? implode(' ', $name_parts) : 'Student #' . (int) $row['id'];
            $adm  = isset($row['admission_no']) ? trim((string) $row['admission_no']) : '';
            $active_student_label = $adm !== ''
                ? sprintf('%s (%s)', $name, $adm)
                : $name;
            $active_student_label = mb_substr($active_student_label, 0, 191);
        }
        if ($check_res) {
            $check_res->free();
        }
    }

    $active_student_label_esc = $mysqli->real_escape_string($active_student_label);

    // ── Insert ───────────────────────────────────────────────────────────
    $reason_esc       = $mysqli->real_escape_string($reason);
    $identifier_esc   = $mysqli->real_escape_string($identifier_used);
    $leaving_date_esc = $mysqli->real_escape_string($dt->format('Y-m-d'));
    $now              = (new DateTimeImmutable())->format('Y-m-d H:i:s');
    $now_esc          = $mysqli->real_escape_string($now);

    // Cap the IP at 64 chars to fit the column; IPv6 worst case is 39 +
    // some headroom for forwarded chains.
    $ip = '';
    if (isset($_SERVER['HTTP_X_FORWARDED_FOR']) && $_SERVER['HTTP_X_FORWARDED_FOR'] !== '') {
        $first = explode(',', (string) $_SERVER['HTTP_X_FORWARDED_FOR'])[0];
        $ip    = trim($first);
    } elseif (isset($_SERVER['REMOTE_ADDR'])) {
        $ip = (string) $_SERVER['REMOTE_ADDR'];
    }
    if (strlen($ip) > 64) {
        $ip = substr($ip, 0, 64);
    }
    $ip_esc = $mysqli->real_escape_string($ip);

    $insert_sql = "INSERT INTO app_parent_leaving_notices
        (app_parent_id, app_parent_user_id, identifier_used, reason,
         leaving_date, submitted_at, submission_ip, status,
         active_student_id, active_student_label)
        VALUES
        ($app_parent_id, $app_parent_user_id_sql, '$identifier_esc', '$reason_esc',
         '$leaving_date_esc', '$now_esc', '$ip_esc', 'submitted',
         $active_student_id_sql, '$active_student_label_esc')";

    if (!$mysqli->query($insert_sql)) {
        throw new Exception('Failed to record notice: ' . $mysqli->error);
    }

    $insert_id = (int) $mysqli->insert_id;
    $mysqli->close();

    pl_json_out([
        'success'              => true,
        'id'                   => $insert_id,
        'leaving_date'         => $dt->format('Y-m-d'),
        'min_leaving_date'     => $earliest->format('Y-m-d'),
        'submitted_at'         => $now,
        'active_student_id'    => $active_student_id_sql === 'NULL'
            ? null
            : (int) $active_student_id_sql,
        'active_student_label' => $active_student_label,
    ]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    pl_json_out([
        'success' => false,
        'error'   => $e->getMessage(),
    ]);
}
