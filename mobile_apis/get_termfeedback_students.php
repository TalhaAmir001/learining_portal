<?php
/**
 * Term Feedback – load students for class/section + any saved feedback for the period.
 *
 * Mirrors admin/Termfeedback::load_students() and Termfeedback_model::get_students_with_feedback().
 *
 * POST JSON:
 *   {
 *     user_type:    "admin" | "teacher",
 *     staff_id?:    int,
 *     class_id:     int,
 *     section_id:   int,
 *     start_month:  "YYYY-MM",
 *     end_month:    "YYYY-MM"     // must be >= start_month
 *   }
 *
 * Response:
 *   {
 *     success: true,
 *     overall_class_performance: "excellent"|"good"|"mixed"|"needs_improvement"|"",
 *     students: [
 *       {
 *         student_id, admission_no, firstname, middlename, lastname, full_name, is_active,
 *         feedback: null | {
 *           id, participation_rating, behaviour_rating, classwork_rating,
 *           confidence_rating, homework_rating, remarks,
 *           overall_class_performance, teacher_staff_id, updated_at
 *         }
 *       }, ...
 *     ]
 *   }
 *
 * Note: the web `load_students` also enriches each row with exam/homework completion percentages
 * pulled from the heavy `Termreport_model`; that enrichment is *not* included here on purpose
 * (it would require porting ~80KB of CodeIgniter logic). The mobile UI works without those columns.
 */

require_once __DIR__ . '/tf_bootstrap.php';

$body = tf_read_json_body();
tf_require_api_secret($body);

$class_id    = isset($body['class_id'])    ? (int) $body['class_id']    : 0;
$section_id  = isset($body['section_id'])  ? (int) $body['section_id']  : 0;
$start_month = trim((string) ($body['start_month'] ?? ''));
$end_month   = trim((string) ($body['end_month']   ?? ''));

if ($class_id < 1 || $section_id < 1
    || !tf_is_valid_month($start_month)
    || !tf_is_valid_month($end_month)
    || $start_month > $end_month) {
    tf_json_out(['success' => false, 'error' => 'Invalid input']);
}

$mysqli = tf_mysqli_connect();
try {
    $caller = tf_resolve_caller($mysqli, $body);
    if (!tf_caller_allows_class_section($caller, $class_id, $section_id)) {
        tf_json_out(['success' => false, 'error' => 'Access denied']);
    }

    $session_id = (int) $caller['session_id'];
    if ($session_id < 1) {
        tf_json_out(['success' => false, 'error' => 'No active session configured.']);
    }

    // Active students enrolled in this class/section for the current session.
    $sql = "SELECT s.id AS student_id,
                   s.admission_no,
                   s.firstname,
                   s.middlename,
                   s.lastname,
                   s.is_active
            FROM student_session ss
            INNER JOIN students s ON s.id = ss.student_id
            WHERE ss.session_id = $session_id
              AND ss.class_id   = $class_id
              AND ss.section_id = $section_id
              AND s.is_active   = 'yes'
            ORDER BY s.firstname ASC";
    $res = $mysqli->query($sql);
    if (!$res) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }

    $students   = [];
    $student_ids = [];
    while ($row = $res->fetch_assoc()) {
        $sid = (int) $row['student_id'];
        $student_ids[] = $sid;
        $first  = (string) ($row['firstname']  ?? '');
        $middle = (string) ($row['middlename'] ?? '');
        $last   = (string) ($row['lastname']   ?? '');
        $full   = trim(implode(' ', array_filter([$first, $middle, $last], static function ($p) {
            return trim((string) $p) !== '';
        })));
        $students[$sid] = [
            'student_id'   => $sid,
            'admission_no' => (string) ($row['admission_no'] ?? ''),
            'firstname'    => $first,
            'middlename'   => $middle,
            'lastname'     => $last,
            'full_name'    => $full !== '' ? $full : ('#' . $sid),
            'is_active'    => (string) ($row['is_active'] ?? ''),
            'feedback'     => null,
        ];
    }

    $overall = '';

    if (!empty($student_ids)) {
        $start_esc = $mysqli->real_escape_string($start_month);
        $end_esc   = $mysqli->real_escape_string($end_month);
        $ids_csv   = implode(',', array_map('intval', $student_ids));

        $teacher_filter = '';
        if ($caller['role'] === 'teacher' && $caller['staff_id'] > 0) {
            $teacher_filter = ' AND teacher_staff_id = ' . (int) $caller['staff_id'];
        }

        $fb_sql = "SELECT id, student_id,
                          participation_rating, behaviour_rating, classwork_rating,
                          confidence_rating,    homework_rating,
                          remarks, overall_class_performance, teacher_staff_id, updated_at
                   FROM term_feedback
                   WHERE session_id         = $session_id
                     AND class_id           = $class_id
                     AND section_id         = $section_id
                     AND period_start_month = '$start_esc'
                     AND period_end_month   = '$end_esc'
                     AND student_id IN ($ids_csv)"
                . $teacher_filter;
        $fbRes = $mysqli->query($fb_sql);
        if ($fbRes) {
            while ($fr = $fbRes->fetch_assoc()) {
                $sid = (int) $fr['student_id'];
                if (!isset($students[$sid])) {
                    continue;
                }
                $students[$sid]['feedback'] = [
                    'id'                        => (int) $fr['id'],
                    'participation_rating'      => $fr['participation_rating'] !== null ? (int) $fr['participation_rating'] : null,
                    'behaviour_rating'          => $fr['behaviour_rating']     !== null ? (int) $fr['behaviour_rating']     : null,
                    'classwork_rating'          => $fr['classwork_rating']     !== null ? (int) $fr['classwork_rating']     : null,
                    'confidence_rating'         => $fr['confidence_rating']    !== null ? (int) $fr['confidence_rating']    : null,
                    'homework_rating'           => $fr['homework_rating']      !== null ? (int) $fr['homework_rating']      : null,
                    'remarks'                   => $fr['remarks'] !== null ? (string) $fr['remarks'] : '',
                    'overall_class_performance' => $fr['overall_class_performance'] !== null ? (string) $fr['overall_class_performance'] : '',
                    'teacher_staff_id'          => $fr['teacher_staff_id'] !== null ? (int) $fr['teacher_staff_id'] : null,
                    'updated_at'                => (string) ($fr['updated_at'] ?? ''),
                ];
                if ($overall === '' && !empty($fr['overall_class_performance'])) {
                    $overall = (string) $fr['overall_class_performance'];
                }
            }
        }
    }

    $mysqli->close();
    tf_json_out([
        'success'                   => true,
        'overall_class_performance' => $overall,
        'students'                  => array_values($students),
    ]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    tf_json_out(['success' => false, 'error' => $e->getMessage(), 'students' => []]);
}
