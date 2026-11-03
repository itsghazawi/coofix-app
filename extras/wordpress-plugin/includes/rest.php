<?php
if (!defined('ABSPATH')) {
    exit;
}

/**
 * Public, read-only endpoint the mobile app reads on every launch:
 *   GET /wp-json/coofix-app/v1/config
 */
add_action('rest_api_init', function () {
    register_rest_route('coofix-app/v1', '/config', array(
        'methods'             => 'GET',
        'permission_callback' => '__return_true',
        'callback'            => 'coofix_app_rest_config',
    ));
    register_rest_route('coofix-app/v1', '/repair', array(
        'methods'             => 'GET',
        'permission_callback' => '__return_true',
        'callback'            => 'coofix_app_rest_repair',
        'args'                => array('code' => array('required' => true, 'sanitize_callback' => 'sanitize_text_field')),
    ));
});

/**
 * Repair status lookup by reference code.
 * The maintenance system plugs in through the filter:
 *   add_filter('coofix_app_repair_lookup', function ($result, $code) { ... return array(...); }, 10, 2);
 * Expected array keys: code, status (received|diagnosing|waiting_parts|repairing|ready|delivered|cancelled),
 * status_label, device, customer, received_at, expected_at, cost, warranty (bool), notes.
 */
function coofix_app_rest_repair(WP_REST_Request $req) {
    $code = strtoupper(trim((string) $req->get_param('code')));
    $result = $code === '' ? null : apply_filters('coofix_app_repair_lookup', null, $code);
    if (!is_array($result)) {
        return new WP_REST_Response(array('found' => false), 404);
    }
    $result['found'] = true;
    if (empty($result['code'])) {
        $result['code'] = $code;
    }
    $res = new WP_REST_Response($result, 200);
    $res->header('Cache-Control', 'no-store');
    return $res;
}

function coofix_app_rest_config() {
    $c = coofix_app_get_config();

    // Maps must stay JSON objects even when empty.
    foreach (array('icons', 'names') as $k) {
        $c['categories'][$k] = (object) (isset($c['categories'][$k]) ? $c['categories'][$k] : array());
    }
    $c['meta']['plugin_version'] = COOFIX_APP_VERSION;
    $c['meta']['server_time'] = time();

    $res = new WP_REST_Response($c, 200);
    $res->header('Cache-Control', 'no-cache, must-revalidate, max-age=0');
    return $res;
}
