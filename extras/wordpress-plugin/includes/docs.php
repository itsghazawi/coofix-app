<?php
/**
 * Website order invoice — rendered on the fly as a printable A4 page
 * (the browser's "Save as PDF"). Nothing is generated or stored on the server.
 */
if (!defined('ABSPATH')) {
    exit;
}

function cfx_invoice_url($order) {
    return add_query_arg(array('cfx_invoice' => $order->get_id(), 'key' => $order->get_order_key()), home_url('/'));
}

function cfx_invoice_button($order) {
    if (!$order) {
        return;
    }
    echo '<p style="margin:18px 0"><a class="button cfx-invoice-btn" target="_blank" rel="noopener" href="' . esc_url(cfx_invoice_url($order)) . '" style="display:inline-flex;align-items:center;gap:8px">'
        . '<svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8zm-1 7V3.5L18.5 9zM8 13h8v2H8zm0 4h5v2H8z"/></svg>'
        . 'تحميل الفاتورة PDF</a></p>';
}

add_action('woocommerce_thankyou', function ($order_id) {
    cfx_invoice_button(wc_get_order($order_id));
}, 5);
add_action('woocommerce_view_order', function ($order_id) {
    cfx_invoice_button(wc_get_order($order_id));
}, 5);
add_action('woocommerce_admin_order_data_after_order_details', function ($order) {
    echo '<p class="form-field form-field-wide"><a class="button" target="_blank" href="' . esc_url(cfx_invoice_url($order)) . '">فاتورة كوفيكس PDF</a></p>';
});

