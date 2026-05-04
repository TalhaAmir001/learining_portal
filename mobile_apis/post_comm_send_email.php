<?php
/**
 * Communicate — compose & send email (stores `messages` row like web log + best-effort PHP mail()).
 *
 * POST JSON:
 * {
 *   "title": "Required subject",
 *   "message": "HTML or plain text (plain is wrapped in <p>)",
 *   "send_mail": true,
 *   "send_sms": false,
 *   "audience": "class" | "individual",
 *   "send_to": ["student"],
 *   "class_id": 0,
 *   "section_ids": [41,42],
 *   "individual_emails": "a@x.com, b@y.com",
 *   "is_schedule": false,
 *   "schedule_date_time": ""
 * }
 *
 * audience=class: class_id > 0, section_ids non-empty. Resolves active students in current session.
 * audience=individual: individual_emails with at least one valid address.
 *
 * SMS: stored on row with mobileno in user_list; actual SMS gateway is not invoked here (same limitation as basic PHP).
 */

header('Content-Type: application/json; charset=utf-8');

function comm_send_out(array $data) {
    $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    if ($json === false) {
        echo json_encode(['success' => false, 'error' => 'Failed to encode response']);
    } else {
        echo $json;
    }
}

function comm_read_json_body(): array {
    $raw = file_get_contents('php://input');
    if ($raw === false || $raw === '') {
        return [];
    }
    $decoded = json_decode($raw, true);
    return is_array($decoded) ? $decoded : [];
}

function comm_session_id(mysqli $mysqli): int {
    $sr = $mysqli->query('SELECT session_id FROM sch_settings ORDER BY id ASC LIMIT 1');
    if (!$sr || $sr->num_rows === 0) {
        return 0;
    }
    return (int) $sr->fetch_assoc()['session_id'];
}

