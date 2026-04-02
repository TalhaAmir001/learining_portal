<?php
/**
 * Get Daily Feedbacks for Guardian/Parent API
 * Returns all daily feedback entries where the recipient includes any of the guardian's children.
 * Guardian is matched via students.parent_id = parent_id (and fl_chat_users.parent_id for the logged-in guardian).
 * GET or POST: parent_id (required) - the guardian's user/parent id (same as in students.parent_id).
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

$parent_id = isset($_REQUEST['parent_id']) ? trim((string) $_REQUEST['parent_id']) : '';
if ($parent_id === '' || $parent_id === '0') {
    sendJson(['success' => false, 'error' => 'Missing or invalid parent_id.', 'feedbacks' => []]);
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

    $parent_esc = $mysqli->real_escape_string($parent_id);
    $students_result = $mysqli->query("SELECT id FROM students WHERE parent_id = " . (int) $parent_esc . " AND is_active = 'yes'");
    if (!$students_result) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }
    $child_student_ids = [];
    while ($row = $students_result->fetch_assoc()) {
        $child_student_ids[] = (int) $row['id'];
    }
    if (empty($child_student_ids)) {
        $mysqli->close();
        sendJson(['success' => true, 'feedbacks' => [], 'count' => 0]);
        exit;
    }

    $all_feedbacks_result = $mysqli->query("SELECT id, staff_id, message_text, voice_url, class_id, section_id, recipient_student_ids, created_at, updated_at FROM fl_daily_feedback ORDER BY created_at DESC");
    if (!$all_feedbacks_result) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }

    $feedbacks = [];
    while ($row = $all_feedbacks_result->fetch_assoc()) {
        $recipient_json = $row['recipient_student_ids'] ?? '';
        if ($recipient_json === '' || $recipient_json === null) {
            continue;
        }
        $normalized = ',' . preg_replace('/[\s\[\]"]+/', '', $recipient_json) . ',';
        $has_child = false;
        foreach ($child_student_ids as $cid) {
            if (strpos($normalized, ',' . $cid . ',') !== false) {
                $has_child = true;
                break;
            }
        }
        if (!$has_child) {
            continue;
        }

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

        // Resolve recipient student IDs that are this parent's children: show "first name - username"
        $recipient_ids = array_filter(array_map('intval', preg_split('/[\s\[\],"]+/', trim($recipient_json), -1, PREG_SPLIT_NO_EMPTY)));
        $child_ids_in_feedback = array_intersect($recipient_ids, $child_student_ids);
        $recipient_child_names = [];
        if (!empty($child_ids_in_feedback)) {
            $ids_placeholders = implode(',', array_map('intval', $child_ids_in_feedback));
            $name_result = $mysqli->query("SELECT s.id, TRIM(s.firstname) AS firstname, (SELECT u.username FROM users u WHERE u.user_id = s.id LIMIT 1) AS username FROM students s WHERE s.id IN (" . $ids_placeholders . ")");
            if ($name_result) {
                while ($nr = $name_result->fetch_assoc()) {
                    $fn = isset($nr['firstname']) ? trim((string) $nr['firstname']) : '';
                    $un = isset($nr['username']) ? trim((string) $nr['username']) : '';
                    if ($fn !== '' && $un !== '') {
                        $recipient_child_names[] = $fn . ' - ' . $un;
                    } elseif ($fn !== '') {
                        $recipient_child_names[] = $fn;
                    } elseif ($un !== '') {
                        $recipient_child_names[] = $un;
                    } else {
                        $recipient_child_names[] = 'Student ' . (int) $nr['id'];
                    }
                }
            }
        }
        $row['recipient_child_names'] = $recipient_child_names;

        // Check if this parent has played the voice for this feedback
        $voice_played_sql = "SELECT 1 FROM fl_daily_feedback_voice_played WHERE feedback_id = " . $feedback_id . " AND parent_id = " . (int) $parent_esc . " LIMIT 1";
        $vp_result = $mysqli->query($voice_played_sql);
        $row['voice_played_by_parent'] = ($vp_result && $vp_result->num_rows > 0);

        $attachments_sql = "SELECT id, file_url, filename, created_at FROM fl_daily_feedback_attachments WHERE feedback_id = " . $feedback_id . " ORDER BY id ASC";
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
    if ($mysqli) {
        $mysqli->close();
    }
    sendJson([
        'success' => false,
        'error' => $e->getMessage(),
        'feedbacks' => [],
    ]);
    exit;
}
