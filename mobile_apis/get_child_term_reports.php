<?php
/**
 * Parent-facing read of `term_feedback` for one of their linked children.
 *
 * The web Termfeedback feature lets staff record per-student ratings +
 * remarks for a month range. This endpoint is the *parent* view of the same
 * data: for the active child (or any child the parent is linked to), list
 * every saved term-feedback row in the current session, joined with class,
 * section and the saving teacher's name.
 *
 * Auth model: same as the rest of parent_link/* — the caller authenticates
 * as the app_parent (caller_user_type='app_parent' + caller_user_id=
 * app_parents.id), and the server then enforces the (parent_id, student_id)
 * link exists in `app_parent_students` before returning anything.
 *
 * POST/GET (JSON or form):
 *   caller_user_type : 'app_parent'   (or legacy 'guardian' / 'parent')
 *   caller_user_id   : app_parents.id (or users.id for the legacy bridge)
 *   student_id       : int            — the child whose reports we want
 *   api_secret?      : when PL_API_SECRET is configured
 *
 * Response shape:
 *   {
 *     success: true,
 *     child:   { student_id, firstname, middlename, lastname, admission_no,
 *                class_name, section_name },
 *     reports: [
 *       {
 *         id, period_start_month, period_end_month,
 *         participation_rating, behaviour_rating, classwork_rating,
 *         confidence_rating, homework_rating,
 *         remarks, overall_class_performance,
 *         teacher_name, updated_at
 *       }, …
 *     ]
 *   }
 *
 * Errors return { success: false, error: "..." }.
 */

require_once __DIR__ . '/pl_bootstrap.php';

$mysqli = pl_mysqli_connect();

try {
    $body = pl_read_json_body();
    pl_require_api_secret($body);

    $student_id = isset($body['student_id']) ? (int) $body['student_id'] : 0;
    if ($student_id < 1) {
        pl_json_out([
            'success' => false,
            'error'   => 'Missing or invalid student_id.',
        ]);
    }

    // Authenticates and returns the app_parents row. Terminates request on
    // failure with a clean JSON error, so no extra defensive code here.
    $parent    = pl_resolve_app_parent($mysqli, $body);
    $parent_id = (int) $parent['id'];

    // ── Verify the parent is actually linked to this child ───────────────
    $check = $mysqli->query(
        "SELECT 1 FROM app_parent_students
         WHERE parent_id = $parent_id AND student_id = $student_id
         LIMIT 1"
    );
    $is_linked = ($check && $check->num_rows > 0);
    if ($check) {
        $check->free();
    }
    if (!$is_linked) {
        $mysqli->close();
        pl_json_out([
            'success' => false,
            'error'   => 'This child is not linked to your account.',
        ]);
    }

    $session_id = pl_current_session_id($mysqli);
    if ($session_id < 1) {
        $mysqli->close();
        pl_json_out([
            'success' => false,
            'error'   => 'No active session configured.',
        ]);
    }

    // ── Child header (name + class + section for the current session) ────
    $hdr_sql = "SELECT
                    st.id           AS student_id,
                    st.firstname,
                    st.middlename,
                    st.lastname,
                    st.admission_no,
                    IFNULL(c.class,    '') AS class_name,
                    IFNULL(sec.section,'') AS section_name
                FROM students st
                LEFT JOIN student_session ss
                       ON ss.student_id = st.id AND ss.session_id = $session_id
                LEFT JOIN classes  c   ON c.id   = ss.class_id
                LEFT JOIN sections sec ON sec.id = ss.section_id
                WHERE st.id = $student_id
                LIMIT 1";
    $hdr_res = $mysqli->query($hdr_sql);
    if (!$hdr_res || $hdr_res->num_rows === 0) {
        if ($hdr_res) {
            $hdr_res->free();
        }
        $mysqli->close();
        pl_json_out([
            'success' => false,
            'error'   => 'Child profile not found.',
        ]);
    }
    $hdr_row = $hdr_res->fetch_assoc();
    $hdr_res->free();

    $child = [
        'student_id'   => (int) $hdr_row['student_id'],
        'firstname'    => (string) ($hdr_row['firstname']    ?? ''),
        'middlename'   => (string) ($hdr_row['middlename']   ?? ''),
        'lastname'     => (string) ($hdr_row['lastname']     ?? ''),
        'admission_no' => (string) ($hdr_row['admission_no'] ?? ''),
        'class_name'   => (string) ($hdr_row['class_name']   ?? ''),
        'section_name' => (string) ($hdr_row['section_name'] ?? ''),
    ];

    // ── All term_feedback rows for this child in the current session ─────
    //
    // Joining class/section per row (not just per-child) handles the edge
    // case of a student being promoted mid-session: each report is shown
    // against the class/section it was filed under, not today's.
    $rep_sql = "SELECT
                    tf.id,
                    tf.period_start_month,
                    tf.period_end_month,
                    tf.participation_rating,
                    tf.behaviour_rating,
                    tf.classwork_rating,
                    tf.confidence_rating,
                    tf.homework_rating,
                    tf.remarks,
                    tf.overall_class_performance,
                    tf.updated_at,
                    IFNULL(c.class,    '') AS class_name,
                    IFNULL(sec.section,'') AS section_name,
                    TRIM(CONCAT_WS(' ', st_staff.name, st_staff.surname)) AS teacher_name
                FROM term_feedback tf
                LEFT JOIN classes  c        ON c.id        = tf.class_id
                LEFT JOIN sections sec      ON sec.id      = tf.section_id
                LEFT JOIN staff    st_staff ON st_staff.id = tf.teacher_staff_id
                WHERE tf.session_id = $session_id
                  AND tf.student_id = $student_id
                ORDER BY tf.period_end_month DESC,
                         tf.period_start_month DESC,
                         tf.updated_at DESC";
    $rep_res = $mysqli->query($rep_sql);
    if (!$rep_res) {
        throw new Exception('Reports query failed: ' . $mysqli->error);
    }

    $reports = [];
    while ($r = $rep_res->fetch_assoc()) {
        $reports[] = [
            'id'                        => (int) $r['id'],
            'period_start_month'        => (string) ($r['period_start_month'] ?? ''),
            'period_end_month'          => (string) ($r['period_end_month']   ?? ''),
            'participation_rating'      => $r['participation_rating'] !== null ? (int) $r['participation_rating'] : null,
            'behaviour_rating'          => $r['behaviour_rating']     !== null ? (int) $r['behaviour_rating']     : null,
            'classwork_rating'          => $r['classwork_rating']     !== null ? (int) $r['classwork_rating']     : null,
            'confidence_rating'         => $r['confidence_rating']    !== null ? (int) $r['confidence_rating']    : null,
            'homework_rating'           => $r['homework_rating']      !== null ? (int) $r['homework_rating']      : null,
            'remarks'                   => (string) ($r['remarks'] ?? ''),
            'overall_class_performance' => (string) ($r['overall_class_performance'] ?? ''),
            'class_name'                => (string) ($r['class_name']   ?? ''),
            'section_name'              => (string) ($r['section_name'] ?? ''),
            'teacher_name'              => (string) ($r['teacher_name'] ?? ''),
            'updated_at'                => (string) ($r['updated_at']   ?? ''),
        ];
    }
    $rep_res->free();

    $mysqli->close();
    pl_json_out([
        'success' => true,
        'child'   => $child,
        'reports' => $reports,
    ]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    pl_json_out([
        'success' => false,
        'error'   => $e->getMessage(),
        'child'   => null,
        'reports' => [],
    ]);
}
