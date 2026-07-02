<?php
/**
 * Poll whether the current mobile-app actor is still allowed to use the app.
 *
 * Used by the Flutter client while a session is already open (revocation is
 * also enforced at login in parent_login.php / Gauthenticate.php).
 *
 * POST/GET (JSON or form):
 *   actor_type    : staff | portal_user | app_parent_user
 *   actor_id      : staff.id, users.id, or app_parent_users.id
 *   device_id     : client install UUID (required for mobile app requests)
 *   session_token : server-issued token from login (required for mobile app requests)
 *   api_secret?   : optional when PL_API_SECRET is configured
 *
 * Requires header X-Learning-Portal-App (same as all mobile API traffic).
 *
 * Response — allowed:
 *   { "success": true, "allowed": true, "revoked": false, "session_invalid": false }
 *
 * Response — revoked:
 *   { "success": true, "allowed": false, "revoked": true, "session_invalid": false, "error": "..." }
 *
 * Response — session invalid:
 *   { "success": true, "allowed": false, "revoked": false, "session_invalid": true, "error": "..." }
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

    if (pl_normalise_mobile_device_id($device_id) === '' || pl_normalise_mobile_session_token($session_token) === '') {
        $mysqli->close();
        pl_json_out(['success' => false, 'error' => 'device_id and session_token are required.']);
    }

    $revoked = pl_is_mobile_app_access_revoked($mysqli, $actor_type, $actor_id);
    if ($revoked) {
        $mysqli->close();
        pl_json_out([
            'success'         => true,
            'allowed'         => false,
            'revoked'         => true,
            'session_invalid' => false,
            'error'           => 'Your access to the Learning Portal mobile app has been disabled. Please contact the school office.',
        ]);
    }

    $session_valid = pl_validate_mobile_app_session($mysqli, $actor_type, $actor_id, $device_id, $session_token);
    if (!$session_valid) {
        $mysqli->close();
        pl_json_out([
            'success'         => true,
            'allowed'         => false,
            'revoked'         => false,
            'session_invalid' => true,
            'error'           => 'Your mobile app session is no longer valid. Please log in again.',
        ]);
    }

    pl_touch_mobile_app_session($mysqli, $actor_type, $actor_id, $device_id, $session_token);
    $mysqli->close();

    pl_json_out([
        'success'         => true,
        'allowed'         => true,
        'revoked'         => false,
        'session_invalid' => false,
    ]);
} catch (Exception $e) {
    if ($mysqli) {
        $mysqli->close();
    }
    pl_json_out(['success' => false, 'error' => $e->getMessage()]);
}
