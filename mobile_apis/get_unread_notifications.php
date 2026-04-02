<?php
/**
 * Get Unread Notifications API
 * Returns only notices that the current user has NOT read (same visibility and date rules as get_send_notifications).
 * GET or POST: user_type = 'student' | 'staff' | 'parent'
 * - For user_type=student: pass student_id (required), optionally session_id.
 * - For user_type=staff or parent: pass user_id (required) – API id of the current user.
 */

header('Content-Type: application/json; charset=utf-8');

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
$user_id = isset($_REQUEST['user_id']) ? (int) $_REQUEST['user_id'] : null;

if (empty($user_type) || !in_array($user_type, ['student', 'staff', 'parent'])) {
    sendJson([
        'success' => false,
        'error' => 'Missing or invalid user_type. Use student, staff, or parent.',
        'notifications' => []
    ]);
    exit;
}

if ($user_type === 'student' && (empty($student_id) || $student_id <= 0)) {
    sendJson([
        'success' => false,
        'error' => 'For user_type=student, student_id is required.',
        'notifications' => []
    ]);
    exit;
}

if (in_array($user_type, ['staff', 'parent']) && (empty($user_id) || $user_id <= 0)) {
    sendJson([
        'success' => false,
        'error' => 'For user_type=staff or parent, user_id is required.',
        'notifications' => []
    ]);
    exit;
}

$mysqli = null;
try {
    $mysqli = new mysqli(
        'localhost',
        'portal_beta',
        'X7&?C%Yx5[L-QyiL',
        'portal_beta'
    );

    if ($mysqli->connect_error) {
        throw new Exception('Database connection failed: ' . $mysqli->connect_error);
    }

    $mysqli->set_charset('utf8mb4');

    $column_map = [
        'student' => 'visible_student',
        'staff' => 'visible_staff',
        'parent' => 'visible_parent'
    ];
    $visibility_column = $column_map[$user_type];

    $filter_student_by_class_section = ($user_type === 'student' && $student_id > 0);

    if ($filter_student_by_class_section) {
        $student_id = (int) $student_id;
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
        if (!empty($class_section_pairs)) {
            $class_section_condition = implode(' OR ', $class_section_pairs);
            $sql = "SELECT n.id, n.title, n.publish_date, n.date, n.message, n.attachment,
                    n.visible_student, n.visible_staff, n.visible_parent, n.created_id,
                    n.is_pinned, n.days, 0 AS is_read
                    FROM send_notification n
                    LEFT JOIN read_notification rn ON rn.notification_id = n.id AND rn.student_id = {$student_id}
                    WHERE n.visible_student IN ('Yes', 'yes')
                      AND n.class_id IS NOT NULL AND n.section_id IS NOT NULL
                      AND ({$class_section_condition})
                      AND COALESCE(n.date, n.publish_date) <= CURDATE()
                      AND (n.days IS NULL OR n.days = '' OR DATEDIFF(CURDATE(), COALESCE(n.date, n.publish_date)) <= CAST(NULLIF(TRIM(n.days), '') AS UNSIGNED))
                      AND rn.id IS NULL
                    ORDER BY n.is_pinned DESC, n.publish_date DESC, n.id DESC";
        } else {
            $sql = "SELECT n.id FROM send_notification n WHERE 1 = 0";
        }
    } else {
        $uid = (int) $user_id;
        $rn_join = "LEFT JOIN read_notification rn ON rn.notification_id = n.id AND ";
        if ($user_type === 'staff') {
            $rn_join .= "rn.staff_id = {$uid}";
        } else {
            $rn_join .= "rn.parent_id = {$uid}";
        }
        $sql = "SELECT n.id, n.title, n.publish_date, n.date, n.message, n.attachment,
                n.visible_student, n.visible_staff, n.visible_parent, n.created_id,
                n.is_pinned, n.days, 0 AS is_read
                FROM send_notification n
                {$rn_join}
                WHERE n.{$visibility_column} IN ('Yes', 'yes')
                  AND COALESCE(n.date, n.publish_date) <= CURDATE()
                  AND (n.days IS NULL OR n.days = '' OR DATEDIFF(CURDATE(), COALESCE(n.date, n.publish_date)) <= CAST(NULLIF(TRIM(n.days), '') AS UNSIGNED))
                  AND rn.id IS NULL
                ORDER BY n.is_pinned DESC, n.publish_date DESC, n.id DESC";
    }

    $result = $mysqli->query($sql);
    if (!$result) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }

    $notifications = [];
    while ($row = $result->fetch_assoc()) {
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
