<?php
/**
 * Mark Notification Read API
 * Inserts a row into read_notifications when user views a notice.
 * POST: notification_id, user_type ('student'|'staff'|'parent'), user_id (API id)
 */

if (!defined('BASEPATH')) {
    define('BASEPATH', __DIR__ . '/../system/');
}
if (!defined('ENVIRONMENT')) {
    define('ENVIRONMENT', 'production');
}

require __DIR__ . '/../application/config/database.php';
$db_config = $db['default'];

$notification_id = isset($_POST['notification_id']) ? (int)$_POST['notification_id'] : 0;
$user_type = $_POST['user_type'] ?? null;
$user_id = isset($_POST['user_id']) ? (int)$_POST['user_id'] : null;

if ($notification_id <= 0 || empty($user_type) || $user_id === null || $user_id < 0) {
    header('Content-Type: application/json');
    echo json_encode([
        'success' => false,
        'error' => 'Missing or invalid notification_id, user_type, or user_id.'
    ]);
    exit;
}

if (!in_array($user_type, ['student', 'staff', 'parent'])) {
    header('Content-Type: application/json');
    echo json_encode([
        'success' => false,
        'error' => 'user_type must be student, staff, or parent.'
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

    $nid = (int) $notification_id;
    $uid = (int) $user_id;

    $student_id = 'NULL';
    $parent_id = 'NULL';
    $staff_id = 'NULL';

    if ($user_type === 'student') {
        $student_id = $uid;
    } elseif ($user_type === 'parent') {
        $parent_id = $uid;
    } else {
        $staff_id = $uid;
    }

    $sql = "INSERT INTO read_notifications
            (student_id, parent_id, staff_id, notification_id, is_active, created_at, updated_at)
            VALUES ($student_id, $parent_id, $staff_id, $nid, 'yes', NOW(), NOW())";

    if ($mysqli->query($sql)) {
        $mysqli->close();
        header('Content-Type: application/json');
        echo json_encode(['success' => true]);
        exit;
    }

    throw new Exception('Insert failed: ' . $mysqli->error);

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
