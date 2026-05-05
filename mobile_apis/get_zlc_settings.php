<?php
require_once __DIR__ . '/zlc_bootstrap.php';

try {
    $mysqli = zlc_mysqli_connect();
    $settings = zlc_zoom_settings($mysqli);
    if (!$settings) {
        throw new Exception('zoom_settings not found');
    }
    $globalTok = zlc_oauth_token_json($mysqli, 0);
    $token_configured = $globalTok !== null && $globalTok !== '' && json_decode($globalTok, true) !== null;
    zlc_json_out(array(
        'success' => true,
        'settings' => array(
            'use_teacher_api' => (int) $settings['use_teacher_api'],
            'use_zoom_app' => (int) $settings['use_zoom_app'],
            'use_zoom_app_user' => (int) $settings['use_zoom_app_user'],
            'parent_live_class' => (int) $settings['parent_live_class'],
            'oauth_token_configured' => $token_configured,
        ),
    ));
} catch (Exception $e) {
    zlc_json_out(array('success' => false, 'error' => $e->getMessage()));
}
