<?php
/**
 * Stream the PDF bytes of a published term-report row for one of the
 * calling parent's linked children.
 *
 * This is the parent-facing analogue of the web's
 * `application/controllers/user/Termreport.php::view($term_number)` — the
 * goal is to let the mobile app fetch the PDF (and render it inline in an
 * embedded viewer) without ever serving an "attachment" content-disposition,
 * so the PDF can be *read* but is not *downloaded* by default. The web
 * exposes a separate `download` route guarded by `download_allowed`; we
 * match that with the optional `mode=download` query when needed.
 *
 * Request (POST JSON or POST form or GET with query):
 *   caller_user_type : 'app_parent'   (or legacy 'guardian' / 'parent')
 *   caller_user_id   : app_parents.id (or users.id for the legacy bridge)
 *   student_id       : int
 *   report_id        : int — `student_term_reports.id`
 *   mode?            : 'inline' (default) | 'download'   (controls header)
 *   api_secret?      : when PL_API_SECRET is configured
 *
 * Response:
 *   On success → raw PDF bytes with
 *     Content-Type: application/pdf
 *     Content-Disposition: inline; filename="…"            (default)
 *                       or attachment; filename="…"        (mode=download)
 *   On any error → JSON { success:false, error:"…" } via pl_json_out().
 *
 * Auth rules:
 *   • Parent must be linked to the student (`app_parent_students`).
 *   • Report must belong to the same student (`student_term_reports.student_id`).
 *   • Report must be `status='published'`.
 *   • For mode=download: report's `download_allowed` flag must be 1, matching
 *     the web's behaviour. Otherwise we 403-style with a JSON error and the
 *     client falls back to inline view.
 */

require_once __DIR__ . '/pl_bootstrap.php';

$mysqli = pl_mysqli_connect();

try {
    // Accept JSON body, form-encoded body, or GET query parameters.
    $body = pl_read_json_body();
    if (empty($body) && !empty($_GET)) {
        $body = $_GET;
    }
    pl_require_api_secret($body);

    $student_id = isset($body['student_id']) ? (int) $body['student_id'] : 0;
    $report_id  = isset($body['report_id'])  ? (int) $body['report_id']  : 0;
    $mode       = isset($body['mode']) ? strtolower(trim((string) $body['mode'])) : 'inline';
    if ($mode !== 'download') {
        $mode = 'inline';
    }
    if ($student_id < 1 || $report_id < 1) {
        pl_json_out([
            'success' => false,
            'error'   => 'Missing or invalid student_id / report_id.',
        ]);
    }

    // Resolve the caller's app_parents row. Helper terminates on auth failure.
    $parent    = pl_resolve_app_parent($mysqli, $body);
    $parent_id = (int) $parent['id'];

    // Link check (parent ↔ child).
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

    $has_download_col = pl_table_has_column($mysqli, 'student_term_reports', 'download_allowed');
    $download_select  = $has_download_col ? ', str.download_allowed' : ', 0 AS download_allowed';

    // Fetch the report row & verify ownership / status.
    $row_q = $mysqli->query(
        "SELECT str.id, str.session_id, str.student_id, str.term_number,
                str.status, str.pdf_path $download_select
         FROM student_term_reports str
         WHERE str.id = $report_id
         LIMIT 1"
    );
    if (!$row_q || $row_q->num_rows === 0) {
        if ($row_q) {
            $row_q->free();
        }
        $mysqli->close();
        pl_json_out([
            'success' => false,
            'error'   => 'Report not found.',
        ]);
    }
    $row = $row_q->fetch_assoc();
    $row_q->free();

    if ((int) ($row['student_id'] ?? 0) !== $student_id) {
        $mysqli->close();
        pl_json_out([
            'success' => false,
            'error'   => 'This report does not belong to the selected child.',
        ]);
    }
    if ((int) ($row['session_id'] ?? 0) !== $session_id) {
        $mysqli->close();
        pl_json_out([
            'success' => false,
            'error'   => 'This report is from a different session.',
        ]);
    }
    if (strtolower((string) ($row['status'] ?? '')) !== 'published') {
        $mysqli->close();
        pl_json_out([
            'success' => false,
            'error'   => 'This report has not been published yet.',
        ]);
    }

    if ($mode === 'download' && (int) ($row['download_allowed'] ?? 0) !== 1) {
        $mysqli->close();
        pl_json_out([
            'success' => false,
            'error'   => 'Downloading is not currently enabled for this report.',
        ]);
    }

    // Resolve PDF file path. `pdf_path` is stored relative to the web app's
    // FCPATH (e.g. "uploads/student_term_reports/<sess>/term1_student_45.pdf").
    // Mobile API lives at <web-root>/mobile_apis/, so go up one to reach the
    // same root the web controller uses (FCPATH equivalent).
    $rel_path = trim((string) ($row['pdf_path'] ?? ''));
    if ($rel_path === '') {
        $mysqli->close();
        pl_json_out([
            'success' => false,
            'error'   => 'No PDF is associated with this report.',
        ]);
    }
    // Defence-in-depth: stop directory traversal even though the column is
    // staff-managed and trusted in practice.
    if (strpos($rel_path, '..') !== false) {
        $mysqli->close();
        pl_json_out([
            'success' => false,
            'error'   => 'Invalid PDF path.',
        ]);
    }

    $web_root = realpath(__DIR__ . '/..');
    if ($web_root === false) {
        $mysqli->close();
        pl_json_out([
            'success' => false,
            'error'   => 'Server misconfiguration: web root not resolvable.',
        ]);
    }
    $full = $web_root . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $rel_path);
    if (!is_file($full)) {
        $mysqli->close();
        pl_json_out([
            'success' => false,
            'error'   => 'PDF file is missing on the server.',
        ]);
    }

    $term     = (int) ($row['term_number'] ?? 0);
    $filename = 'term_report_term' . max(1, $term) . '_student' . $student_id . '.pdf';
    $disp     = $mode === 'download' ? 'attachment' : 'inline';

    $mysqli->close();

    // From here on we're writing the binary body — pl_json_out() must NOT be
    // called below.
    header('Content-Type: application/pdf');
    header('Content-Disposition: ' . $disp . '; filename="' . $filename . '"');
    header('Content-Length: ' . filesize($full));
    header('Cache-Control: private, no-store, no-cache, must-revalidate, max-age=0');
    header('Pragma: no-cache');
    readfile($full);
    exit;
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    pl_json_out([
        'success' => false,
        'error'   => $e->getMessage(),
    ]);
}