function comm_ensure_html(string $msg): string {
    $t = trim($msg);
    if ($t === '') {
        return '<p></p>';
    }
    if (strpos($t, '<') !== false) {
        return $t;
    }
    return '<p>' . htmlspecialchars($t, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8') . '</p>';
}

/**
 * @return array<int, array{user_id:string,email:string,mobileno:string,role:string}>
 */
function comm_recipients_class_sections(
    mysqli $mysqli,
    int $session_id,
    int $class_id,
    array $section_ids
): array {
    if ($session_id <= 0 || $class_id <= 0 || empty($section_ids)) {
        return [];
    }
    $section_ids = array_values(array_unique(array_map('intval', $section_ids)));
    $section_ids = array_filter($section_ids, function ($v) {
        return $v > 0;
    });
    if (empty($section_ids)) {
        return [];
    }
    $in = implode(',', $section_ids);
    $sql = "SELECT DISTINCT st.id, st.email, st.mobileno
        FROM students st
        INNER JOIN student_session ss ON ss.student_id = st.id
        WHERE ss.session_id = ?
          AND ss.class_id = ?
          AND ss.section_id IN ($in)
          AND st.is_active = 'yes'
          AND (
            TRIM(IFNULL(st.email, '')) <> ''
            OR TRIM(IFNULL(st.mobileno, '')) <> ''
          )";

    $st = $mysqli->prepare($sql);
    if (!$st) {
        return [];
    }
    $types = 'ii' . str_repeat('i', count($section_ids));
    $bind = array_merge([$session_id, $class_id], $section_ids);
    $st->bind_param($types, ...$bind);
    $st->execute();
    $res = $st->get_result();
    $out = [];
    $seen = [];
    while ($res && ($row = $res->fetch_assoc())) {
        $e = strtolower(trim((string) ($row['email'] ?? '')));
        $m = trim((string) ($row['mobileno'] ?? ''));
        $key = $e !== '' ? 'e:' . $e : 'id:' . (int) $row['id'];
        if (isset($seen[$key])) {
            continue;
        }
        $seen[$key] = true;
        $out[] = [
            'user_id' => (string) ((int) $row['id']),
            'email' => trim((string) ($row['email'] ?? '')),
            'mobileno' => $m,
            'role' => 'student',
        ];
    }
    $st->close();
    return $out;
}

/**
 * @return array<int, array{user_id:string,email:string,mobileno:string,role:string}>
 */
function comm_recipients_individual_emails(string $blob): array {
    $parts = preg_split('/[\s,;]+/', $blob, -1, PREG_SPLIT_NO_EMPTY);
    $out = [];
    $seen = [];
    foreach ($parts as $p) {
        $e = trim($p);
        if ($e === '' || !filter_var($e, FILTER_VALIDATE_EMAIL)) {
            continue;
        }
        $lk = strtolower($e);
        if (isset($seen[$lk])) {
            continue;
        }
        $seen[$lk] = true;
        $out[] = [
            'user_id' => '0',
            'email' => $e,
            'mobileno' => '',
            'role' => 'student',
        ];
    }
    return $out;
}

/**
 * @param array<int, array{user_id:string,email:string,mobileno:string,role:string}> $recipients
 */
function comm_try_send_mail_html(string $from, string $subject, string $html, array $recipients): array {
    $headers = "MIME-Version: 1.0\r\n"
        . "Content-type: text/html; charset=UTF-8\r\n"
        . 'From: ' . $from . "\r\n";
    $encSub = '=?UTF-8?B?' . base64_encode($subject) . '?=';
    $sent = 0;
    $failed = 0;
    foreach ($recipients as $r) {
        $to = trim((string) ($r['email'] ?? ''));
        if ($to === '') {
            continue;
        }
        if (@mail($to, $encSub, $html, $headers)) {
            $sent++;
        } else {
            $failed++;
        }
    }
    return ['sent' => $sent, 'failed' => $failed];
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

    $in = comm_read_json_body();
    $title = trim((string) ($in['title'] ?? ''));
    $messageRaw = (string) ($in['message'] ?? '');
    $send_mail = !empty($in['send_mail']);
    $send_sms = !empty($in['send_sms']);
    $audience = strtolower(trim((string) ($in['audience'] ?? '')));
    $is_schedule = !empty($in['is_schedule']);
    $schedule_dt = trim((string) ($in['schedule_date_time'] ?? ''));

    if ($title === '') {
        throw new Exception('title is required.');
    }
    if (!$send_mail && !$send_sms) {
        throw new Exception('Choose at least one of send_mail or send_sms.');
    }
    if ($is_schedule && $schedule_dt === '') {
        throw new Exception('schedule_date_time is required when scheduling a send.');
    }

    $send_to_raw = $in['send_to'] ?? ['student'];
    if (!is_array($send_to_raw)) {
        $send_to_raw = ['student'];
    }
    $send_to_json = json_encode(array_values($send_to_raw));

    $session_id = comm_session_id($mysqli);
    if ($session_id <= 0) {
        throw new Exception('Could not resolve school session.');
    }

    $recipients = [];
    $is_class = 0;
    $is_individual = 0;
    $is_group = 0;
    $class_id = (int) ($in['class_id'] ?? 0);
    $section_ids = isset($in['section_ids']) && is_array($in['section_ids']) ? $in['section_ids'] : [];

    if ($audience === 'class') {
        $is_class = 1;
        $recipients = comm_recipients_class_sections($mysqli, $session_id, $class_id, $section_ids);
        if (empty($recipients)) {
            throw new Exception('No recipients found for this class and sections (need student email or phone on file).');
        }
    } elseif ($audience === 'individual') {
        $is_individual = 1;
        $emails_blob = trim((string) ($in['individual_emails'] ?? ''));
        $recipients = comm_recipients_individual_emails($emails_blob);
        if (empty($recipients)) {
            throw new Exception('individual_emails must contain at least one valid email address.');
        }
    } else {
        throw new Exception('audience must be "class" or "individual".');
    }

    $user_list_json = json_encode($recipients, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    if ($user_list_json === false) {
        throw new Exception('Failed to encode user_list.');
    }

    $message_html = comm_ensure_html($messageRaw);
    $schedule_section_json = $is_class ? json_encode(array_values(array_map('intval', $section_ids))) : '';
    $schedule_class_val = $is_class ? $class_id : null;

    $template_id = trim((string) ($in['template_id'] ?? ''));
    $send_through = trim((string) ($in['send_through'] ?? 'mail'));
    if ($send_through === '') {
        $send_through = 'mail';
    }

    $mail_flag = $send_mail ? 1 : 0;
    $sms_flag = $send_sms ? 1 : 0;
    $sched_flag = $is_schedule ? 1 : 0;

    $group_list = '';

    $mail_attempt = ['sent' => 0, 'failed' => 0, 'skipped' => true];
    if ($send_mail && !$is_schedule) {
        $from = 'noreply@portal.gcsewithrosi.co.uk';
        $mail_attempt = comm_try_send_mail_html($from, $title, $message_html, $recipients);
        $mail_attempt['skipped'] = false;
    }

    $sent_val = 0;
    if (!$is_schedule && $send_mail && !$mail_attempt['skipped'] && $mail_attempt['sent'] > 0) {
        $sent_val = 1;
    }

    $sql = 'INSERT INTO messages (
            title, template_id, email_template_id, sms_template_id, send_through,
            message, send_mail, send_sms, is_group, is_individual, is_class, is_schedule,
            sent, schedule_date_time, group_list, user_list, send_to, schedule_class, schedule_section,
            created_at, updated_at
        ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,NOW(),NOW())';

    $st = $mysqli->prepare($sql);
    if (!$st) {
        throw new Exception('Prepare failed: ' . $mysqli->error);
    }

    $email_template_id = 0;
    $sms_template_id = 0;
    $schedule_class_bind = $schedule_class_val !== null ? $schedule_class_val : 0;
    $schedule_section_bind = $schedule_section_json !== null ? $schedule_section_json : '';

    $st->bind_param(
        'ssiissiiiiiiissssis',
        $title,
        $template_id,
        $email_template_id,
        $sms_template_id,
        $send_through,
        $message_html,
        $mail_flag,
        $sms_flag,
        $is_group,
        $is_individual,
        $is_class,
        $sched_flag,
        $sent_val,
        $schedule_dt,
        $group_list,
        $user_list_json,
        $send_to_json,
        $schedule_class_bind,
        $schedule_section_bind
    );

    if (!$st->execute()) {
        $err = $st->error;
        $st->close();
        throw new Exception('Insert failed: ' . $err);
    }
    $new_id = (int) $mysqli->insert_id;
    $st->close();
    $mysqli->close();

    $warnings = [];
    if ($send_sms) {
        $warnings[] = 'SMS is recorded on the message but outbound SMS is not sent from this API (configure gateway on web if needed).';
    }
    if ($send_mail && !$is_schedule && $mail_attempt['sent'] === 0) {
        $warnings[] = 'No email was accepted by the server mail() function; the message is still saved to the log.';
    }

    comm_send_out([
        'success' => true,
        'message_id' => $new_id,
        'recipient_count' => count($recipients),
        'mail_attempt' => $mail_attempt,
        'warnings' => $warnings,
    ]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    comm_send_out(['success' => false, 'error' => $e->getMessage()]);
}
