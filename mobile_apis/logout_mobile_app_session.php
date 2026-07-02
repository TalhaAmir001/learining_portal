<?php
/**
 * Release the active mobile-app session on logout.
 *
 * POST (JSON or form):
 *   actor_type    : staff | portal_user | app_parent_user
 *   actor_id      : staff.id, users.id, or app_parent_users.id
 *   device_id     : client install UUID
 *   session_token : server-issued token from login
 *   api_secret?   : optional when PL_API_SECRET is configured
 *
 * Requires header X-Learning-Portal-App.
 *
 * Response:
 *   { "success": true }
 */

require_once __DIR__ . '/pl_bootstrap.php';

$mysqli = pl_mysqli_connect();

try {
    $body = pl_read_json_body();
    pl_require_api_secret($body);

    if (!pl_is_learning_portal_mobile_app_request()) {
        $mysqli->close();
        pl_json_out(['success' => false, 'error' => 'Mobile app request required.']);
    }

    $actor_type    = isset($body['actor_type']) ? (string) $body['actor_type'] : '';
    $actor_id      = isset($body['actor_id']) ? (int) $body['actor_id'] : 0;
    $device_id     = isset($body['device_id']) ? (string) $body['device_id'] : '';
    $session_token = isset($body['session_token']) ? (string) $body['session_token'] : '';
    $actor_type    = preg_replace('/[^a-z_]/', '', strtolower(trim($actor_type)));

    if (!in_array($actor_type, array('staff', 'portal_user', 'app_parent_user'), true) || $actor_id < 1) {
        $mysqli->close();
        pl_json_out(['success' => false, 'error' => 'Invalid actor_type or actor_id.']);
    }

    pl_release_mobile_app_session($mysqli, $actor_type, $actor_id, $device_id, $session_token);
    $mysqli->close();

    pl_json_out(['success' => true]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    pl_json_out(['success' => false, 'error' => $e->getMessage()]);
}
