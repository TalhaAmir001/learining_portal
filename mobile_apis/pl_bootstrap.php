<?php
/**
 * Shared bootstrap for "Parent Self-Link Children" mobile APIs.
 *
 * Trust model (code-based):
 *   1. School admin generates a 6-char one-time `mobile_app_code` on each
 *      `students` row.
 *   2. Guardian enters that code in the mobile app.
 *   3. Server confirms the code is valid + unused, then writes a row in
 *      `app_parent_students(parent_id, student_id)` and marks the code as
 *      consumed.
 *
 * Identity:
 *   • Guardian login still happens against `users` (the existing flow).
 *   • A 1:1 mobile profile is then materialised in `app_parents`, keyed by
 *     `users.email` (or a stable fallback if that's blank). This is the
 *     `parent_id` everything downstream uses.
 *
 * Required schema (run mobile_apis/parent_link_tables.sql once):
 *   • app_parents              — UNIQUE(email), active_child_id INT NULL
 *   • app_parent_students      — UNIQUE(parent_id, student_id)
 *   • students.mobile_app_code (CHAR 6 UNIQUE),
 *     mobile_app_code_used (TINYINT),
 *     mobile_app_code_used_at (DATETIME),
 *     mobile_app_code_used_by_parent_id (INT)
 */

if (!defined('PL_API_SECRET')) {
    $env = getenv('PL_API_SECRET');
    define('PL_API_SECRET', ($env !== false && $env !== '') ? (string) $env : '');
}

function pl_json_out($data) {
    if (!headers_sent()) {
        header('Content-Type: application/json; charset=utf-8');
    }
    $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    if ($json === false) {
        echo json_encode(['success' => false, 'error' => 'Failed to encode response']);
    } else {
        echo $json;
    }
    exit;
}

function pl_mysqli_connect() {
    $mysqli = new mysqli(
        'localhost',
        'portal_beta',
        'X7&?C%Yx5[L-QyiL',
        'portal_beta'
    );
    if ($mysqli->connect_error) {
        pl_json_out(['success' => false, 'error' => 'Database connection failed: ' . $mysqli->connect_error]);
    }
    $mysqli->set_charset('utf8mb4');
    return $mysqli;
}

function pl_read_json_body() {
    $raw  = file_get_contents('php://input');
    $body = json_decode($raw, true);
    if (is_array($body)) {
        return $body;
    }
    return is_array($_POST) ? $_POST : [];
}

function pl_require_api_secret($body) {
    if (PL_API_SECRET === '') {
        return;
    }
    $sent = '';
    if (is_array($body) && isset($body['api_secret'])) {
        $sent = (string) $body['api_secret'];
    }
    if ($sent === '' && !empty($_SERVER['HTTP_X_PL_SECRET'])) {
        $sent = (string) $_SERVER['HTTP_X_PL_SECRET'];
    }
    if ($sent === '' && isset($_GET['api_secret'])) {
        $sent = (string) $_GET['api_secret'];
    }
    if (!hash_equals(PL_API_SECRET, $sent)) {
        pl_json_out(['success' => false, 'error' => 'Invalid or missing api_secret.']);
    }
}

function pl_current_session_id($mysqli) {
    $sr = $mysqli->query('SELECT session_id FROM sch_settings ORDER BY id ASC LIMIT 1');
    if (!$sr || $sr->num_rows === 0) {
        return 0;
    }
    $row = $sr->fetch_assoc();
    return (int) $row['session_id'];
}

/** Schema check — does $column exist on $table? Cached per-request. */
function pl_table_has_column($mysqli, $table, $column) {
    static $cache = [];
    $key = $table . '.' . $column;
    if (array_key_exists($key, $cache)) {
        return $cache[$key];
    }
    $tbl_esc = $mysqli->real_escape_string($table);
    $col_esc = $mysqli->real_escape_string($column);
    $r = $mysqli->query("SHOW COLUMNS FROM `$tbl_esc` LIKE '$col_esc'");
    $exists = ($r && $r->num_rows > 0);
    if ($r) {
        $r->free();
    }
    $cache[$key] = $exists;
    return $exists;
}

/**
 * Normalise + validate a 6-char mobile_app_code. Returns the normalised
 * (upper-cased, trimmed) code or '' if it doesn't fit the expected shape.
 */
function pl_normalise_code($raw) {
    $s = strtoupper(trim((string) $raw));
    // Allow A-Z and 0-9 only, must be exactly 6 chars.
    if (!preg_match('/^[A-Z0-9]{6}$/', $s)) {
        return '';
    }
    return $s;
}

/**
 * Resolve the calling parent's mobile profile in `app_parents`. Supports
 * two identity styles so callers can migrate incrementally:
 *
 *   • Preferred (new flow, after `parent_login.php`):
 *       caller_user_type = 'app_parent'
 *       caller_user_id   = app_parents.id   (or `caller_app_parent_id`)
 *     The server simply SELECTs that row — no bridge needed.
 *
 *   • Legacy (existing guardian-via-users):
 *       caller_user_type = 'guardian' | 'parent'
 *       caller_user_id   = users.id
 *     The server looks up `users`, finds an `app_parents` row by
 *     LOWER(email) (with a synthetic fallback), and lazily creates one
 *     if missing.
 *
 * Terminates the request with a JSON error if the caller can't be resolved.
 *
 * @return array Row from `app_parents` (id, name, email, phone, active_child_id?)
 */
