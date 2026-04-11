<?php
/**
 * Get Send Notifications API
 * Returns notices from send_notification visible to the given user type.
 * - Pinned notices (is_pinned = 1) appear at the top.
 * - Only notices within their validity window are returned: notice date must be on or before
 *   today, and (if days is set) current date must be within `days` days after the notice date.
 * GET or POST: user_type = 'student' | 'staff' | 'parent'
 * For user_type=student, pass student_id (and optionally session_id) to filter by class/section:
 *   only notices for all students (class_id/section_id null) or for the student's class/section are returned.
 * For user_type=staff, pass staff_id (staff.id / same as app uid): notices are limited by notification_roles
 *   to match Notification_model::get() (role_id 7 = all notices that have any role row; else that role only).
 */

header('Content-Type: application/json; charset=utf-8');

// Ensure we always output JSON (avoid blank response from json_encode failure or fatal errors)
function sendJson($data) {
    $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    if ($json === false) {
        echo json_encode(['success' => false, 'error' => 'Failed to encode response', 'notifications' => []]);
    } else {
        echo $json;
    }
}

$user_type = isset($_REQUEST['user_type']) ? trim($_REQUEST['user_type']) : null;
$student_id = isset($_REQUEST['student_id']) ? (int) $_REQUEST['student_id'] : null;
$session_id = isset($_REQUEST['session_id']) ? trim($_REQUEST['session_id']) : null;
$staff_id_param = isset($_REQUEST['staff_id']) ? (int) $_REQUEST['staff_id'] : 0;
// Comma-separated role ids from app login JSON (same as notification_roles.role_id); required when staff.role_id is empty
$role_ids_param = isset($_REQUEST['role_ids']) ? trim((string) $_REQUEST['role_ids']) : '';

if (empty($user_type) || !in_array($user_type, ['student', 'staff', 'parent'])) {
    sendJson([
        'success' => false,
        'error' => 'Missing or invalid user_type. Use student, staff, or parent.',
        'notifications' => []
    ]);
    exit;
}

if ($user_type === 'student' && (empty($student_id) || (int) $student_id <= 0)) {
    sendJson([
        'success' => false,
        'error' => 'For user_type=student, student_id is required to filter notifications by class/section.',
        'notifications' => []
    ]);
    exit;
}

if ($user_type === 'staff' && $staff_id_param <= 0) {
    sendJson([
        'success' => false,
        'error' => 'For user_type=staff, staff_id is required (staff table id) to filter by notification_roles.',
        'notifications' => []
    ]);
    exit;
}

