<?php
/**
 * GET: session_id (optional, 0 = all)
 */
require_once __DIR__ . '/zlc_bootstrap.php';

try {
    $mysqli = zlc_mysqli_connect();
    $session_id = isset($_GET['session_id']) ? (int) $_GET['session_id'] : 0;
    $sess = ($session_id > 0) ? (' WHERE session_id = ' . (int) $session_id) : '';
    $total = 0;
    $r = $mysqli->query('SELECT COUNT(*) AS c FROM live_class_feedback' . $sess);
    if ($r && $r->num_rows > 0) {
        $total = (int) $r->fetch_assoc()['c'];
    }
    $unread = 0;
    $wu = $sess ? ($sess . ' AND read_at IS NULL') : ' WHERE read_at IS NULL';
    $r = $mysqli->query('SELECT COUNT(*) AS c FROM live_class_feedback' . $wu);
    if ($r && $r->num_rows > 0) {
        $unread = (int) $r->fetch_assoc()['c'];
    }
    $read = 0;
    $wr = $sess ? ($sess . ' AND read_at IS NOT NULL') : ' WHERE read_at IS NOT NULL';
    $r = $mysqli->query('SELECT COUNT(*) AS c FROM live_class_feedback' . $wr);
    if ($r && $r->num_rows > 0) {
        $read = (int) $r->fetch_assoc()['c'];
    }
    $critical = 0;
    $wc = $sess ? ($sess . ' AND behavior_rating < 3 AND behavior_rating > 0') : ' WHERE behavior_rating < 3 AND behavior_rating > 0';
    $r = $mysqli->query('SELECT COUNT(*) AS c FROM live_class_feedback' . $wc);
    if ($r && $r->num_rows > 0) {
        $critical = (int) $r->fetch_assoc()['c'];
    }
    zlc_json_out(array(
        'success' => true,
        'summary' => array(
            'total' => $total,
            'unread' => $unread,
            'read' => $read,
            'critical' => $critical,
        ),
    ));
} catch (Exception $e) {
    zlc_json_out(array('success' => false, 'error' => $e->getMessage()));
}
