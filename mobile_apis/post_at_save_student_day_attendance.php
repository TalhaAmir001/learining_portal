<?php
/**
 * Attendance — save student day attendance (upsert per student_session + date).
 * POST JSON: { "date": "YYYY-MM-DD", "rows": [ { "student_session_id", "attendence_type_id", "remark?", "feedback?", "in_time?", "out_time?" } ] }
 * Mirrors Stuattendence_model::addorUpdate (single daily row per student_session).
 */

header('Content-Type: application/json; charset=utf-8');

function at_json_out($data) {
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
}

function at_valid_date($d) {
    if (!is_string($d) || !preg_match('/^\d{4}-\d{2}-\d{2}$/', $d)) {
        return false;
    }
    $p = explode('-', $d);
    return checkdate((int) $p[1], (int) $p[2], (int) $p[0]);
}

function at_norm_time($t) {
    if ($t === null || $t === '') {
        return null;
    }
    $s = trim((string) $t);
    if ($s === '') {
        return null;
    }
    $ts = strtotime($s);
    if ($ts === false) {
        return null;
    }
    return date('H:i:s', $ts);
}

$mysqli = null;
try {
    $raw = file_get_contents('php://input');
    $body = json_decode($raw, true);
    if (!is_array($body)) {
        throw new Exception('Invalid JSON body.');
    }
    $date = isset($body['date']) ? trim((string) $body['date']) : '';
    $rows = isset($body['rows']) && is_array($body['rows']) ? $body['rows'] : [];
    if (!at_valid_date($date)) {
        throw new Exception('Valid date (YYYY-MM-DD) required.');
    }
    if (count($rows) === 0) {
        throw new Exception('rows array required.');
    }

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

    $mysqli->begin_transaction();

    foreach ($rows as $r) {
        if (!is_array($r)) {
            continue;
        }
        $ssid = isset($r['student_session_id']) ? (int) $r['student_session_id'] : 0;
        $typeId = isset($r['attendence_type_id']) ? (int) $r['attendence_type_id'] : 0;
        if ($ssid <= 0 || $typeId <= 0) {
            throw new Exception('Each row needs student_session_id and attendence_type_id.');
        }
        $remark = isset($r['remark']) ? (string) $r['remark'] : '';
        $feedback = isset($r['feedback']) ? (string) $r['feedback'] : '';
        $inT = at_norm_time($r['in_time'] ?? null);
        $outT = at_norm_time($r['out_time'] ?? null);

        // Align with web: absent (4) / holiday (5) have no in/out times
        if ($typeId === 4 || $typeId === 5) {
            $inT = null;
            $outT = null;
        }

        $stmt = $mysqli->prepare(
            'SELECT id FROM student_attendences WHERE student_session_id = ? AND date = ? LIMIT 1'
        );
        $stmt->bind_param('is', $ssid, $date);
        $stmt->execute();
        $ex = $stmt->get_result();
        $existingId = 0;
        if ($ex && $row = $ex->fetch_assoc()) {
            $existingId = (int) $row['id'];
        }
        $stmt->close();

        if ($existingId > 0) {
            if ($inT === null && $outT === null) {
                $q = $mysqli->prepare(
                    'UPDATE student_attendences SET attendence_type_id=?, remark=?, feedback=?, in_time=NULL, out_time=NULL WHERE id=?'
                );
                $q->bind_param('issi', $typeId, $remark, $feedback, $existingId);
            } else {
                $q = $mysqli->prepare(
                    'UPDATE student_attendences SET attendence_type_id=?, remark=?, feedback=?, in_time=?, out_time=? WHERE id=?'
                );
                $q->bind_param('issssi', $typeId, $remark, $feedback, $inT, $outT, $existingId);
            }
            if (!$q->execute()) {
                throw new Exception('Update failed: ' . $q->error);
            }
            $q->close();
        } else {
            if ($inT === null && $outT === null) {
                $q = $mysqli->prepare(
                    'INSERT INTO student_attendences (student_session_id, attendence_type_id, remark, feedback, in_time, out_time, date)
                     VALUES (?, ?, ?, ?, NULL, NULL, ?)'
                );
                $q->bind_param('iisss', $ssid, $typeId, $remark, $feedback, $date);
            } else {
                $q = $mysqli->prepare(
                    'INSERT INTO student_attendences (student_session_id, attendence_type_id, remark, feedback, in_time, out_time, date)
                     VALUES (?, ?, ?, ?, ?, ?, ?)'
                );
                $q->bind_param('iisssss', $ssid, $typeId, $remark, $feedback, $inT, $outT, $date);
            }
            if (!$q->execute()) {
                throw new Exception('Insert failed: ' . $q->error);
            }
            $q->close();
        }
    }

    $mysqli->commit();
    $mysqli->close();
    at_json_out(['success' => true, 'message' => 'Attendance saved successfully.']);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->rollback();
        $mysqli->close();
    }
    at_json_out(['success' => false, 'error' => $e->getMessage()]);
}
