<?php
/**
 * Shared bootstrap for Term Feedback mobile APIs.
 *
 * Mirrors the role / scope rules of admin/Termfeedback.php and Termfeedback_model:
 *   • Admin (any user_type 'admin' / 'staff' for Super Admin) → full access, history visible.
 *   • Teacher (user_type 'teacher') → restricted to class/section pairs they teach.
 *   • Students/guardians → no access.
 *
 * Period values are validated as YYYY-MM strings (matches the admin controller).
 */

if (!defined('TF_API_SECRET')) {
    $env = getenv('TF_API_SECRET');
    define('TF_API_SECRET', ($env !== false && $env !== '') ? (string) $env : '');
}

function tf_json_out($data) {
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

function tf_mysqli_connect() {
    $mysqli = new mysqli(
        'localhost',
        'portal_beta',
        'X7&?C%Yx5[L-QyiL',
        'portal_beta'
    );
    if ($mysqli->connect_error) {
        tf_json_out(['success' => false, 'error' => 'Database connection failed: ' . $mysqli->connect_error]);
    }
    $mysqli->set_charset('utf8mb4');
    return $mysqli;
}

function tf_read_json_body() {
    $raw  = file_get_contents('php://input');
    $body = json_decode($raw, true);
    if (is_array($body)) {
        return $body;
    }
    return is_array($_POST) ? $_POST : [];
}

function tf_require_api_secret($body) {
    if (TF_API_SECRET === '') {
        return;
    }
    $sent = '';
    if (is_array($body) && isset($body['api_secret'])) {
        $sent = (string) $body['api_secret'];
    }
    if ($sent === '' && !empty($_SERVER['HTTP_X_TF_SECRET'])) {
        $sent = (string) $_SERVER['HTTP_X_TF_SECRET'];
    }
    if ($sent === '' && isset($_GET['api_secret'])) {
        $sent = (string) $_GET['api_secret'];
    }
    if (!hash_equals(TF_API_SECRET, $sent)) {
        tf_json_out(['success' => false, 'error' => 'Invalid or missing api_secret.']);
    }
}

function tf_current_session_id($mysqli) {
    $sr = $mysqli->query('SELECT session_id FROM sch_settings ORDER BY id ASC LIMIT 1');
    if (!$sr || $sr->num_rows === 0) {
        return 0;
    }
    $row = $sr->fetch_assoc();
    return (int) $row['session_id'];
}

/** Validate a YYYY-MM string. */
function tf_is_valid_month($ym) {
    return (bool) preg_match('/^\d{4}-(0[1-9]|1[0-2])$/', (string) $ym);
}

/** Normalise the user_type from the client to one of: admin, teacher, ''. */
function tf_normalise_user_type($raw) {
    $t = strtolower(trim((string) $raw));
    if (in_array($t, ['admin', 'staff', 'super admin', 'administrator'], true)) {
        return 'admin';
    }
    if ($t === 'teacher') {
        return 'teacher';
    }
    return '';
}

/**
 * Classteacher_model::get_staff_lesson_scope() port: returns
 *   [class_id => [section_id, ...], ...]
 * combining `class_teacher` (form teacher) and `subject_timetable` (timetable).
 */
function tf_staff_lesson_scope($mysqli, $staff_id, $session_id) {
    $staff_id   = (int) $staff_id;
    $session_id = (int) $session_id;
    $map        = [];
    if ($staff_id < 1 || $session_id < 1) {
        return $map;
    }

    $add = function ($cid, $sid) use (&$map) {
        $cid = (int) $cid;
        $sid = (int) $sid;
        if ($cid < 1 || $sid < 1) {
            return;
        }
        if (!isset($map[$cid])) {
            $map[$cid] = [];
        }
        if (!in_array($sid, $map[$cid], true)) {
            $map[$cid][] = $sid;
        }
    };

    $res = $mysqli->query(
        "SELECT class_id, section_id FROM class_teacher
         WHERE staff_id = $staff_id AND session_id = $session_id"
    );
    if ($res) {
        while ($r = $res->fetch_assoc()) {
            $add($r['class_id'] ?? 0, $r['section_id'] ?? 0);
        }
    }

    $res = $mysqli->query(
        "SELECT DISTINCT class_id, section_id FROM subject_timetable
         WHERE staff_id = $staff_id AND session_id = $session_id"
    );
    if ($res) {
        while ($r = $res->fetch_assoc()) {
            $add($r['class_id'] ?? 0, $r['section_id'] ?? 0);
        }
    }

    return $map;
}

/**
 * Resolve the caller. Returns:
 *   [
 *     'role'     => 'admin' | 'teacher' | '',
 *     'staff_id' => int (>0 for teacher; may be 0 for super-admin),
 *     'scope'    => [class_id => [section_id, ...], ...] (empty for admin),
 *     'show_history' => bool,
 *     'can_save'     => bool,
 *   ]
 *
 * Mirrors the privilege rules in Termfeedback controller:
 *   • super admin / admin / administrator: full access + history view.
 *   • teacher (role_id=2): can view + save, scoped to their class/section pairs, no history.
 */
function tf_resolve_caller($mysqli, $body) {
    $session_id = tf_current_session_id($mysqli);
    $role_raw   = isset($body['user_type']) ? $body['user_type'] : '';
    $role       = tf_normalise_user_type($role_raw);
    $staff_id   = isset($body['staff_id']) ? (int) $body['staff_id'] : 0;

    if ($role === '') {
        tf_json_out(['success' => false, 'error' => 'Term feedback is available for admin and teacher accounts only.']);
    }

    $scope = [];
    if ($role === 'teacher') {
        if ($staff_id < 1) {
            tf_json_out(['success' => false, 'error' => 'Missing staff_id for teacher.']);
        }
        $scope = tf_staff_lesson_scope($mysqli, $staff_id, $session_id);
    }

    return [
        'role'         => $role,
        'staff_id'     => $staff_id,
        'session_id'   => $session_id,
        'scope'        => $scope,
        'show_history' => $role === 'admin',
        'can_save'     => $role === 'admin' || $role === 'teacher',
    ];
}

/**
 * Returns true if the given (class_id, section_id) pair is allowed for this caller.
 * Admins always pass; teachers must have the pair in their scope.
 */
function tf_caller_allows_class_section(array $caller, $class_id, $section_id) {
    if ($caller['role'] === 'admin') {
        return true;
    }
    $cid = (int) $class_id;
    $sid = (int) $section_id;
    return isset($caller['scope'][$cid]) && in_array($sid, $caller['scope'][$cid], true);
}
