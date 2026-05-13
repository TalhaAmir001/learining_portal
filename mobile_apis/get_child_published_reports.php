<?php
/**
 * Parent-facing read of the school's *published* term-report PDFs for one of
 * their linked children.
 *
 * The web Termreport feature lets staff generate per-term PDFs (Term 1 / 2 /
 * 3) per student and then publish them. Once published, parents/students can
 * view them inline. This endpoint is the mobile-app equivalent of the web's
 * `user/termreport/index` listing — for the active child (or any child the
 * parent is linked to), return every published `student_term_reports` row in
 * the current session.
 *
 * Auth model (same as the rest of `parent_link/*`):
 *   • caller_user_type='app_parent' + caller_user_id=app_parents.id, OR
 *   • legacy guardian-via-users bridge (caller_user_type='guardian'+users.id).
 * The server then enforces the (parent_id, student_id) link exists in
 * `app_parent_students` before returning anything.
 *
 * POST/GET (JSON or form):
 *   caller_user_type : 'app_parent' (or legacy 'guardian' / 'parent')
 *   caller_user_id   : app_parents.id (or users.id for the legacy bridge)
 *   student_id       : int — the child whose PDFs we want
 *   api_secret?      : when PL_API_SECRET is configured
 *
 * Response shape:
 *   {
 *     success: true,
 *     child:   { student_id, firstname, middlename, lastname, admission_no,
 *                class_name, section_name },
 *     reports: [
 *       {
 *         id, term_number,                          // 1..3
 *         period_start_month, period_end_month,    // 'YYYY-MM'
 *         status, published_at, download_allowed
 *       }, …
 *     ]
 *   }
 *
 * Errors return { success: false, error: "..." }.
 *
 * NOTE: only `status='published'` rows are returned — drafts are admin-only.
 * Use `view_term_report_pdf.php` (sibling endpoint) to stream the PDF bytes
 * for a specific `report_id`.
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

    // `download_allowed` was added later by the web's ensure_schema(); the
    // mobile call may run before the staff side has been touched in this DB
    // — so SELECT defensively. Defaults to 0 (= view-only) when the column
    // is missing, which matches the web's fail-safe behaviour.
    $has_download_col = pl_table_has_column($mysqli, 'student_term_reports', 'download_allowed');
    $download_select  = $has_download_col ? 'str.download_allowed' : '0 AS download_allowed';

    $rep_sql = "SELECT
                    str.id,
                    str.term_number,
                    str.period_start_month,
                    str.period_end_month,
                    str.status,
                    str.published_at,
                    $download_select
                FROM student_term_reports str
                WHERE str.session_id = $session_id
                  AND str.student_id = $student_id
                  AND str.status     = 'published'
                ORDER BY str.term_number ASC,
                         str.published_at DESC";
    $rep_res = $mysqli->query($rep_sql);
    if (!$rep_res) {
        throw new Exception('Reports query failed: ' . $mysqli->error);
    }

    $reports = [];
    while ($r = $rep_res->fetch_assoc()) {
        $reports[] = [
            'id'                 => (int) $r['id'],
            'term_number'        => (int) ($r['term_number'] ?? 0),
            'period_start_month' => (string) ($r['period_start_month'] ?? ''),
            'period_end_month'   => (string) ($r['period_end_month']   ?? ''),
            'status'             => (string) ($r['status'] ?? ''),
            'published_at'       => (string) ($r['published_at'] ?? ''),
            'download_allowed'   => (int) ($r['download_allowed'] ?? 0) === 1,
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
