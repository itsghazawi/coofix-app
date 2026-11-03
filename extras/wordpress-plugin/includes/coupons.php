<?php
/**
 * Discount codes for the app — they are normal WooCommerce coupons
 * (WooCommerce → Marketing → Coupons), so the owner sets each code's value there.
 */
if (!defined('ABSPATH')) {
    exit;
}

/** Validate a coupon for a list of [product_id => qty] and a subtotal. */
function cfx_coupon_check($code, $items, $subtotal) {
    if (!class_exists('WC_Coupon')) {
        return new WP_Error('cfx_wc', 'المتجر غير متاح');
    }
    $code = wc_format_coupon_code($code);
    if ($code === '') {
        return new WP_Error('cfx_empty', 'أدخل كود الحسم');
    }
    $c = new WC_Coupon($code);
    if (!$c->get_id() || get_post_status($c->get_id()) !== 'publish') {
        return new WP_Error('cfx_bad', 'الكود غير صحيح');
    }
    $exp = $c->get_date_expires();
    if ($exp && $exp->getTimestamp() < time()) {
        return new WP_Error('cfx_exp', 'انتهت صلاحية هذا الكود');
    }
    if ($c->get_usage_limit() && $c->get_usage_count() >= $c->get_usage_limit()) {
        return new WP_Error('cfx_used', 'تم استخدام هذا الكود بالكامل');
    }
    $min = floatval($c->get_minimum_amount());
    if ($min > 0 && $subtotal < $min) {
        return new WP_Error('cfx_min', 'الحد الأدنى للطلب لاستخدام الكود: ' . wc_format_localized_price($min));
    }
    $max = floatval($c->get_maximum_amount());
    if ($max > 0 && $subtotal > $max) {
        return new WP_Error('cfx_max', 'قيمة الطلب أعلى من الحد المسموح لهذا الكود');
    }
    // Which items does it apply to?
    $incl = array_map('intval', $c->get_product_ids());
    $excl = array_map('intval', $c->get_excluded_product_ids());
    $cats = array_map('intval', $c->get_product_categories());
    $xcats = array_map('intval', $c->get_excluded_product_categories());
    $eligible = 0.0;
    $any = false;
    foreach ($items as $pid => $it) {
        $pid = intval($pid);
        $p = wc_get_product($pid);
        if (!$p) {
            continue;
        }
        $pc = wc_get_product_cat_ids($p->get_parent_id() ?: $pid);
        $ok = (!$incl || in_array($pid, $incl, true)) && !in_array($pid, $excl, true)
            && (!$cats || array_intersect($pc, $cats)) && !array_intersect($pc, $xcats);
        if ($c->get_exclude_sale_items() && $p->is_on_sale()) {
            $ok = false;
        }
        if ($ok) {
            $any = true;
            $eligible += floatval($it['price']) * intval($it['qty']);
        }
    }
    if (!$any) {
        return new WP_Error('cfx_na', 'هذا الكود لا ينطبق على منتجات السلة');
    }
    $type = $c->get_discount_type();
    $amount = floatval($c->get_amount());
    if ($type === 'percent') {
        $disc = $eligible * $amount / 100;
        $label = rtrim(rtrim(number_format($amount, 2, '.', ''), '0'), '.') . '%';
    } elseif ($type === 'fixed_product') {
        $disc = 0;
        foreach ($items as $pid => $it) {
            $disc += min(floatval($it['price']), $amount) * intval($it['qty']);
        }
        $label = wc_format_localized_price($amount) . ' للقطعة';
    } else {
        $disc = min($amount, $eligible);
        $label = wc_format_localized_price($amount);
    }
    $disc = round(min($disc, $subtotal), 2);
    return array(
        'ok'       => true,
        'code'     => strtoupper($code),
        'type'     => $type,
        'amount'   => $amount,
        'label'    => $label,
        'discount' => $disc,
        'total'    => round($subtotal - $disc, 2),
        'message'  => $c->get_description() ?: 'تم تطبيق الحسم',
    );
}

add_action('rest_api_init', function () {
    // POST {code, items: [{id, qty, price}]}
    register_rest_route('coofix-app/v1', '/coupon', array(
        'methods'             => 'POST',
        'permission_callback' => '__return_true',
        'callback'            => function (WP_REST_Request $r) {
            if (cfx_rate_limited('coupon', 40, 600)) {
                return new WP_Error('cfx_rate', 'محاولات كثيرة، حاول بعد قليل', array('status' => 429));
            }
            $items = array();
            $sub = 0.0;
            foreach ((array) $r->get_param('items') as $it) {
                $id = intval(isset($it['id']) ? $it['id'] : 0);
                $q = max(1, intval(isset($it['qty']) ? $it['qty'] : 1));
                $p = $id ? wc_get_product($id) : null;
                if (!$p) {
                    continue;
                }
                $price = floatval($p->get_price());
                $items[$id] = array('qty' => $q, 'price' => $price);
                $sub += $price * $q;
            }
            $res = cfx_coupon_check((string) $r->get_param('code'), $items, $sub);
            if (is_wp_error($res)) {
                return new WP_REST_Response(array('ok' => false, 'message' => $res->get_error_message()), 200);
            }
            // The app sends `use=1` when the order is actually sent: count one use.
            if ($r->get_param('use')) {
                $c = new WC_Coupon($res['code']);
                if ($c->get_id()) {
                    $c->increase_usage();
                }
            }
            $res['subtotal'] = round($sub, 2);
            return $res;
        },
    ));
});

// Website: make sure the coupon box is visible on the cart.
add_filter('woocommerce_coupons_enabled', '__return_true');