/** Printable invoice page from a normalised array. */
function cfx_invoice_render($d) {
    nocache_headers();
    header('X-Robots-Tag: noindex');
    $cfg = coofix_app_get_config();
    $icon = !empty($cfg['brand']['icon_url']) ? $cfg['brand']['icon_url'] : COOFIX_APP_URL . 'assets/icon.png';
    $brand = $cfg['general']['app_name'] ?: 'كوفيكس سوريا';
    $tag = $cfg['general']['tagline'] ?: 'الوكيل الحصري والرسمي في سوريا';
    $wa = preg_replace('/\D/', '', $cfg['contact']['whatsapp_orders']);
    $wa_pretty = strpos($wa, '963') === 0 ? '0' . substr($wa, 3) : $wa;
    $d = wp_parse_args($d, array('number' => '', 'date' => '', 'name' => '', 'phone' => '', 'addr' => '', 'items' => array(), 'sub' => '', 'disc' => '', 'coupons' => '', 'total' => '', 'note' => ''));
    ?><!doctype html>
<html lang="ar" dir="rtl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>فاتورة <?php echo esc_html($d['number']); ?> — <?php echo esc_html($brand); ?></title>
<link href="https://fonts.googleapis.com/css2?family=Alexandria:wght@500;700;800&family=IBM+Plex+Sans+Arabic:wght@400;500;600;700&display=swap" rel="stylesheet">
<style>
@page{size:A4;margin:0}
*{box-sizing:border-box}
body{margin:0;background:#E9E7E2;font-family:'IBM Plex Sans Arabic',sans-serif;color:#15181D;-webkit-print-color-adjust:exact;print-color-adjust:exact}
.bar{position:sticky;top:0;z-index:5;display:flex;gap:10px;justify-content:center;padding:12px;background:#061922}
.bar button{font:700 15px 'IBM Plex Sans Arabic';border:0;border-radius:12px;padding:12px 22px;cursor:pointer;background:#FAA21B;color:#061922}
.bar a{font:600 14px 'IBM Plex Sans Arabic';color:#fff;align-self:center;text-decoration:none;opacity:.75}
.page{width:210mm;min-height:297mm;margin:16px auto;background:#fff;display:flex;flex-direction:column;box-shadow:0 10px 40px rgba(0,0,0,.12)}
.hd{background:#061922;color:#fff;padding:40px 48px 34px;display:flex;justify-content:space-between;align-items:flex-start;border-bottom:5px solid #FAA21B}
.hd .b{display:flex;gap:16px;align-items:center}
.hd img{width:64px;height:64px;border-radius:18px;background:#0F3041;padding:8px;border:1px solid rgba(250,162,27,.45)}
.hd h1{margin:0;font:800 24px Alexandria}.hd small{display:block;font-size:13px;opacity:.62}
.hd .t{text-align:left}.hd .t i{display:block;font:700 13px Alexandria;letter-spacing:3px;color:#FAA21B;font-style:normal}
.hd .t b{display:block;font:800 26px Alexandria}.hd .t span{font-size:13px;opacity:.62}
.info{padding:28px 48px 0;display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px}
.info div{background:#F4F3F0;border-radius:16px;padding:12px 16px}.info small{display:block;font-size:12px;color:#6B7079}.info b{font-size:15px}
.info .w2{grid-column:span 2}
table{width:calc(100% - 96px);margin:24px 48px 0;border-collapse:collapse}
th{font-size:12px;color:#6B7079;font-weight:600;text-align:right;padding:0 14px 10px;border-bottom:2px solid #061922}
td{padding:12px 14px;border-bottom:1px solid #E6E3DD;font-size:14px;vertical-align:middle}
td.n b{display:block;font-size:15px}td.n code{display:inline-block;margin-top:4px;font:700 11px Alexandria;color:#7A4700;background:rgba(250,162,27,.16);padding:2px 8px;border-radius:7px}
.c{text-align:center}.l{text-align:left;font-family:Alexandria;font-weight:700}
.tot{padding:20px 48px 0;display:flex;justify-content:flex-end}.tot div{width:330px}
.tot p{display:flex;justify-content:space-between;margin:0 0 6px;font-size:14px;color:#4A4F57}.tot .g{color:#16794A;font-weight:700}
.tot .grand{margin-top:10px;background:#061922;color:#fff;border-radius:16px;padding:14px 18px;display:flex;justify-content:space-between;align-items:center}
.tot .grand b{font:800 22px Alexandria;color:#FAA21B}
.note{margin:20px 48px 0;border:1px solid #D9D5CC;border-radius:16px;padding:12px 18px;font-size:13px;color:#4A4F57}
.sp{flex:1}
.perks{padding:0 48px 16px;display:grid;grid-template-columns:repeat(3,1fr);font-size:12.5px;color:#4A4F57}
.ft{background:#F4F3F0;padding:16px 48px;display:flex;justify-content:space-between;font-size:12.5px;color:#4A4F57}
@media print{body{background:#fff}.bar{display:none}.page{margin:0;box-shadow:none;width:auto;min-height:100vh}}
@media (max-width:820px){.page{width:auto;margin:0}}
</style></head><body>
<div class="bar"><button type="button" onclick="window.print()">حفظ PDF / طباعة</button><a href="<?php echo esc_url(home_url('/')); ?>">العودة للمتجر</a></div>
<div class="page">
  <div class="hd">
    <div class="b"><img src="<?php echo esc_url($icon); ?>" alt=""><div><h1><?php echo esc_html($brand); ?></h1><small><?php echo esc_html($tag); ?></small></div></div>
    <div class="t"><i>ORDER</i><b>فاتورة طلب</b><span dir="ltr"><?php echo esc_html($d['number']); ?></span></div>
  </div>
  <div class="info">
    <div><small>الزبون</small><b><?php echo esc_html($d['name'] ?: '—'); ?></b></div>
    <div><small>رقم الهاتف</small><b dir="ltr"><?php echo esc_html($d['phone'] ?: '—'); ?></b></div>
    <div><small>التاريخ</small><b><?php echo esc_html($d['date']); ?></b></div>
    <div class="w2"><small>العنوان</small><b><?php echo esc_html($d['addr'] ?: '—'); ?></b></div>
    <div><small>طريقة الدفع</small><b>تحويل قبل الاستلام</b></div>
  </div>
  <table>
    <thead><tr><th>المنتج</th><th class="c">السعر</th><th class="c">الكمية</th><th class="l" style="font-family:inherit;font-weight:600">المجموع</th></tr></thead>
    <tbody>
    <?php foreach ($d['items'] as $it) : ?>
      <tr>
        <td class="n"><b><?php echo esc_html($it['n']); ?></b><?php if (!empty($it['s'])) { echo '<code dir="ltr">' . esc_html($it['s']) . '</code>'; } ?></td>
        <td class="c" dir="ltr"><?php echo esc_html($it['p']); ?></td>
        <td class="c"><b><?php echo intval($it['q']); ?></b></td>
        <td class="l" dir="ltr"><?php echo esc_html($it['t']); ?></td>
      </tr>
    <?php endforeach; ?>
    </tbody>
  </table>
  <div class="tot"><div>
    <?php if ($d['sub']) : ?><p><span>المجموع الفرعي</span><span dir="ltr"><?php echo esc_html($d['sub']); ?></span></p><?php endif; ?>
    <?php if ($d['disc']) : ?><p class="g"><span>حسم <?php echo esc_html($d['coupons']); ?></span><span dir="ltr">- <?php echo esc_html($d['disc']); ?></span></p><?php endif; ?>
    <p><span>رسوم التوصيل</span><span>يدفعها الزبون</span></p>
    <div class="grand"><span style="font-weight:700">الإجمالي</span><b dir="ltr"><?php echo esc_html($d['total']); ?></b></div>
  </div></div>
  <?php if ($d['note']) : ?><div class="note"><strong style="color:#15181D">ملاحظات الزبون:</strong> <?php echo esc_html($d['note']); ?></div><?php endif; ?>
  <div class="sp"></div>
  <div class="perks"><span><b style="color:#B56A00">●</b> كفالة 6 أشهر</span><span><b style="color:#B56A00">●</b> منتجات أصلية 100%</span><span><b style="color:#B56A00">●</b> توصيل لكل المحافظات</span></div>
  <div class="ft"><span>شكراً لثقتك بكوفيكس — سنتواصل معك لتأكيد الطلب</span><span dir="ltr" style="font-weight:600">coofix.sy · <?php echo esc_html($wa_pretty); ?></span></div>
</div>
</body></html><?php
    exit;
}

add_action('template_redirect', function () {
    // Signed invoice link sent inside the WhatsApp order (the data travels in the link; nothing is stored).
    if (!empty($_GET['cfx_order'])) {
        $t = sanitize_text_field(wp_unslash($_GET['cfx_order']));
        $parts = explode('.', $t);
        if (count($parts) === 2 && hash_equals(substr(hash_hmac('sha256', $parts[0], wp_salt('auth')), 0, 32), $parts[1])) {
            $json = base64_decode(strtr($parts[0], '-_', '+/'));
            $d = json_decode((string) $json, true);
            if (is_array($d)) {
                cfx_invoice_render($d);
            }
        }
        wp_die('رابط الفاتورة غير صالح', 403);
    }
    if (empty($_GET['cfx_invoice']) || !function_exists('wc_get_order')) {
        return;
    }
    $order = wc_get_order(absint($_GET['cfx_invoice']));
    $key = isset($_GET['key']) ? sanitize_text_field(wp_unslash($_GET['key'])) : '';
    if (!$order || (!hash_equals($order->get_order_key(), $key) && !current_user_can('manage_woocommerce'))) {
        wp_die('الفاتورة غير متاحة', 403);
    }
    $m = function ($v) use ($order) {
        return wp_strip_all_tags(wc_price($v, array('currency' => $order->get_currency())));
    };
    $items = array();
    foreach ($order->get_items() as $it) {
        $p = $it->get_product();
        $nm = $it->get_name();
        $sku = $p ? $p->get_sku() : '';
        if (!$sku && preg_match('/^\s*([A-Za-z0-9][A-Za-z0-9\-_.\/ ]{1,24}?)\s*\|\s*(.+)$/u', $nm, $mm)) {
            $sku = trim($mm[1]);
            $nm = trim($mm[2]);
        }
        $items[] = array('n' => $nm, 's' => $sku, 'q' => max(1, $it->get_quantity()), 'p' => $m($order->get_item_subtotal($it, false, true)), 't' => $m($order->get_line_subtotal($it, false, true)));
    }
    cfx_invoice_render(array(
        'number'  => '#' . $order->get_order_number(),
        'date'    => $order->get_date_created() ? $order->get_date_created()->date_i18n('Y/m/d — H:i') : '',
        'name'    => trim($order->get_formatted_billing_full_name()),
        'phone'   => preg_replace('/[\s\-]/', '', $order->get_billing_phone()),
        'addr'    => implode(' — ', array_filter(array($order->get_billing_state(), $order->get_billing_city(), $order->get_billing_address_1()))),
        'items'   => $items,
        'sub'     => $m($order->get_subtotal()),
        'disc'    => $order->get_total_discount() > 0 ? $m($order->get_total_discount()) : '',
        'coupons' => strtoupper(implode('، ', $order->get_coupon_codes())),
        'total'   => $m($order->get_total()),
        'note'    => $order->get_customer_note(),
    ));
}, 1);

/** REST: sign an order snapshot → invoice link (used by the website's WhatsApp order). */
add_action('rest_api_init', function () {
    register_rest_route('coofix-app/v1', '/order-link', array(
        'methods'             => 'POST',
        'permission_callback' => '__return_true',
        'callback'            => function (WP_REST_Request $r) {
            if (cfx_rate_limited('olink', 60, 600)) {
                return new WP_Error('cfx_rate', 'محاولات كثيرة', array('status' => 429));
            }
            $in = (array) $r->get_json_params();
            $clean = function ($v, $n = 120) { return mb_substr(sanitize_text_field((string) $v), 0, $n); };
            $items = array();
            foreach (array_slice((array) ($in['items'] ?? array()), 0, 40) as $it) {
                $items[] = array('n' => $clean($it['n'] ?? ''), 's' => $clean($it['s'] ?? '', 40), 'q' => max(1, intval($it['q'] ?? 1)), 'p' => $clean($it['p'] ?? '', 40), 't' => $clean($it['t'] ?? '', 40));
            }
            $d = array(
                'number' => $clean($in['number'] ?? '', 40), 'date' => $clean($in['date'] ?? '', 40),
                'name' => $clean($in['name'] ?? ''), 'phone' => preg_replace('/[^\d+]/', '', (string) ($in['phone'] ?? '')),
                'addr' => $clean($in['addr'] ?? '', 200), 'items' => $items,
                'sub' => $clean($in['sub'] ?? '', 40), 'disc' => $clean($in['disc'] ?? '', 40), 'coupons' => $clean($in['coupons'] ?? '', 80),
                'total' => $clean($in['total'] ?? '', 40), 'note' => '',
            );
            $b = rtrim(strtr(base64_encode(wp_json_encode($d)), '+/', '-_'), '=');
            $sig = substr(hash_hmac('sha256', $b, wp_salt('auth')), 0, 32);
            return array('url' => add_query_arg('cfx_order', $b . '.' . $sig, home_url('/')));
        },
    ));
});
