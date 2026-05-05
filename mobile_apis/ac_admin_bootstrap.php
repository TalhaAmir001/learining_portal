<?php
/**
 * Shared bootstrap for Admin → Academics mobile APIs.
 *
 * Uses the same DB and secret model as existing academics timetable APIs.
 */

require_once __DIR__ . '/ac_bootstrap.php';

function ac_admin_success($payload = array()) {
    $out = array_merge(array('success' => true), $payload);
    ac_json_out($out);
}

function ac_admin_fail($message, $extra = array()) {
    $out = array_merge(array('success' => false, 'error' => (string) $message), $extra);
    ac_json_out($out);
}

function ac_admin_require_fields($body, $required_keys) {
    foreach ($required_keys as $k) {
        if (!isset($body[$k]) || $body[$k] === '' || $body[$k] === null) {
            throw new Exception("Missing required field: " . $k);
        }
    }
}

