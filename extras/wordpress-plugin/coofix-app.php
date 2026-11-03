<?php
/**
 * Plugin Name:       Coofix App
 * Description:       لوحة تحكم كاملة بتطبيق كوفيكس سوريا (أندرويد وآيفون): الهوية، البانرات، الأقسام، المنتجات، التواصل، الإعلانات، الصيانة والتحديثات.
 * Version:           1.2.0
 * Author:            Coofix Syria
 * Text Domain:       coofix-app
 * Requires at least: 5.8
 * Requires PHP:      7.4
 */

if (!defined('ABSPATH')) {
    exit;
}

define('COOFIX_APP_VERSION', '1.2.0');
define('COOFIX_APP_OPTION', 'coofix_app_config');
define('COOFIX_APP_URL', plugin_dir_url(__FILE__));
define('COOFIX_APP_DIR', plugin_dir_path(__FILE__));

require_once COOFIX_APP_DIR . 'includes/defaults.php';
require_once COOFIX_APP_DIR . 'includes/sanitize.php';
require_once COOFIX_APP_DIR . 'includes/rest.php';
require_once COOFIX_APP_DIR . 'includes/admin.php';
require_once COOFIX_APP_DIR . 'includes/repairs.php';

/** Current config merged over defaults (so new keys always exist). */
function coofix_app_get_config() {
    $saved = get_option(COOFIX_APP_OPTION, array());
    if (!is_array($saved)) {
        $saved = array();
    }
    return coofix_app_merge(coofix_app_defaults(), $saved);
}

/** Deep merge: assoc arrays merge recursively, lists are replaced as a whole. */
function coofix_app_merge($base, $over) {
    if (!is_array($base) || !is_array($over)) {
        return $over;
    }
    $is_list = array_keys($base) === range(0, count($base) - 1) && count($base) > 0;
    if ($is_list) {
        return $over;
    }
    foreach ($over as $k => $v) {
        if (array_key_exists($k, $base) && is_array($base[$k]) && is_array($v)) {
            $base_is_list = $base[$k] === array() || array_keys($base[$k]) === range(0, count($base[$k]) - 1);
            $base[$k] = $base_is_list ? $v : coofix_app_merge($base[$k], $v);
        } else {
            $base[$k] = $v;
        }
    }
    return $base;
}

register_activation_hook(__FILE__, function () {
    if (get_option(COOFIX_APP_OPTION, null) === null) {
        $d = coofix_app_defaults();
        $d['meta']['updated'] = time();
        add_option(COOFIX_APP_OPTION, $d, '', false);
    }
});

add_filter('plugin_action_links_' . plugin_basename(__FILE__), function ($links) {
    array_unshift($links, '<a href="' . esc_url(admin_url('admin.php?page=coofix-app')) . '">الإعدادات</a>');
    return $links;
});
