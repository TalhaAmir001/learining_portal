<?php
/**
 * Attendance — save staff day attendance.
 * POST JSON: { "date": "YYYY-MM-DD", "rows": [ { "staff_id", "staff_attendance_type_id", "remark?", "in_time?", "out_time?" } ] }
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
    if (!at_valid_date($date) || count($rows) === 0) {
        throw new Exception('date and non-empty rows required.');
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
        $staffId = isset($r['staff_id']) ? (int) $r['staff_id'] : 0;
        $typeId = isset($r['staff_attendance_type_id']) ? (int) $r['staff_attendance_type_id'] : 0;
        if ($staffId <= 0 || $typeId <= 0) {
            throw new Exception('Each row needs staff_id and staff_attendance_type_id.');
        }
        $remark = isset($r['remark']) ? (string) $r['remark'] : '';
        $inT = at_norm_time($r['in_time'] ?? null);
        $outT = at_norm_time($r['out_time'] ?? null);

        $stmt = $mysqli->prepare('SELECT id FROM staff_attendance WHERE staff_id = ? AND date = ? LIMIT 1');
        $stmt->bind_param('is', $staffId, $date);
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
                    'UPDATE staff_attendance SET staff_attendance_type_id=?, remark=?, in_time=NULL, out_time=NULL, updated_at=? WHERE id=?'
                );
                $q->bind_param('issi', $typeId, $remark, $date, $existingId);
            } else {
                $q = $mysqli->prepare(
                    'UPDATE staff_attendance SET staff_attendance_type_id=?, remark=?, in_time=?, out_time=?, updated_at=? WHERE id=?'
                );
                $q->bind_param('issssi', $typeId, $remark, $inT, $outT, $date, $existingId);
            }
            if (!$q->execute()) {
                throw new Exception('Update failed: ' . $q->error);
            }
            $q->close();
        } else {
            if ($inT === null && $outT === null) {
                $q = $mysqli->prepare(
                    'INSERT INTO staff_attendance (staff_id, staff_attendance_type_id, remark, in_time, out_time, date, updated_at)
                     VALUES (?, ?, ?, NULL, NULL, ?, ?)'
                );
                $q->bind_param('iisss', $staffId, $typeId, $remark, $date, $date);
            } else {
                $q = $mysqli->prepare(
                    'INSERT INTO staff_attendance (staff_id, staff_attendance_type_id, remark, in_time, out_time, date, updated_at)
                     VALUES (?, ?, ?, ?, ?, ?, ?)'
                );
                $q->bind_param('iisssss', $staffId, $typeId, $remark, $inT, $outT, $date, $date);
            }
            if (!$q->execute()) {
                throw new Exception('Insert failed: ' . $q->error);
            }
            $q->close();
        }
    }

    $mysqli->commit();
    $mysqli->close();
    at_json_out(['success' => true, 'message' => 'Staff attendance saved successfully.']);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->rollback();
        $mysqli->close();
    }
    at_json_out(['success' => false, 'error' => $e->getMessage()]);
}
