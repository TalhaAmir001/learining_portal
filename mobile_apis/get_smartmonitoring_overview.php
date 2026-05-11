<?php
/**
 * Smart Monitoring – overview payload for the Flutter dashboard (Super Admin only).
 *
 * POST JSON:
 *   {
 *     api_secret?:   string,
 *     caller_staff_id: int,
 *     date_from?:   "YYYY-MM-DD",   // default last-30-days
 *     date_to?:     "YYYY-MM-DD",   // default today
 *     class_id?:    int,            // 0 = all
 *     section_id?:  int,            // 0 = all
 *     status?:      "good"|"warning"|"critical"|"",
 *     q?:           string          // student name / admission search
 *   }
 *
 * Response:
 *   {
 *     success:    bool,
 *     table_ok:   bool,
 *     period:     { from, to },
 *     classlist:  [{ id, class_name }],
 *     snapshots:  [<row>],
 *     rollups:    { avg_score, by_status, n },
 *     insights:   { n, by_status, risk, trend, avg_score, avg_attendance,
 *                   avg_homework, avg_exams_blended, top_suggestions:[{text,count}] },
 *     error?
 *   }
 *
 * Each snapshot row already has `metrics` and `suggestions` decoded server-side
 * (no double-decode on the Flutter side). Mirrors the projection of
 * Monitoring_model::list_snapshots_for_admin / dashboard_insights / class_rollups
 * but skips the heavy student_session join when no class/section filter is set.
 */

require_once __DIR__ . '/sm_bootstrap.php';

$body = sm_read_json_body();
sm_require_api_secret($body);