$mysqli = null;
try {
    require_once __DIR__ . '/notice_staff_role_resolve.php';

    $mysqli = new mysqli(
        'localhost',
        'portal_beta',
        'X7&?C%Yx5[L-QyiL',
        'portal_beta'
    );

    if ($mysqli->connect_error) {
        throw new Exception('Database connection failed: ' . $mysqli->connect_error);
    }

    // Use UTF-8 so apostrophes, en-dashes, bullet points, etc. are returned correctly
    $mysqli->set_charset('utf8mb4');

    // Map user type to column (match Notification_model: 'Yes' / 'yes')
    $column_map = [
        'student' => 'visible_student',
        'staff' => 'visible_staff',
        'parent' => 'visible_parent'
    ];
    $visibility_column = $column_map[$user_type];

    $filter_student_by_class_section = ($user_type === 'student' && $student_id > 0);
    $add_is_read_zero = false;

    if ($filter_student_by_class_section) {
        $student_id = (int) $student_id;
        // Get ALL (class_id, section_id) pairs for this student from student_session (student can appear multiple times)
        $ss_sql = "SELECT DISTINCT class_id, section_id FROM student_session
                   WHERE student_id = {$student_id}
                   AND class_id IS NOT NULL AND section_id IS NOT NULL";
        $ss_result = $mysqli->query($ss_sql);
        $class_section_pairs = [];
        if ($ss_result) {
            while ($ss_row = $ss_result->fetch_assoc()) {
                $c = (int) $ss_row['class_id'];
                $s = (int) $ss_row['section_id'];
                $class_section_pairs[] = "(n.class_id = {$c} AND n.section_id = {$s})";
            }
        }
        // Only class/section-wise: skip notices where class_id/section_id are null; match ANY of student's class/section pairs
        if (!empty($class_section_pairs)) {
            $class_section_condition = implode(' OR ', $class_section_pairs);
            $sql = "SELECT n.id, n.title, n.publish_date, n.date, n.message, n.attachment,
                    n.visible_student, n.visible_staff, n.visible_parent, n.created_id,
                    n.is_pinned, n.days,
                    IF(rn.id IS NULL, 0, 1) AS is_read
                    FROM send_notification n
                    LEFT JOIN read_notification rn ON rn.notification_id = n.id AND rn.student_id = {$student_id}
                    WHERE n.visible_student IN ('Yes', 'yes')
                      AND n.class_id IS NOT NULL AND n.section_id IS NOT NULL
                      AND ({$class_section_condition})
                      AND COALESCE(n.date, n.publish_date) <= CURDATE()
                      AND (n.days IS NULL OR n.days = '' OR DATEDIFF(CURDATE(), COALESCE(n.date, n.publish_date)) <= CAST(NULLIF(TRIM(n.days), '') AS UNSIGNED))
                    ORDER BY n.is_pinned DESC, n.publish_date DESC, n.id DESC";
        } else {
            // Student has no class/section in student_session: return no notifications
            $sql = "SELECT n.id FROM send_notification n WHERE 1 = 0";
        }
    } elseif ($user_type === 'staff') {
        $sid = (int) $staff_id_param;
        $resolved_roles = notice_resolve_staff_role_ids($mysqli, $sid, $role_ids_param !== '' ? $role_ids_param : null);
        $nr_join = notice_staff_notification_roles_join($resolved_roles);
        $sql = "SELECT n.id, n.title, n.publish_date, n.date, n.message, n.attachment,
                n.visible_student, n.visible_staff, n.visible_parent, n.created_id,
                n.is_pinned, n.days
                FROM send_notification n
                {$nr_join}
                WHERE n.visible_staff IN ('Yes', 'yes')
                  AND COALESCE(n.date, n.publish_date) <= CURDATE()
                  AND (n.days IS NULL OR n.days = '' OR DATEDIFF(CURDATE(), COALESCE(n.date, n.publish_date)) <= CAST(NULLIF(TRIM(n.days), '') AS UNSIGNED))
                ORDER BY n.is_pinned DESC, n.publish_date DESC, n.id DESC";
        $add_is_read_zero = true;
    } else {
        // parent: all visible_parent notices (no notification_roles for parents on web)
        $sql = "SELECT id, title, publish_date, date, message, attachment,
                visible_student, visible_staff, visible_parent, created_id,
                is_pinned, days
                FROM send_notification
                WHERE {$visibility_column} IN ('Yes', 'yes')
                  AND COALESCE(date, publish_date) <= CURDATE()
                  AND (days IS NULL OR days = '' OR DATEDIFF(CURDATE(), COALESCE(date, publish_date)) <= CAST(NULLIF(TRIM(days), '') AS UNSIGNED))
                ORDER BY is_pinned DESC, publish_date DESC, id DESC";
        $add_is_read_zero = true;
    }

    $result = $mysqli->query($sql);
    if (!$result) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }

    $notifications = [];
    while ($row = $result->fetch_assoc()) {
        if ($add_is_read_zero) {
            $row['is_read'] = 0;
        }
        $notifications[] = $row;
    }

    $mysqli->close();
    $mysqli = null;

    sendJson([
        'success' => true,
        'notifications' => $notifications,
        'count' => count($notifications)
    ]);
    exit;

} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    sendJson([
        'success' => false,
        'error' => $e->getMessage(),
        'notifications' => []
    ]);
    exit;
}