<?php
/**
 * Term Feedback – bulk save (insert or update) for a class/section/period.
 *
 * Mirrors admin/Termfeedback::save() and Termfeedback_model::upsert_bulk().
 *
 * POST JSON:
 *   {
 *     user_type:   "admin" | "teacher",
 *     staff_id?:   int,        // required for teacher; sets teacher_staff_id on the row
 *     class_id:    int,
 *     section_id:  int,
 *     start_month: "YYYY-MM",
 *     end_month:   "YYYY-MM",
 *     overall_class_performance: "excellent"|"good"|"mixed"|"needs_improvement"|"",
 *     items: [
 *       {
 *         student_id: int,
 *         participation_rating: 1-5|null,
 *         behaviour_rating:     1-5|null,
 *         classwork_rating:     1-5|null,
 *         confidence_rating:    1-5|null,
 *         homework_rating:      1-5|null,
 *         remarks:              string
 *       }, ...
 *     ]
 *   }
 *
 * Response: { success: true, saved: <int> } or { success: false, error: ... }.
 */

require_once __DIR__ . '/tf_bootstrap.php';

$body = tf_read_json_body();
tf_require_api_secret($body);

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    tf_json_out(['success' => false, 'error' => 'Method not allowed']);
}

$class_id    = isset($body['class_id'])    ? (int) $body['class_id']    : 0;
$section_id  = isset($body['section_id'])  ? (int) $body['section_id']  : 0;
$start_month = trim((string) ($body['start_month'] ?? ''));
$end_month   = trim((string) ($body['end_month']   ?? ''));
$items_raw   = $body['items'] ?? [];

if (is_string($items_raw)) {
    $decoded = json_decode($items_raw, true);
    $items_raw = is_array($decoded) ? $decoded : [];
}
if (!is_array($items_raw)) {
    $items_raw = [];
}

if ($class_id < 1 || $section_id < 1
    || !tf_is_valid_month($start_month)
    || !tf_is_valid_month($end_month)
    || $start_month > $end_month) {
    tf_json_out(['success' => false, 'error' => 'Invalid input']);
}

$overall = trim((string) ($body['overall_class_performance'] ?? ''));
if (!in_array($overall, ['excellent', 'good', 'mixed', 'needs_improvement'], true)) {
    $overall = null;
}

$mysqli = tf_mysqli_connect();
try {
    $caller = tf_resolve_caller($mysqli, $body);
    if (!$caller['can_save']) {
        tf_json_out(['success' => false, 'error' => 'You do not have permission to save term feedback.']);
    }
    if (!tf_caller_allows_class_section($caller, $class_id, $section_id)) {
        tf_json_out(['success' => false, 'error' => 'Access denied']);
    }

    $session_id = (int) $caller['session_id'];
    if ($session_id < 1) {
        tf_json_out(['success' => false, 'error' => 'No active session configured.']);
    }

    // For teachers, teacher_staff_id is mandatory and identifies the row owner.
    // Admins may save without a teacher_staff_id (matches the web behaviour: $teacher_staff_id = userData['id'] for admin too).
    $teacher_staff_id = $caller['staff_id'] > 0 ? (int) $caller['staff_id'] : null;

    $now           = date('Y-m-d H:i:s');
    $start_esc     = $mysqli->real_escape_string($start_month);
    $end_esc       = $mysqli->real_escape_string($end_month);
    $overall_sql   = $overall !== null ? "'" . $mysqli->real_escape_string($overall) . "'" : 'NULL';
    $tsid_sql      = $teacher_staff_id !== null ? (int) $teacher_staff_id : 'NULL';

    $clip_rating = static function ($v) {
        if ($v === null || $v === '' || !is_numeric($v)) {
            return null;
        }
        $n = (int) $v;
        if ($n < 1 || $n > 5) {
            return null;
        }
        return $n;
    };

    $mysqli->begin_transaction();
    $saved = 0;
    foreach ($items_raw as $r) {
        if (!is_array($r)) {
            continue;
        }
        $student_id = isset($r['student_id']) ? (int) $r['student_id'] : 0;
        if ($student_id < 1) {
            continue;
        }

        $p  = $clip_rating($r['participation_rating'] ?? null);
        $b  = $clip_rating($r['behaviour_rating']     ?? null);
        $cw = $clip_rating($r['classwork_rating']     ?? null);
        $cf = $clip_rating($r['confidence_rating']    ?? null);
        $hw = $clip_rating($r['homework_rating']      ?? null);
        $remarks = isset($r['remarks']) ? (string) $r['remarks'] : '';

        $p_sql       = $p  !== null ? (int) $p  : 'NULL';
        $b_sql       = $b  !== null ? (int) $b  : 'NULL';
        $cw_sql      = $cw !== null ? (int) $cw : 'NULL';
        $cf_sql      = $cf !== null ? (int) $cf : 'NULL';
        $hw_sql      = $hw !== null ? (int) $hw : 'NULL';
        $remarks_sql = "'" . $mysqli->real_escape_string($remarks) . "'";

        // Match upsert_bulk: row identity is (session_id, student_id, period_start_month, period_end_month).
        $find = $mysqli->query(
            "SELECT id FROM term_feedback
             WHERE session_id         = $session_id
               AND student_id         = $student_id
               AND period_start_month = '$start_esc'
               AND period_end_month   = '$end_esc'
             LIMIT 1"
        );
        $existing_id = 0;
        if ($find && ($existRow = $find->fetch_assoc())) {
            $existing_id = (int) $existRow['id'];
        }

        if ($existing_id > 0) {
            $ok = $mysqli->query(
                "UPDATE term_feedback SET
                    class_id                  = $class_id,
                    section_id                = $section_id,
                    participation_rating      = $p_sql,
                    behaviour_rating          = $b_sql,
                    classwork_rating          = $cw_sql,
                    confidence_rating         = $cf_sql,
                    homework_rating           = $hw_sql,
                    remarks                   = $remarks_sql,
                    overall_class_performance = $overall_sql,
                    teacher_staff_id          = $tsid_sql,
                    updated_at                = '$now'
                 WHERE id = $existing_id"
            );
        } else {
            $ok = $mysqli->query(
                "INSERT INTO term_feedback
                    (session_id, class_id, section_id, student_id,
                     period_start_month, period_end_month,
                     participation_rating, behaviour_rating, classwork_rating,
                     confidence_rating, homework_rating,
                     remarks, overall_class_performance, teacher_staff_id,
                     created_at, updated_at)
                 VALUES
                    ($session_id, $class_id, $section_id, $student_id,
                     '$start_esc', '$end_esc',
                     $p_sql, $b_sql, $cw_sql,
                     $cf_sql, $hw_sql,
                     $remarks_sql, $overall_sql, $tsid_sql,
                     '$now', '$now')"
            );
        }
        if (!$ok) {
            throw new Exception('Save failed: ' . $mysqli->error);
        }
        $saved++;
    }
    $mysqli->commit();
    $mysqli->close();
    tf_json_out(['success' => true, 'saved' => $saved]);
} catch (Exception $e) {
    if ($mysqli) {
        @$mysqli->rollback();
        $mysqli->close();
    }
    tf_json_out(['success' => false, 'error' => $e->getMessage()]);
}