$mysqli = sm_mysqli_connect();
try {
    sm_require_super_admin($mysqli, $body);

    $session_id = sm_current_session_id($mysqli);
    [$df, $dt]  = sm_resolve_period($body);

    $class_id   = isset($body['class_id'])   ? (int) $body['class_id']   : 0;
    $section_id = isset($body['section_id']) ? (int) $body['section_id'] : 0;
    $status     = isset($body['status'])     ? trim((string) $body['status']) : '';
    $q          = isset($body['q'])          ? trim((string) $body['q'])     : '';

    if (!in_array($status, ['good', 'warning', 'critical'], true)) {
        $status = '';
    }

    $df_q = $mysqli->real_escape_string($df);
    $dt_q = $mysqli->real_escape_string($dt);
    $q_q  = $mysqli->real_escape_string($q);

    // Always-present output
    $table_ok = sm_snapshots_table_exists($mysqli);

    $classlist = [];
    $res = $mysqli->query("SELECT id, class AS class_name FROM classes ORDER BY class ASC");
    if ($res) {
        while ($row = $res->fetch_assoc()) {
            $classlist[] = [
                'id'         => (int) $row['id'],
                'class_name' => (string) ($row['class_name'] ?? ''),
            ];
        }
        $res->free();
    }

    $response = [
        'success'   => true,
        'table_ok'  => $table_ok,
        'period'    => ['from' => $df, 'to' => $dt],
        'classlist' => $classlist,
        'snapshots' => [],
        'rollups'   => ['avg_score' => null, 'by_status' => ['good' => 0, 'warning' => 0, 'critical' => 0], 'n' => 0],
        'insights'  => sm_empty_insights(),
    ];

    if (!$table_ok) {
        $mysqli->close();
        sm_json_out($response);
    }

    $where = [
        "sms.session_id = $session_id",
        "sms.period_start = '$df_q'",
        "sms.period_end = '$dt_q'",
    ];
    if ($status !== '') {
        $where[] = "sms.status = '" . $mysqli->real_escape_string($status) . "'";
    }
    if ($q !== '') {
        $where[] = "(st.firstname LIKE '%$q_q%' OR st.lastname LIKE '%$q_q%' OR st.admission_no LIKE '%$q_q%')";
    }

    $join_extra = '';
    $group_by   = '';
    if ($class_id > 0 || $section_id > 0) {
        $join_extra = "INNER JOIN student_session ss
                          ON ss.student_id = sms.student_id
                         AND ss.session_id = sms.session_id";
        if ($class_id > 0) {
            $where[] = 'ss.class_id = ' . $class_id;
        }
        if ($section_id > 0) {
            $where[] = 'ss.section_id = ' . $section_id;
        }
        $group_by = 'GROUP BY sms.id';
    }

    $where_sql = implode(' AND ', $where);
    $sql = "SELECT sms.*, st.firstname, st.lastname, st.admission_no
              FROM student_monitoring_snapshots sms
              LEFT JOIN students st ON st.id = sms.student_id
              $join_extra
             WHERE $where_sql
             $group_by
             ORDER BY sms.score ASC, st.firstname ASC";
    $res = $mysqli->query($sql);
    $snapshots = [];
    if ($res) {
        while ($row = $res->fetch_assoc()) {
            $snapshots[] = sm_format_snapshot_row($row);
        }
        $res->free();
    } else {
        throw new Exception('Snapshot query failed: ' . $mysqli->error);
    }
    $response['snapshots'] = $snapshots;

    // Rollups – mirrors Monitoring_model::class_rollups (full-period, ignores class/section/status filters).
    $rollups = ['avg_score' => null, 'by_status' => ['good' => 0, 'warning' => 0, 'critical' => 0], 'n' => 0];
    $sql = "SELECT status, COUNT(*) AS c FROM student_monitoring_snapshots
             WHERE session_id = $session_id AND period_start = '$df_q' AND period_end = '$dt_q'
             GROUP BY status";
    $res = $mysqli->query($sql);
    if ($res) {
        while ($row = $res->fetch_assoc()) {
            $st = (string) ($row['status'] ?? '');
            $cn = (int) ($row['c'] ?? 0);
            if (isset($rollups['by_status'][$st])) {
                $rollups['by_status'][$st] = $cn;
            }
            $rollups['n'] += $cn;
        }
        $res->free();
    }
    $sql = "SELECT AVG(score) AS avg_score FROM student_monitoring_snapshots
             WHERE session_id = $session_id AND period_start = '$df_q' AND period_end = '$dt_q'";
    $res = $mysqli->query($sql);
    if ($res) {
        $row = $res->fetch_assoc();
        if (!empty($row['avg_score'])) {
            $rollups['avg_score'] = round((float) $row['avg_score'], 1);
        }
        $res->free();
    }
    $response['rollups'] = $rollups;

    $response['insights'] = sm_compute_insights($snapshots);

    $mysqli->close();
    sm_json_out($response);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    sm_json_out(['success' => false, 'error' => $e->getMessage()]);
}

/**
 * Convert a raw DB row into a Flutter-friendly snapshot with decoded JSON columns.
 */
function sm_format_snapshot_row(array $row) {
    $metrics     = sm_decode_json($row['metrics'] ?? '');
    $suggestions = sm_decode_suggestions($row['suggestions'] ?? '');
    return [
        'id'             => (int) ($row['id'] ?? 0),
        'session_id'     => (int) ($row['session_id'] ?? 0),
        'student_id'     => (int) ($row['student_id'] ?? 0),
        'firstname'      => (string) ($row['firstname'] ?? ''),
        'lastname'       => (string) ($row['lastname'] ?? ''),
        'admission_no'   => (string) ($row['admission_no'] ?? ''),
        'period_start'   => (string) ($row['period_start'] ?? ''),
        'period_end'     => (string) ($row['period_end'] ?? ''),
        'score'          => isset($row['score'])          ? (float) $row['score']          : 0.0,
        'previous_score' => isset($row['previous_score']) && $row['previous_score'] !== null
                                ? (float) $row['previous_score']
                                : null,
        'status'         => (string) ($row['status'] ?? 'warning'),
        'trend'          => (string) ($row['trend'] ?? 'stable'),
        'risk_level'     => (string) ($row['risk_level'] ?? 'normal'),
        'computed_at'    => (string) ($row['computed_at'] ?? ''),
        'metrics'        => $metrics,
        'suggestions'    => $suggestions,
    ];
}

