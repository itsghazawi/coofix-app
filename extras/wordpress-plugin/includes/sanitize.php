<?php
if (!defined('ABSPATH')) {
    exit;
}

/**
 * Sanitize submitted settings against the defaults schema:
 * each value is cast to the type of its default, lists of records are
 * cleaned item by item, colours / links / numbers get their own filters.
 */
function coofix_app_sanitize($input) {
    $schema = coofix_app_defaults();
    $out = coofix_app_clean_node($schema, is_array($input) ? $input : array(), '');
    $out['meta']['updated'] = time();
    return $out;
}

function coofix_app_is_list($a) {
    return is_array($a) && ($a === array() || array_keys($a) === range(0, count($a) - 1));
}

function coofix_app_clean_node($schema, $value, $path) {
    // Special shapes whose default is empty.
    $int_lists = array('categories.order', 'categories.hidden', 'products.featured_ids');
    $maps      = array('categories.icons', 'categories.names');

    if (in_array($path, $int_lists, true)) {
        if (is_string($value)) {
            $value = preg_split('/[\s,،]+/u', $value);
        }
        $ids = array();
        foreach ((array) $value as $v) {
            $n = absint($v);
            if ($n > 0 && !in_array($n, $ids, true)) {
                $ids[] = $n;
            }
        }
        return $ids;
    }
    if (in_array($path, $maps, true)) {
        $m = array();
        foreach ((array) $value as $k => $v) {
            $k = absint($k);
            $v = sanitize_text_field(wp_unslash((string) $v));
            if ($k > 0 && $v !== '' && $v !== 'auto') {
                $m[(string) $k] = $v;
            }
        }
        return $m;
    }

    if (is_array($schema) && coofix_app_is_list($schema)) {
        if (is_string($value)) {
            $value = preg_split('/\r\n|\r|\n/', $value);
        }
        if (is_array($value)) {
            // Drop template placeholders such as [__i__]; keep posted order.
            $value = array_values(array_filter($value, function ($k) {
                return is_int($k) || ctype_digit((string) $k);
            }, ARRAY_FILTER_USE_KEY));
        } else {
            $value = array();
        }
        $tpl = isset($schema[0]) ? $schema[0] : '';
        $out = array();
        foreach ($value as $item) {
            if (is_array($tpl)) {
                if (!is_array($item)) {
                    continue;
                }
                $out[] = coofix_app_clean_node($tpl, $item, $path . '[]');
            } else {
                $s = sanitize_text_field(wp_unslash((string) $item));
                if ($s !== '') {
                    $out[] = $s;
                }
            }
        }
        return $out;
    }

    if (is_array($schema)) {
        $out = array();
        foreach ($schema as $k => $def) {
            $child_path = $path === '' ? $k : $path . '.' . $k;
            $has = is_array($value) && array_key_exists($k, $value);
            if (is_bool($def)) {
                // Checkboxes: absent means false (forms always post a hidden 0).
                $out[$k] = $has ? (bool) intval(is_array($value[$k]) ? 0 : $value[$k]) : false;
                continue;
            }
            if (!$has) {
                $out[$k] = is_array($def) ? coofix_app_clean_node($def, array(), $child_path) : $def;
                continue;
            }
            $out[$k] = coofix_app_clean_node($def, $value[$k], $child_path);
        }
        return $out;
    }

    // Scalars
    $key = $path;
    $leaf = preg_replace('/^.*[.\]]/', '', $key);
    if (is_int($schema)) {
        return intval($value);
    }
    if (is_float($schema)) {
        return round(floatval($value), 2);
    }
    $raw = wp_unslash(is_scalar($value) ? (string) $value : '');

    if (preg_match('/^(primary|primary_light|primary_deep|dark|dark_light|background|text|bg|fg)$/', $leaf)) {
        $c = sanitize_hex_color($raw);
        return $c ? strtoupper($c) : $schema;
    }
    if (preg_match('/(_url|^url|^image|^website|^maps_url|^facebook|^instagram|^tiktok|^telegram|^youtube)$/', $leaf)) {
        return esc_url_raw(trim($raw));
    }
    if (preg_match('/^(whatsapp_orders|whatsapp_support|whatsapp_maintenance|phone)$/', $leaf)) {
        return preg_replace('/\D+/', '', $raw);
    }
    if ($leaf === 'email') {
        return sanitize_email($raw);
    }
    if (preg_match('/^(title|body|message|header|footer|about_body|maintenance_intro|subtitle|text)$/', $leaf) || strpos($raw, "\n") !== false) {
        return sanitize_textarea_field($raw);
    }
    return sanitize_text_field($raw);
}
