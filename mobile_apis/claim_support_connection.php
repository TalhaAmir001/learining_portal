<?php
/**
 * Claim Support Connection API
 *
 * When an admin opens a support thread (chat with a student), claim it so other admins
 * don't see that student in their Support Inbox.
 *
 * POST: connection_id, staff_id
 */

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
header('Access-Control-Max-Age: 86400');
header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if (!defined('BASEPATH')) {
    define('BASEPATH', __DIR__ . '/../system/');
}
if (!defined('ENVIRONMENT')) {
    define('ENVIRONMENT', 'production');
}

require __DIR__ . '/../application/config/database.php';
$db_config = $db['default'];

$input = json_decode(file_get_contents('php://input'), true);
if ($input) {
    $connection_id = isset($input['connection_id']) ? trim($input['connection_id']) : null;
    $staff_id = isset($input['staff_id']) ? $input['staff_id'] : null;
} else {
    $connection_id = isset($_POST['connection_id']) ? trim($_POST['connection_id']) : null;
    $staff_id = isset($_POST['staff_id']) ? $_POST['staff_id'] : null;
}

if ($connection_id === null || $connection_id === '' || $staff_id === null || $staff_id === '') {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'error' => 'Missing connection_id or staff_id'
    ]);
    exit;
}

$staff_id = intval($staff_id);
$connection_id = intval($connection_id);

if ($connection_id <= 0 || $staff_id <= 0) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'error' => 'Invalid connection_id or staff_id'
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

    // Only update if this connection involves Support (one side is staff_id=0)
    $conn_id_esc = $mysqli->real_escape_string($connection_id);
    $check = $mysqli->query("
        SELECT cc.id FROM fl_chat_connections cc
        JOIN fl_chat_users cu1 ON cc.chat_user_one = cu1.id
        JOIN fl_chat_users cu2 ON cc.chat_user_two = cu2.id
        WHERE cc.id = '$conn_id_esc'
        AND ((cu1.staff_id = 0 AND cu1.user_type = 'staff') OR (cu2.staff_id = 0 AND cu2.user_type = 'staff'))
        LIMIT 1
    ");
    if (!$check || $check->num_rows === 0) {
        $mysqli->close();
        http_response_code(200);
        echo json_encode(['success' => true, 'claimed' => false, 'message' => 'Not a support connection']);
        exit;
    }

    $sql = "UPDATE fl_chat_connections SET support_claimed_by_staff_id = " . intval($staff_id) . ", updated_at = NOW() WHERE id = " . intval($connection_id);
    if ($mysqli->query($sql)) {
        $mysqli->close();
        http_response_code(200);
        echo json_encode(['success' => true, 'claimed' => true]);
        exit;
    }

    throw new Exception('Update failed: ' . $mysqli->error);
} catch (Exception $e) {
    if (isset($mysqli)) {
        $mysqli->close();
    }
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    exit;
}