function sm_empty_insights() {
    return [
        'n'                 => 0,
        'by_status'         => ['good' => 0, 'warning' => 0, 'critical' => 0],
        'risk'              => ['normal' => 0, 'warning' => 0, 'critical' => 0],
        'trend'             => ['up' => 0, 'down' => 0, 'stable' => 0],
        'avg_score'         => null,
        'avg_attendance'    => null,
        'avg_homework'      => null,
        'avg_exams_blended' => null,
        'top_suggestions'   => [],
    ];
}

/**
 * Port of Monitoring_model::dashboard_insights() that operates on already-formatted
 * snapshot rows (metrics/suggestions are already arrays here).
 */
function sm_compute_insights(array $snapshots) {
    $out = sm_empty_insights();
    $out['n'] = count($snapshots);
    if (empty($snapshots)) {
        return $out;
    }
    $scores   = [];
    $att_vals = [];
    $hw_vals  = [];
    $ex_vals  = [];
    $sug_map  = [];
    foreach ($snapshots as $row) {
        $st = (string) ($row['status'] ?? '');
        if (isset($out['by_status'][$st])) {
            $out['by_status'][$st]++;
        }
        $rk = strtolower(trim((string) ($row['risk_level'] ?? 'normal')));
        if (!isset($out['risk'][$rk])) {
            $rk = 'normal';
        }
        $out['risk'][$rk]++;
        $tr = strtolower(trim((string) ($row['trend'] ?? 'stable')));
        if (!isset($out['trend'][$tr])) {
            $tr = 'stable';
        }
        $out['trend'][$tr]++;
        if (isset($row['score']) && $row['score'] !== null && $row['score'] !== '') {
            $scores[] = (float) $row['score'];
        }
        $m = is_array($row['metrics'] ?? null) ? $row['metrics'] : [];
        if (isset($m['attendance']['pct']) && $m['attendance']['pct'] !== null && $m['attendance']['pct'] !== '') {
            $att_vals[] = (float) $m['attendance']['pct'];
        }
        if (isset($m['homework_blended_pct']) && $m['homework_blended_pct'] !== null && $m['homework_blended_pct'] !== '') {
            $hw_vals[] = (float) $m['homework_blended_pct'];
        }
        if (isset($m['exams_blended_pct']) && $m['exams_blended_pct'] !== null && $m['exams_blended_pct'] !== '') {
            $ex_vals[] = (float) $m['exams_blended_pct'];
        }
        $sug = is_array($row['suggestions'] ?? null) ? $row['suggestions'] : [];
        foreach ($sug as $line) {
            $line = trim((string) $line);
            if ($line === '') {
                continue;
            }
            if (!isset($sug_map[$line])) {
                $sug_map[$line] = 0;
            }
            $sug_map[$line]++;
        }
    }
    if (!empty($scores)) {
        $out['avg_score'] = round(array_sum($scores) / count($scores), 1);
    }
    if (!empty($att_vals)) {
        $out['avg_attendance'] = round(array_sum($att_vals) / count($att_vals), 1);
    }
    if (!empty($hw_vals)) {
        $out['avg_homework'] = round(array_sum($hw_vals) / count($hw_vals), 1);
    }
    if (!empty($ex_vals)) {
        $out['avg_exams_blended'] = round(array_sum($ex_vals) / count($ex_vals), 1);
    }
    arsort($sug_map);
    $top = array_slice($sug_map, 0, 8, true);
    $out['top_suggestions'] = [];
    foreach ($top as $text => $cnt) {
        $out['top_suggestions'][] = ['text' => (string) $text, 'count' => (int) $cnt];
    }
    return $out;
}
