<?php
/**
 * Save Support Feedback API
 *
 * Saves support feedback (ticket) text from the chat. The feedback is stored
 * against the admin (staff) who claimed this support connection
 * (support_claimed_by_staff_id). If the connection is not claimed yet,
 * claimed_staff_id is stored as NULL.
 *
 * POST: connection_id (required), feedback_text (required)
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

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['success' => false, 'error' => 'Method not allowed']);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);
if ($input === null && !empty($_POST)) {
    $input = $_POST;
}
if ($input === null) {
    $input = [];
}

$connection_id = isset($input['connection_id']) ? (int) $input['connection_id'] : 0;
$feedback_text = isset($input['feedback_text']) ? trim($input['feedback_text']) : '';

if ($connection_id <= 0) {
    echo json_encode(['success' => false, 'error' => 'Missing or invalid connection_id']);
    exit;
}

if ($feedback_text === '') {
    echo json_encode(['success' => false, 'error' => 'Feedback text is required']);
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

    // Ensure this is a support connection (one side is Support) and get claimed_staff_id
    $conn_esc = (int) $connection_id;
    $check = $mysqli->query("
        SELECT cc.id, cc.support_claimed_by_staff_id
        FROM fl_chat_connections cc
        JOIN fl_chat_users cu1 ON cc.chat_user_one = cu1.id
        JOIN fl_chat_users cu2 ON cc.chat_user_two = cu2.id
        WHERE cc.id = $conn_esc
        AND ((cu1.staff_id = 0 AND cu1.user_type = 'staff') OR (cu2.staff_id = 0 AND cu2.user_type = 'staff'))
        LIMIT 1
    ");
    if (!$check || $check->num_rows === 0) {
        $mysqli->close();
        echo json_encode(['success' => false, 'error' => 'Connection not found or not a support connection']);
        exit;
    }

    $row = $check->fetch_assoc();
    $claimed_staff_id = isset($row['support_claimed_by_staff_id']) && $row['support_claimed_by_staff_id'] !== null
        ? (int) $row['support_claimed_by_staff_id']
        : null;

    $text_esc = $mysqli->real_escape_string($feedback_text);
    $claimed_sql = $claimed_staff_id !== null ? (int) $claimed_staff_id : 'NULL';

    $mysqli->query("
        INSERT INTO fl_support_feedback (chat_connection_id, claimed_staff_id, feedback_text)
        VALUES ($conn_esc, $claimed_sql, '$text_esc')
    ");
    if ($mysqli->error) {
        throw new Exception('Insert failed: ' . $mysqli->error);
    }

    $new_id = (int) $mysqli->insert_id;
    $mysqli->close();
    $mysqli = null;

    echo json_encode([
        'success' => true,
        'feedback_id' => $new_id,
        'message' => 'Support feedback saved.',
    ]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    exit;
}
