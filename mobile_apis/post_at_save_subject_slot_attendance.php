<?php
/**
 * Attendance — save subject period attendance (upsert per student_session + subject_timetable + date).
 * POST JSON: { "subject_timetable_id": int, "date": "YYYY-MM-DD", "rows": [ { "student_session_id", "attendence_type_id", "remark?" } ] }
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

$mysqli = null;
try {
    $raw = file_get_contents('php://input');
    $body = json_decode($raw, true);
    if (!is_array($body)) {
        throw new Exception('Invalid JSON body.');
    }
    $date = isset($body['date']) ? trim((string) $body['date']) : '';
    $stid = isset($body['subject_timetable_id']) ? (int) $body['subject_timetable_id'] : 0;
    $rows = isset($body['rows']) && is_array($body['rows']) ? $body['rows'] : [];
    if (!at_valid_date($date) || $stid <= 0 || count($rows) === 0) {
        throw new Exception('date, subject_timetable_id, and non-empty rows required.');
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

        $stmt = $mysqli->prepare(
            'SELECT id FROM student_subject_attendances
             WHERE student_session_id = ? AND subject_timetable_id = ? AND date = ? LIMIT 1'
        );
        $stmt->bind_param('iis', $ssid, $stid, $date);
        $stmt->execute();
        $ex = $stmt->get_result();
        $existingId = 0;
        if ($ex && $row = $ex->fetch_assoc()) {
            $existingId = (int) $row['id'];
        }
        $stmt->close();

        if ($existingId > 0) {
            $q = $mysqli->prepare(
                'UPDATE student_subject_attendances SET attendence_type_id=?, remark=? WHERE id=?'
            );
            $q->bind_param('isi', $typeId, $remark, $existingId);
            if (!$q->execute()) {
                throw new Exception('Update failed: ' . $q->error);
            }
            $q->close();
        } else {
            $q = $mysqli->prepare(
                'INSERT INTO student_subject_attendances (student_session_id, attendence_type_id, remark, subject_timetable_id, date)
                 VALUES (?, ?, ?, ?, ?)'
            );
            $q->bind_param('iisis', $ssid, $typeId, $remark, $stid, $date);
            if (!$q->execute()) {
                throw new Exception('Insert failed: ' . $q->error);
            }
            $q->close();
        }
    }

    $mysqli->commit();
    $mysqli->close();
    at_json_out(['success' => true, 'message' => 'Subject attendance saved successfully.']);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->rollback();
        $mysqli->close();
    }
    at_json_out(['success' => false, 'error' => $e->getMessage()]);
}
