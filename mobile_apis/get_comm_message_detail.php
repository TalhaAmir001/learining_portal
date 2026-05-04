<?php
/**
 * Communicate — single message row (full body for detail screen).
 * GET: id (required).
 */

header('Content-Type: application/json; charset=utf-8');

function comm_send_json($data) {
    $json = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    if ($json === false) {
        echo json_encode(['success' => false, 'error' => 'Failed to encode', 'message' => null]);
    } else {
        echo $json;
    }
}

/**
 * Resolve messages.schedule_class / schedule_section (JSON ids) to display names (web: classes.class, sections.section).
 *
 * @return array{0: string, 1: string} [className, sectionNamesCsv]
 */
function comm_resolve_schedule_labels(mysqli $mysqli, $scheduleClass, $scheduleSectionRaw) {
    $className = '';
    $sectionNames = '';

    $cid = isset($scheduleClass) ? (int) $scheduleClass : 0;
    if ($cid > 0) {
        $st = $mysqli->prepare('SELECT `class` FROM classes WHERE id = ? LIMIT 1');
        if ($st) {
            $st->bind_param('i', $cid);
            $st->execute();
            $res = $st->get_result();
            if ($res && ($r = $res->fetch_assoc())) {
                $className = isset($r['class']) ? trim((string) $r['class']) : '';
            }
            $st->close();
        }
    }

    $secIds = [];
    $raw = is_string($scheduleSectionRaw) ? trim($scheduleSectionRaw) : '';
    if ($raw !== '' && strpos($raw, '[') === 0) {
        $decoded = json_decode($raw, true);
        if (is_array($decoded)) {
            foreach ($decoded as $sid) {
                $i = (int) $sid;
                if ($i > 0) {
                    $secIds[] = $i;
                }
            }
        }
    } elseif ($raw !== '') {
        foreach (explode(',', $raw) as $p) {
            $i = (int) trim($p);
            if ($i > 0) {
                $secIds[] = $i;
            }
        }
    }
    $secIds = array_values(array_unique($secIds));
    if (!empty($secIds)) {
        $in = implode(',', array_map('intval', $secIds));
        $qs = $mysqli->query(
            'SELECT `section` FROM sections WHERE id IN (' . $in . ') ORDER BY `section` ASC'
        );
        if ($qs) {
            $names = [];
            while ($r = $qs->fetch_assoc()) {
                $n = isset($r['section']) ? trim((string) $r['section']) : '';
                if ($n !== '') {
                    $names[] = $n;
                }
            }
            $sectionNames = implode(', ', $names);
        }
    }

    return [$className, $sectionNames];
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

    $id = isset($_REQUEST['id']) ? (int) $_REQUEST['id'] : 0;
    if ($id <= 0) {
        throw new Exception('Missing or invalid id.');
    }

    $sql = "SELECT id, title, template_id, email_template_id, sms_template_id, send_through,
            message, send_mail, send_sms, is_group, is_individual, is_class, is_schedule,
            sent, schedule_date_time, group_list, user_list, send_to, schedule_class,
            schedule_section, created_at, updated_at
        FROM messages WHERE id = " . $id . " LIMIT 1";

    $result = $mysqli->query($sql);
    if (!$result) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }
    if ($result->num_rows === 0) {
        $mysqli->close();
        comm_send_json(['success' => false, 'error' => 'Not found.', 'message' => null]);
        exit;
    }
    $row = $result->fetch_assoc();
    $labels = comm_resolve_schedule_labels(
        $mysqli,
        $row['schedule_class'] ?? null,
        $row['schedule_section'] ?? ''
    );
    $out = [
        'id' => (int) $row['id'],
        'title' => $row['title'] ?? '',
        'template_id' => $row['template_id'] ?? '',
        'send_through' => $row['send_through'] ?? '',
        'message' => $row['message'] ?? '',
        'send_mail' => $row['send_mail'] ?? '',
        'send_sms' => $row['send_sms'] ?? '',
        'is_group' => $row['is_group'] ?? '',
        'is_individual' => $row['is_individual'] ?? '',
        'is_class' => isset($row['is_class']) ? (int) $row['is_class'] : 0,
        'is_schedule' => isset($row['is_schedule']) ? (int) $row['is_schedule'] : 0,
        'sent' => isset($row['sent']) && $row['sent'] !== null ? (int) $row['sent'] : null,
        'schedule_date_time' => $row['schedule_date_time'] ?? '',
        'group_list' => $row['group_list'] ?? '',
        'user_list' => $row['user_list'] ?? '',
        'send_to' => $row['send_to'] ?? '',
        'schedule_class' => isset($row['schedule_class']) ? (int) $row['schedule_class'] : null,
        'schedule_section' => $row['schedule_section'] ?? '',
        'schedule_class_name' => $labels[0],
        'schedule_section_names' => $labels[1],
        'created_at' => $row['created_at'] ?? '',
        'updated_at' => $row['updated_at'] ?? '',
    ];
    $mysqli->close();
    comm_send_json(['success' => true, 'message' => $out]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    comm_send_json(['success' => false, 'error' => $e->getMessage(), 'message' => null]);
}
