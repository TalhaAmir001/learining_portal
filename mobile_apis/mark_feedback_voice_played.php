<?php
/**
 * Mark feedback voice as played by a parent/guardian.
 * POST: feedback_id (required), parent_id (required).
 */

header('Content-Type: application/json; charset=utf-8');

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

$feedback_id = isset($input['feedback_id']) ? (int) $input['feedback_id'] : 0;
$parent_id = isset($input['parent_id']) ? (int) $input['parent_id'] : 0;

if ($feedback_id <= 0 || $parent_id <= 0) {
    echo json_encode(['success' => false, 'error' => 'Missing or invalid feedback_id and parent_id.']);
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
    $mysqli->set_charset('utf8mb4');

    $stmt = $mysqli->prepare('INSERT INTO fl_daily_feedback_voice_played (feedback_id, parent_id) VALUES (?, ?) ON DUPLICATE KEY UPDATE played_at = NOW()');
    if (!$stmt) {
        $mysqli->close();
        echo json_encode(['success' => false, 'error' => 'Prepare failed. Table fl_daily_feedback_voice_played may not exist.']);
        exit;
    }
    $stmt->bind_param('ii', $feedback_id, $parent_id);
    $stmt->execute();
    $stmt->close();
    $mysqli->close();

    echo json_encode(['success' => true]);
} catch (Exception $e) {
    if (isset($mysqli)) {
        $mysqli->close();
    }
    echo json_encode(['success' => false, 'error' => $e->getMessage()]);
}
