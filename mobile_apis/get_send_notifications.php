<?php
/**
 * Get Send Notifications API
 * Returns notices from send_notifications visible to the given user type.
 * GET or POST: user_type = 'student' | 'staff' | 'parent'
 * (GET is used so redirects do not lose the parameter.)
 */
// Prevent any accidental output before JSON
ob_start();

$user_type = isset($_REQUEST['user_type']) ? trim($_REQUEST['user_type']) : null;

if (empty($user_type) || !in_array($user_type, ['student', 'staff', 'parent'])) {
    ob_end_clean();
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode([
        'success' => false,
        'error' => 'Missing or invalid user_type. Use student, staff, or parent.',
        'notifications' => []
    ]);
    exit;
}

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

    $user_type_esc = $mysqli->real_escape_string($user_type);
    $visibility_column = 'visible_student';
    if ($user_type_esc === 'staff') {
        $visibility_column = 'visible_staff';
    } elseif ($user_type_esc === 'parent') {
        $visibility_column = 'visible_parent';
    }

    $sql = "SELECT id, title, publish_date, date, attachment, message,
            visible_student, visible_staff, visible_parent,
            created_by, created_id, is_active, created_at, updated_at
            FROM send_notification
            ORDER BY publish_date DESC, created_at DESC";

    $result = $mysqli->query($sql);
    if (!$result) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }

    $notifications = [];
    while ($row = $result->fetch_assoc()) {
        $notifications[] = $row;
    }

    $mysqli->close();
    ob_end_clean();
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode([
        'success' => true,
        'notifications' => $notifications
    ]);
    exit;

} catch (Exception $e) {
    if (isset($mysqli)) {
        $mysqli->close();
    }
    ob_end_clean();
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage(),
        'notifications' => []
    ]);
    exit;
}
