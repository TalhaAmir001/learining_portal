<?php
/**
 * Get Send Notifications API
 * Returns notices from send_notifications visible to the given user type.
 * POST: user_type = 'student' | 'staff' | 'parent'
 */

if (!defined('BASEPATH')) {
    define('BASEPATH', __DIR__ . '/../system/');
}
if (!defined('ENVIRONMENT')) {
    define('ENVIRONMENT', 'production');
}

require __DIR__ . '/../application/config/database.php';
$db_config = $db['default'];

$user_type = $_POST['user_type'] ?? null;

if (empty($user_type) || !in_array($user_type, ['student', 'staff', 'parent'])) {
    header('Content-Type: application/json');
    echo json_encode([
        'success' => false,
        'error' => 'Missing or invalid user_type. Use student, staff, or parent.'
    ]);
    exit;
}

try {
    $mysqli = new mysqli(
        $db_config['hostname'],
        $db_config['username'],
        $db_config['password'],
        $db_config['database']
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
            FROM send_notifications
            WHERE is_active = 'yes'
            AND " . $visibility_column . " = 'yes'
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
    header('Content-Type: application/json');
    echo json_encode([
        'success' => true,
        'notifications' => $notifications
    ]);
    exit;

} catch (Exception $e) {
    if (isset($mysqli)) {
        $mysqli->close();
    }
    header('Content-Type: application/json');
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage()
    ]);
    exit;
}
