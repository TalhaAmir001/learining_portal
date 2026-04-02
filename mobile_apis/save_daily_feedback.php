<?php
/**
 * Save or Update Daily Feedback API
 * One feedback per staff per day per (class, section, student): a student can appear in only one feedback per day.
 * Create new or update existing (by feedback_id).
 * POST: staff_id (required), feedback_id (optional for update), message_text, voice_url, attachment_urls (optional JSON array)
 */

header('Content-Type: application/json; charset=utf-8');
ob_start(); // Prevent FCM helper echoes from corrupting JSON response

function sendJson($data) {
    if (ob_get_level()) {
        ob_clean();
    }
    $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    if ($json === false) {
        echo json_encode(['success' => false, 'error' => 'Failed to encode response']);
    } else {
        echo $json;
    }
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    sendJson(['success' => false, 'error' => 'Method not allowed']);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);
if ($input === null && !empty($_POST)) {
    $input = $_POST;
}
if ($input === null) {
    $input = [];
}

$staff_id = isset($input['staff_id']) ? (int) $input['staff_id'] : 0;
if ($staff_id <= 0) {
    sendJson(['success' => false, 'error' => 'Missing or invalid staff_id.']);
    exit;
}

$feedback_id = isset($input['feedback_id']) ? (int) $input['feedback_id'] : null;
$message_text = isset($input['message_text']) ? trim($input['message_text']) : null;
$voice_url = isset($input['voice_url']) ? trim($input['voice_url']) : null;
$class_id = isset($input['class_id']) ? (int) $input['class_id'] : null;
$section_id = isset($input['section_id']) ? (int) $input['section_id'] : null;
$recipient_student_ids = null;
if (isset($input['recipient_student_ids'])) {
    if (is_string($input['recipient_student_ids'])) {
        $decoded = json_decode($input['recipient_student_ids'], true);
        if (is_array($decoded)) {
            $recipient_student_ids = json_encode(array_values(array_map('intval', $decoded)));
        }
    } elseif (is_array($input['recipient_student_ids'])) {
        $recipient_student_ids = json_encode(array_values(array_map('intval', $input['recipient_student_ids'])));
    }
}
$attachment_urls = [];
if (isset($input['attachment_urls'])) {
    if (is_string($input['attachment_urls'])) {
        $decoded = json_decode($input['attachment_urls'], true);
        if (is_array($decoded)) {
            $attachment_urls = $decoded;
        }
    } elseif (is_array($input['attachment_urls'])) {
        $attachment_urls = $input['attachment_urls'];
    }
}
$attachment_list = [];
foreach ($attachment_urls as $a) {
    if (is_string($a)) {
        $attachment_list[] = ['url' => $a, 'filename' => null];
    } elseif (is_array($a) && !empty($a['url'])) {
        $attachment_list[] = [
            'url' => $a['url'],
            'filename' => isset($a['filename']) ? $a['filename'] : null,
        ];
    }
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

    $staff_id_esc = $mysqli->real_escape_string($staff_id);
    $msg_esc = $message_text !== null && $message_text !== '' ? "'" . $mysqli->real_escape_string($message_text) . "'" : 'NULL';
    $voice_esc = $voice_url !== null && $voice_url !== '' ? "'" . $mysqli->real_escape_string($voice_url) . "'" : 'NULL';
    $class_esc = ($class_id !== null && $class_id > 0) ? (int) $class_id : 'NULL';
    $section_esc = ($section_id !== null && $section_id > 0) ? (int) $section_id : 'NULL';
    $recipient_esc = $recipient_student_ids !== null ? "'" . $mysqli->real_escape_string($recipient_student_ids) . "'" : 'NULL';

    $new_student_ids = [];
    if ($recipient_student_ids !== null) {
        $decoded = json_decode($recipient_student_ids, true);
        if (is_array($decoded)) {
            $new_student_ids = array_values(array_map('intval', $decoded));
            $new_student_ids = array_filter($new_student_ids, function ($id) { return $id > 0; });
        }
    }
    $check_exclude_id = ($feedback_id !== null && $feedback_id > 0) ? (int) $feedback_id : 0;
    $class_match = ($class_id !== null && $class_id > 0) ? " AND class_id = " . (int) $class_id : " AND (class_id IS NULL OR class_id = 0)";
    $section_match = ($section_id !== null && $section_id > 0) ? " AND section_id = " . (int) $section_id : " AND (section_id IS NULL OR section_id = 0)";

    foreach ($new_student_ids as $sid) {
        $sid_esc = (int) $sid;
        $exclude = $check_exclude_id > 0 ? " AND id != $check_exclude_id" : '';
        // MariaDB-compatible: cast to string and check if student id appears in array [1,2,3] using comma-boundary match
        $like_pattern = "%,$sid_esc,%";
        $existing = $mysqli->query(
            "SELECT id FROM fl_daily_feedback WHERE staff_id = $staff_id_esc AND DATE(created_at) = CURDATE()"
            . " AND recipient_student_ids IS NOT NULL AND recipient_student_ids != ''"
            . $class_match . $section_match
            . " AND CONCAT(',', REPLACE(REPLACE(REPLACE(REPLACE(CAST(recipient_student_ids AS CHAR), '[', ''), ']', ''), ' ', ''), '\"', ''), ',') LIKE '" . $mysqli->real_escape_string($like_pattern) . "'"
            . " $exclude LIMIT 1"
        );
        if ($existing && $existing->num_rows > 0) {
            $mysqli->close();
            sendJson([
                'success' => false,
                'error' => "A feedback for today already exists for this class, section and student(s). Each student can have only one feedback per day per class/section.",
            ]);
            exit;
        }
    }

    if ($feedback_id !== null && $feedback_id > 0) {
        // Update existing: must belong to this staff
        $fid_esc = (int) $feedback_id;
        $check = $mysqli->query("SELECT id FROM fl_daily_feedback WHERE id = $fid_esc AND staff_id = $staff_id_esc LIMIT 1");
        if (!$check || $check->num_rows === 0) {
            $mysqli->close();
            sendJson(['success' => false, 'error' => 'Feedback not found or you do not have permission to edit it.']);
            exit;
        }
        $mysqli->query("UPDATE fl_daily_feedback SET message_text = $msg_esc, voice_url = $voice_esc, class_id = $class_esc, section_id = $section_esc, recipient_student_ids = $recipient_esc WHERE id = $fid_esc AND staff_id = $staff_id_esc");
        if ($mysqli->error) {
            throw new Exception('Update failed: ' . $mysqli->error);
        }
        $mysqli->query("DELETE FROM fl_daily_feedback_attachments WHERE feedback_id = $fid_esc");
        foreach ($attachment_list as $att) {
            $url_esc = "'" . $mysqli->real_escape_string($att['url']) . "'";
            $fn_esc = $att['filename'] !== null && $att['filename'] !== '' ? "'" . $mysqli->real_escape_string($att['filename']) . "'" : 'NULL';
            $mysqli->query("INSERT INTO fl_daily_feedback_attachments (feedback_id, file_url, filename) VALUES ($fid_esc, $url_esc, $fn_esc)");
        }

        // Notify parents when feedback is edited (same as create)
        $parent_ids = [];
        if (!empty($new_student_ids)) {
            $ids_placeholder = implode(',', array_map('intval', $new_student_ids));
            $parent_res = $mysqli->query("SELECT DISTINCT parent_id FROM students WHERE id IN ($ids_placeholder) AND parent_id IS NOT NULL AND parent_id > 0");
            if ($parent_res) {
                while ($pr = $parent_res->fetch_assoc()) {
                    $parent_ids[] = (int) $pr['parent_id'];
                }
            }
        }

        $mysqli->close();
        $mysqli = null;

        if (!empty($parent_ids) && file_exists(__DIR__ . '/../fcm_notification_helper.php')) {
            require_once __DIR__ . '/../fcm_notification_helper.php';
            $fcm = new FCMNotificationHelper();
            $title = 'Daily Feedback';
            $body = 'Feedback for your child has been updated.';
            $data = ['type' => 'daily_feedback'];
            foreach (array_unique($parent_ids) as $pid) {
                $token = $fcm->getFCMTokenForUser((string) $pid, 'guardian');
                if ($token !== null && $token !== '') {
                    $fcm->sendNotification($token, $title, $body, $data);
                }
            }
        }

        sendJson([
            'success' => true,
            'feedback_id' => $feedback_id,
            'message' => 'Feedback updated.',
        ]);
        exit;
    }

    // Create new: multiple per day allowed; student uniqueness per day already checked above
    $mysqli->query("INSERT INTO fl_daily_feedback (staff_id, message_text, voice_url, class_id, section_id, recipient_student_ids) VALUES ($staff_id_esc, $msg_esc, $voice_esc, $class_esc, $section_esc, $recipient_esc)");
    if ($mysqli->error) {
        throw new Exception('Insert failed: ' . $mysqli->error);
    }
    $new_id = (int) $mysqli->insert_id;

    foreach ($attachment_list as $att) {
        $url_esc = "'" . $mysqli->real_escape_string($att['url']) . "'";
        $fn_esc = $att['filename'] !== null && $att['filename'] !== '' ? "'" . $mysqli->real_escape_string($att['filename']) . "'" : 'NULL';
        $mysqli->query("INSERT INTO fl_daily_feedback_attachments (feedback_id, file_url, filename) VALUES ($new_id, $url_esc, $fn_esc)");
    }

    // Notify parents of recipient students (push + local on their devices)
    $parent_ids = [];
    if (!empty($new_student_ids)) {
        $ids_placeholder = implode(',', array_map('intval', $new_student_ids));
        $parent_res = $mysqli->query("SELECT DISTINCT parent_id FROM students WHERE id IN ($ids_placeholder) AND parent_id IS NOT NULL AND parent_id > 0");
        if ($parent_res) {
            while ($pr = $parent_res->fetch_assoc()) {
                $parent_ids[] = (int) $pr['parent_id'];
            }
        }
    }

    $mysqli->close();
    $mysqli = null;

    if (!empty($parent_ids)) {
        if (file_exists(__DIR__ . '/../fcm_notification_helper.php')) {
            require_once __DIR__ . '/../fcm_notification_helper.php';
            $fcm = new FCMNotificationHelper();
            $title = 'Daily Feedback';
            $body = 'New feedback for your child.';
            $data = ['type' => 'daily_feedback'];
            foreach (array_unique($parent_ids) as $pid) {
                $token = $fcm->getFCMTokenForUser((string) $pid, 'guardian');
                if ($token !== null && $token !== '') {
                    $fcm->sendNotification($token, $title, $body, $data);
                }
            }
        }
    }

    sendJson([
        'success' => true,
        'feedback_id' => $new_id,
        'message' => 'Feedback saved.',
    ]);
    exit;
} catch (Exception $e) {
    if ($mysqli) $mysqli->close();
    sendJson(['success' => false, 'error' => $e->getMessage()]);
    exit;
}