function pl_resolve_app_parent($mysqli, $body) {
    $raw_type = isset($body['caller_user_type']) ? (string) $body['caller_user_type'] : '';
    $type     = strtolower(trim($raw_type));

    // ─── Direct path: caller already authenticated via parent_login.php ───
    if ($type === 'app_parent' || isset($body['caller_app_parent_id'])) {
        $app_parent_id = 0;
        if (isset($body['caller_app_parent_id'])) {
            $app_parent_id = (int) $body['caller_app_parent_id'];
        } elseif (isset($body['caller_user_id'])) {
            $app_parent_id = (int) $body['caller_user_id'];
        }
        if ($app_parent_id < 1) {
            pl_json_out(['success' => false, 'error' => 'Missing or invalid app_parent id.']);
        }
        $r = $mysqli->query("SELECT * FROM app_parents WHERE id = $app_parent_id LIMIT 1");
        if (!$r || $r->num_rows === 0) {
            pl_json_out(['success' => false, 'error' => 'Parent profile not found. Please log in again.']);
        }
        $row = $r->fetch_assoc();
        $r->free();
        return $row;
    }

    // ─── Legacy bridge: guardian on `users` → app_parents by email ────────
    if ($type !== 'guardian' && $type !== 'parent') {
        pl_json_out(['success' => false, 'error' => 'This action is only available to guardian accounts.']);
    }

    $user_id = isset($body['caller_user_id']) ? (int) $body['caller_user_id'] : 0;
    if ($user_id < 1) {
        pl_json_out(['success' => false, 'error' => 'Missing or invalid caller_user_id.']);
    }

    $res = $mysqli->query("SELECT id, username, email, role FROM users WHERE id = $user_id LIMIT 1");
    if (!$res || $res->num_rows === 0) {
        pl_json_out(['success' => false, 'error' => 'Guardian account not found.']);
    }
    $user = $res->fetch_assoc();
    $res->free();
    $role = strtolower(trim((string) ($user['role'] ?? '')));
    if ($role !== 'parent' && $role !== 'guardian') {
        pl_json_out(['success' => false, 'error' => 'This action is only available to guardian accounts.']);
    }

    // `app_parents.email` is UNIQUE NOT NULL — synthesise a stable key when
    // the portal user has no email on file.
    $email = pl_email_for_user($user);

    return pl_find_or_create_app_parent($mysqli, $email, $user);
}

/** Resolve the lookup email for a `users` row with a stable fallback. */
function pl_email_for_user(array $user) {
    $email = trim((string) ($user['email'] ?? ''));
    if ($email !== '') {
        return strtolower($email);
    }
    $username = trim((string) ($user['username'] ?? ''));
    if ($username !== '') {
        return strtolower($username);
    }
    $uid = (int) ($user['id'] ?? 0);
    return 'app+' . $uid . '@local';
}

/** Display name for a freshly-created `app_parents` row. */
function pl_display_name_for_user(array $user) {
    $username = trim((string) ($user['username'] ?? ''));
    if ($username !== '') {
        return $username;
    }
    $email = trim((string) ($user['email'] ?? ''));
    if ($email !== '' && str_contains($email, '@')) {
        return explode('@', $email, 2)[0];
    }
    $uid = (int) ($user['id'] ?? 0);
    return 'Guardian #' . $uid;
}

/**
 * Public response shape for an `app_parents` row + a optional
 * `app_parent_users` row paired with it. Keeps `parent_login.php` and the
 * other endpoints in lock-step so the Flutter app sees the same fields
 * regardless of entry point.
 */
function pl_app_parent_profile_payload(array $parent, ?array $user = null) {
    $active = $parent['active_child_id'] ?? null;
    $active_id = ($active !== null && $active !== '') ? (int) $active : null;

    $out = [
        'app_parent_id'   => (int) ($parent['id'] ?? 0),
        'name'            => (string) ($parent['name'] ?? ''),
        'email'           => (string) ($parent['email'] ?? ''),
        'phone'           => (string) ($parent['phone'] ?? ''),
        'active_child_id' => $active_id,
    ];
    if ($user !== null) {
        $out['app_parent_user_id'] = (int) ($user['id'] ?? 0);
        $out['username']           = (string) ($user['username'] ?? '');
        // Prefer the login email when it exists; falls back to the
        // app_parents email otherwise.
        $u_email = trim((string) ($user['email'] ?? ''));
        if ($u_email !== '') {
            $out['email'] = $u_email;
        }
    }
    return $out;
}

