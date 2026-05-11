<?php
/**
 * Smart Monitoring – fetch a single student's snapshot for the chosen period
 * (Super Admin only). Used by the per-student visual report screen.
 *
 * POST JSON:
 *   {
 *     api_secret?:    string,
 *     caller_staff_id: int,
 *     student_id:     int,
 *     date_from?:     "YYYY-MM-DD", // default last-30-days
 *     date_to?:       "YYYY-MM-DD"  // default today
 *   }
 *
 * Response:
 *   {
 *     success:   bool,
 *     table_ok:  bool,
 *     period:    { from, to },
 *     snapshot?: <row|null>,   // null when no snapshot yet for that period
 *     error?
 *   }
 *
 * Mirrors Monitoring_model::get_admin_snapshot_for_student().
 */

require_once __DIR__ . '/sm_bootstrap.php';

$body = sm_read_json_body();
sm_require_api_secret($body);

$student_id = isset($body['student_id']) ? (int) $body['student_id'] : 0;
if ($student_id < 1) {
    sm_json_out(['success' => false, 'error' => 'Missing or invalid student_id']);
}

$mysqli = sm_mysqli_connect();
try {
    sm_require_super_admin($mysqli, $body);

    $session_id = sm_current_session_id($mysqli);
    [$df, $dt]  = sm_resolve_period($body);
    $df_q = $mysqli->real_escape_string($df);
    $dt_q = $mysqli->real_escape_string($dt);

    $table_ok = sm_snapshots_table_exists($mysqli);
    if (!$table_ok) {
        $mysqli->close();
        sm_json_out([
            'success'  => true,
            'table_ok' => false,
            'period'   => ['from' => $df, 'to' => $dt],
            'snapshot' => null,
        ]);
    }

    $sql = "SELECT sms.*, st.firstname, st.lastname, st.admission_no
              FROM student_monitoring_snapshots sms
              LEFT JOIN students st ON st.id = sms.student_id
             WHERE sms.session_id   = $session_id
               AND sms.student_id   = $student_id
               AND sms.period_start = '$df_q'
               AND sms.period_end   = '$dt_q'
             LIMIT 1";

    $res = $mysqli->query($sql);
    if (!$res) {
        throw new Exception('Query failed: ' . $mysqli->error);
    }
    $snapshot = null;
    if ($row = $res->fetch_assoc()) {
        $snapshot = [
            'id'             => (int) ($row['id'] ?? 0),
            'session_id'     => (int) ($row['session_id'] ?? 0),
            'student_id'     => (int) ($row['student_id'] ?? 0),
            'firstname'      => (string) ($row['firstname'] ?? ''),
            'lastname'       => (string) ($row['lastname'] ?? ''),
            'admission_no'   => (string) ($row['admission_no'] ?? ''),
            'period_start'   => (string) ($row['period_start'] ?? ''),
            'period_end'     => (string) ($row['period_end'] ?? ''),
            'score'          => isset($row['score']) ? (float) $row['score'] : 0.0,
            'previous_score' => isset($row['previous_score']) && $row['previous_score'] !== null
                                    ? (float) $row['previous_score']
                                    : null,
            'status'         => (string) ($row['status'] ?? 'warning'),
            'trend'          => (string) ($row['trend'] ?? 'stable'),
            'risk_level'     => (string) ($row['risk_level'] ?? 'normal'),
            'computed_at'    => (string) ($row['computed_at'] ?? ''),
            'metrics'        => sm_decode_json($row['metrics'] ?? ''),
            'suggestions'    => sm_decode_suggestions($row['suggestions'] ?? ''),
        ];
    }
    $res->free();
    $mysqli->close();

    sm_json_out([
        'success'  => true,
        'table_ok' => true,
        'period'   => ['from' => $df, 'to' => $dt],
        'snapshot' => $snapshot,
    ]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    sm_json_out(['success' => false, 'error' => $e->getMessage()]);
}
