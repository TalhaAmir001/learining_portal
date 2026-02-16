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

if (empty($user_type) || !in_array($user_type, ['student', 'staff', 'parent'])) {
    sendJson([
        'success' => false,
        'error' => 'Missing or invalid user_type. Use student, staff, or parent.',
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

    if ($filter_student_by_class_section && empty($session_id)) {
        $res = $mysqli->query("SELECT current_session FROM sch_settings LIMIT 1");
        if ($res && $row = $res->fetch_assoc() && !empty($row['current_session'])) {
            $session_id = $row['current_session'];
        }
    }

    if ($filter_student_by_class_section && !empty($session_id)) {
        $session_id = $mysqli->real_escape_string($session_id);
        $student_id = (int) $student_id;
        $sql = "SELECT n.id, n.title, n.publish_date, n.date, n.message, n.attachment,
                n.visible_student, n.visible_staff, n.visible_parent, n.created_id,
                n.is_pinned, n.days
                FROM send_notification n
                LEFT JOIN student_session ss ON ss.student_id = {$student_id} AND ss.session_id = '" . $session_id . "'
                WHERE n.visible_student IN ('Yes', 'yes')
                  AND COALESCE(n.date, n.publish_date) <= CURDATE()
                  AND (n.days IS NULL OR n.days = '' OR DATEDIFF(CURDATE(), COALESCE(n.date, n.publish_date)) <= CAST(NULLIF(TRIM(n.days), '') AS UNSIGNED))
                  AND (
                    (n.class_id IS NULL AND n.section_id IS NULL)
                    OR (n.class_id IS NOT NULL AND n.section_id IS NOT NULL
                        AND ss.class_id = n.class_id AND ss.section_id = n.section_id)
                  )
                ORDER BY n.is_pinned DESC, n.publish_date DESC, n.id DESC";
    } else {
        $sql = "SELECT id, title, publish_date, date, message, attachment,
                visible_student, visible_staff, visible_parent, created_id,
                is_pinned, days
                FROM send_notification
                WHERE {$visibility_column} IN ('Yes', 'yes')
                  AND COALESCE(date, publish_date) <= CURDATE()
                  AND (days IS NULL OR days = '' OR DATEDIFF(CURDATE(), COALESCE(date, publish_date)) <= CAST(NULLIF(TRIM(days), '') AS UNSIGNED))
                ORDER BY is_pinned DESC, publish_date DESC, id DESC";
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