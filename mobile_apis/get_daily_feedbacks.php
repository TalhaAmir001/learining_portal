<?php
/**
 * Get Daily Feedbacks API
 * Returns daily feedback entries for the given admin (staff_id).
 * GET or POST: staff_id (required)
 */

header('Content-Type: application/json; charset=utf-8');

function sendJson($data) {
    $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    if ($json === false) {
        echo json_encode(['success' => false, 'error' => 'Failed to encode response', 'feedbacks' => []]);
    } else {
        echo $json;
    }
}

$staff_id = isset($_REQUEST['staff_id']) ? (int) $_REQUEST['staff_id'] : 0;
if ($staff_id <= 0) {
    sendJson(['success' => false, 'error' => 'Missing or invalid staff_id.', 'feedbacks' => []]);
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

    $staff_id = $mysqli->real_escape_string($staff_id);
    $sql = "SELECT id, staff_id, message_text, voice_url, class_id, section_id, recipient_student_ids, created_at, updated_at
            FROM fl_daily_feedback
            WHERE staff_id = " . $staff_id . "
            ORDER BY created_at DESC";
    $result = $mysqli->query($sql);
    if (!$result) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }

    $feedbacks = [];
    while ($row = $result->fetch_assoc()) {
        $feedback_id = (int) $row['id'];
        $class_id = isset($row['class_id']) ? (int) $row['class_id'] : null;
        $section_id = isset($row['section_id']) ? (int) $row['section_id'] : null;
        if ($class_id > 0) {
            $cr = $mysqli->query("SELECT `class` AS class_name FROM classes WHERE id = " . $class_id . " LIMIT 1");
            $row['class_name'] = ($cr && $cr_row = $cr->fetch_assoc()) ? $cr_row['class_name'] : null;
        } else {
            $row['class_name'] = null;
        }
        if ($section_id > 0) {
            $sr = $mysqli->query("SELECT section AS section_name FROM sections WHERE id = " . $section_id . " LIMIT 1");
            $row['section_name'] = ($sr && $sr_row = $sr->fetch_assoc()) ? $sr_row['section_name'] : null;
        } else {
            $row['section_name'] = null;
        }
        $attachments_sql = "SELECT id, file_url, filename, created_at
                            FROM fl_daily_feedback_attachments
                            WHERE feedback_id = " . $feedback_id . "
                            ORDER BY id ASC";
        $att_result = $mysqli->query($attachments_sql);
        $attachments = [];
        if ($att_result) {
            while ($att = $att_result->fetch_assoc()) {
                $attachments[] = $att;
            }
        }
        $row['attachments'] = $attachments;
        $feedbacks[] = $row;
    }

    $mysqli->close();
    $mysqli = null;
    sendJson([
        'success' => true,
        'feedbacks' => $feedbacks,
        'count' => count($feedbacks),
    ]);
    exit;
} catch (Exception $e) {
    if ($mysqli) $mysqli->close();
    sendJson([
        'success' => false,
        'error' => $e->getMessage(),
        'feedbacks' => [],
    ]);
    exit;
}
