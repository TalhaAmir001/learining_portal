<?php
/**
 * Create or verify chat user in fl_chat_users (HTTP API).
 * user_type: student, guardian, teacher, admin. Support (staff_id=0) is created via add_support_chat_user.sql.
 * Uses staff_id (admins), student_id, teacher_id, parent_id per user_type.
 */

if (!defined('BASEPATH')) {
    define('BASEPATH', __DIR__ . '/../system/');
}
if (!defined('ENVIRONMENT')) {
    define('ENVIRONMENT', 'production');
}

require __DIR__ . '/../application/config/database.php';
header('Content-Type: application/json');

$input = json_decode(file_get_contents('php://input'), true) ?: $_POST;
$user_id = $input['user_id'] ?? null;
$user_type = isset($input['user_type']) ? strtolower(trim($input['user_type'])) : 'student';

$valid_types = ['student', 'guardian', 'teacher', 'admin'];
if ($user_id === null || $user_id === '') {
    echo json_encode(['success' => false, 'error' => 'Missing user_id']);
    exit;
}
if (!in_array($user_type, $valid_types)) {
    echo json_encode([
        'success' => false,
        'error' => 'Invalid user_type. Must be one of: ' . implode(', ', $valid_types),
    ]);
    exit;
}

$db = $db['default'];
$mysqli = new mysqli($db['hostname'], $db['username'], $db['password'], $db['database']);
if ($mysqli->connect_error) {
    echo json_encode(['success' => false, 'error' => 'Database connection failed']);
    exit;
}

$user_id = $mysqli->real_escape_string((string) $user_id);
$user_type = $mysqli->real_escape_string($user_type);

function getIdColumnForUserType($user_type) {
    $t = strtolower(trim($user_type));
    if (in_array($t, ['staff', 'admin'], true)) return 'staff_id';
    if ($t === 'teacher') return 'teacher_id';
    if (in_array($t, ['guardian', 'parent'], true)) return 'parent_id';
    return 'student_id';
}

function getChatUserId($mysqli, $user_id, $user_type) {
    $col = getIdColumnForUserType($user_type);
    $sql = "SELECT id FROM fl_chat_users WHERE $col = '$user_id' LIMIT 1";
    $result = $mysqli->query($sql);
    if ($result && $row = $result->fetch_assoc()) {
        return (int) $row['id'];
    }
    return null;
}

$chat_user_id = getChatUserId($mysqli, $user_id, $user_type);
$is_new = false;

if (!$chat_user_id) {
    $col = getIdColumnForUserType($user_type);
    $mysqli->query("UPDATE fl_chat_users SET user_type = '$user_type', updated_at = NOW() WHERE $col = '$user_id'");
    if ($mysqli->affected_rows > 0) {
        $chat_user_id = getChatUserId($mysqli, $user_id, $user_type);
    }
    if (!$chat_user_id) {
        $staff = $col === 'staff_id' ? "'$user_id'" : 'NULL';
        $student = $col === 'student_id' ? "'$user_id'" : 'NULL';
        $teacher = $col === 'teacher_id' ? "'$user_id'" : 'NULL';
        $parent = $col === 'parent_id' ? "'$user_id'" : 'NULL';
        $mysqli->query("INSERT INTO fl_chat_users (staff_id, student_id, teacher_id, parent_id, user_type, created_at, updated_at)
            VALUES ($staff, $student, $teacher, $parent, '$user_type', NOW(), NOW())");
        $chat_user_id = getChatUserId($mysqli, $user_id, $user_type);
    }
    $is_new = (bool) $chat_user_id;
}

// For students: fetch class/section from student_session and save to fl_chat_users
if ($chat_user_id && $user_type === 'student') {
    $student_id_int = (int) $user_id;
    $sessions_sql = "SELECT DISTINCT ss.class_id, ss.section_id
        FROM student_session ss
        WHERE ss.student_id = " . $student_id_int . "
        AND ss.class_id IS NOT NULL AND ss.section_id IS NOT NULL
        ORDER BY ss.class_id, ss.section_id";
    $sessions_result = $mysqli->query($sessions_sql);
    $class_section_list = [];
    if ($sessions_result) {
        while ($row = $sessions_result->fetch_assoc()) {
            $cid = (int) $row['class_id'];
            $sid = (int) $row['section_id'];
            $class_name = null;
            $section_name = null;
            $cr = $mysqli->query("SELECT `class` FROM classes WHERE id = " . $cid . " LIMIT 1");
            if ($cr && $cr_row = $cr->fetch_assoc()) {
                $class_name = $cr_row['class'];
            }
            $sr = $mysqli->query("SELECT section FROM sections WHERE id = " . $sid . " LIMIT 1");
            if ($sr && $sr_row = $sr->fetch_assoc()) {
                $section_name = $sr_row['section'];
            }
            $class_section_list[] = [
                'class_id' => $cid,
                'section_id' => $sid,
                'class_name' => $class_name,
                'section_name' => $section_name,
            ];
        }
    }
    $json = json_encode($class_section_list, JSON_UNESCAPED_UNICODE);
    $json_esc = $mysqli->real_escape_string($json);
    $update_col = getIdColumnForUserType($user_type);
    $mysqli->query("UPDATE fl_chat_users SET class_section_data = '$json_esc', updated_at = NOW() WHERE id = " . $chat_user_id . " AND $update_col = '$user_id'");
}

$mysqli->close();

if ($chat_user_id) {
    echo json_encode([
        'success' => true,
        'status' => 'success',
        'chat_user_id' => $chat_user_id,
        'is_new' => $is_new,
    ]);
} else {
    echo json_encode([
        'success' => false,
        'error' => 'Failed to create or find chat user entry.',
    ]);
}