function pl_find_or_create_app_parent($mysqli, $email_lc, array $user) {
    $email_esc = $mysqli->real_escape_string($email_lc);

    $existing = $mysqli->query(
        "SELECT * FROM app_parents WHERE LOWER(email) = '$email_esc' LIMIT 1"
    );
    if ($existing && $existing->num_rows > 0) {
        $row = $existing->fetch_assoc();
        $existing->free();
        return $row;
    }
    if ($existing) {
        $existing->free();
    }

    $name_esc = $mysqli->real_escape_string(pl_display_name_for_user($user));
    $ok = $mysqli->query(
        "INSERT INTO app_parents (name, email, phone, created_at)
         VALUES ('$name_esc', '$email_esc', '', NOW())"
    );
    if (!$ok) {
        pl_json_out(['success' => false, 'error' => 'Failed to create parent profile: ' . $mysqli->error]);
    }
    $parent_id = (int) $mysqli->insert_id;

    $r = $mysqli->query("SELECT * FROM app_parents WHERE id = $parent_id LIMIT 1");
    if (!$r || $r->num_rows === 0) {
        pl_json_out(['success' => false, 'error' => 'Parent profile created but could not be re-read.']);
    }
    $row = $r->fetch_assoc();
    $r->free();
    return $row;
}

/**
 * Map a `students` row + (optional) joined session row into the JSON shape
 * the Flutter `ParentChild` model expects.
 *
 * Expected columns on $row: student_id, firstname, middlename, lastname,
 * admission_no, dob, class_name, section_name, is_active.
 */
function pl_map_child_row(array $row) {
    return [
        'student_id'   => (int) ($row['student_id'] ?? 0),
        'firstname'    => (string) ($row['firstname'] ?? ''),
        'middlename'   => (string) ($row['middlename'] ?? ''),
        'lastname'     => (string) ($row['lastname'] ?? ''),
        'admission_no' => (string) ($row['admission_no'] ?? ''),
        'dob'          => (string) ($row['dob'] ?? ''),
        'class_name'   => (string) ($row['class_name'] ?? ''),
        'section_name' => (string) ($row['section_name'] ?? ''),
        'is_active'    => strtolower((string) ($row['is_active'] ?? 'yes')) === 'yes',
    ];
}

/**
 * Look up a single student by `mobile_app_code` for code-based linking.
 * Returns the joined row (with class/section for the current session) or
 * null if no row matches. The result includes the code's used flags.
 *
 * @return array|null
 */
function pl_find_student_by_code($mysqli, $code, $session_id) {
    $code_esc = $mysqli->real_escape_string($code);
    $sid      = (int) $session_id;

    $session_join = $sid > 0
        ? "LEFT JOIN student_session ss ON ss.student_id = st.id AND ss.session_id = $sid
           LEFT JOIN classes  c   ON c.id   = ss.class_id
           LEFT JOIN sections sec ON sec.id = ss.section_id"
        : "LEFT JOIN student_session ss ON ss.student_id = st.id
           LEFT JOIN classes  c   ON c.id   = ss.class_id
           LEFT JOIN sections sec ON sec.id = ss.section_id";

    $sql = "SELECT
                st.id            AS student_id,
                st.firstname,
                st.middlename,
                st.lastname,
                st.admission_no,
                st.dob,
                st.is_active,
                st.mobile_app_code,
                st.mobile_app_code_used,
                st.mobile_app_code_used_at,
                st.mobile_app_code_used_by_parent_id,
                IFNULL(c.class,  '') AS class_name,
                IFNULL(sec.section, '') AS section_name
            FROM students st
            $session_join
            WHERE st.mobile_app_code = '$code_esc'
            ORDER BY ss.id DESC
            LIMIT 1";

    $r = $mysqli->query($sql);
    if (!$r || $r->num_rows === 0) {
        return null;
    }
    $row = $r->fetch_assoc();
    $r->free();
    return $row;
}

/**
 * Fetch a child's display row for the current session, used when we already
 * know the student_id (e.g. "already_linked" return shape). Returns null if
 * the student is not enrolled in the active session.
 */
function pl_get_child_for_active_session($mysqli, $student_id, $session_id) {
    $student_id = (int) $student_id;
    $session_id = (int) $session_id;
    if ($student_id < 1 || $session_id < 1) {
        return null;
    }
    $sql = "SELECT
                st.id            AS student_id,
                st.firstname,
                st.middlename,
                st.lastname,
                st.admission_no,
                st.dob,
                st.is_active,
                c.class          AS class_name,
                sec.section      AS section_name
            FROM students st
            INNER JOIN student_session ss ON ss.student_id = st.id AND ss.session_id = $session_id
            INNER JOIN classes  c   ON c.id   = ss.class_id
            INNER JOIN sections sec ON sec.id = ss.section_id
            WHERE st.id = $student_id
            ORDER BY ss.id DESC
            LIMIT 1";
    $r = $mysqli->query($sql);
    if (!$r || $r->num_rows === 0) {
        return null;
    }
    $row = $r->fetch_assoc();
    $r->free();
    return $row;
}
