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

add_action('template_redirect', function () {
    if (empty($_GET['cfx_invoice']) || !function_exists('wc_get_order')) {
        return;
    }
    $order = wc_get_order(absint($_GET['cfx_invoice']));
    $key = isset($_GET['key']) ? sanitize_text_field(wp_unslash($_GET['key'])) : '';
    if (!$order || (!hash_equals($order->get_order_key(), $key) && !current_user_can('manage_woocommerce'))) {
        wp_die('الفاتورة غير متاحة', 403);
    }
    nocache_headers();
    header('X-Robots-Tag: noindex');
    $cfg = coofix_app_get_config();
    $icon = !empty($cfg['brand']['icon_url']) ? $cfg['brand']['icon_url'] : COOFIX_APP_URL . 'assets/icon.png';
    $brand = $cfg['general']['app_name'] ?: 'كوفيكس سوريا';
    $tag = $cfg['general']['tagline'] ?: 'الوكيل الحصري والرسمي في سوريا';
    $wa = preg_replace('/\D/', '', $cfg['contact']['whatsapp_orders']);
    $wa_pretty = strpos($wa, '963') === 0 ? '0' . substr($wa, 3) : $wa;
    $name = trim($order->get_formatted_billing_full_name());
    $addr = implode(' — ', array_filter(array($order->get_billing_state(), $order->get_billing_city(), $order->get_billing_address_1())));
    $date = $order->get_date_created() ? $order->get_date_created()->date_i18n('Y/m/d — H:i') : '';
    $m = function ($v) use ($order) {
        return wp_strip_all_tags(wc_price($v, array('currency' => $order->get_currency())));
    };
    ?><!doctype html>
<html lang="ar" dir="rtl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>فاتورة <?php echo esc_html($order->get_order_number()); ?> — <?php echo esc_html($brand); ?></title>
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
    <div class="t"><i>ORDER</i><b>فاتورة طلب</b><span dir="ltr">#<?php echo esc_html($order->get_order_number()); ?></span></div>
  </div>
  <div class="info">
    <div><small>الزبون</small><b><?php echo esc_html($name ?: '—'); ?></b></div>
    <div><small>رقم الهاتف</small><b dir="ltr"><?php echo esc_html($order->get_billing_phone() ?: '—'); ?></b></div>
    <div><small>التاريخ</small><b><?php echo esc_html($date); ?></b></div>
    <div class="w2"><small>العنوان</small><b><?php echo esc_html($addr ?: '—'); ?></b></div>
    <div><small>طريقة الدفع</small><b><?php echo esc_html($order->get_payment_method_title() ?: 'الدفع عند الاستلام'); ?></b></div>
  </div>
  <table>
    <thead><tr><th>المنتج</th><th class="c">السعر</th><th class="c">الكمية</th><th class="l" style="font-family:inherit;font-weight:600">المجموع</th></tr></thead>
    <tbody>
    <?php foreach ($order->get_items() as $it) :
        $p = $it->get_product();
        $nm = $it->get_name();
        $sku = $p ? $p->get_sku() : '';
        if (!$sku && preg_match('/^\s*([A-Za-z0-9][A-Za-z0-9\-_.\/ ]{1,24}?)\s*\|\s*(.+)$/u', $nm, $mm)) {
            $sku = trim($mm[1]);
            $nm = trim($mm[2]);
        }
        $q = max(1, $it->get_quantity()); ?>
      <tr>
        <td class="n"><b><?php echo esc_html($nm); ?></b><?php if ($sku) { echo '<code dir="ltr">' . esc_html($sku) . '</code>'; } ?></td>
        <td class="c" dir="ltr"><?php echo esc_html($m($order->get_item_subtotal($it, false, true))); ?></td>
        <td class="c"><b><?php echo intval($q); ?></b></td>
        <td class="l" dir="ltr"><?php echo esc_html($m($order->get_line_subtotal($it, false, true))); ?></td>
      </tr>
    <?php endforeach; ?>
    </tbody>
  </table>
  <div class="tot"><div>
    <p><span>المجموع الفرعي</span><span dir="ltr"><?php echo esc_html($m($order->get_subtotal())); ?></span></p>
    <?php if ($order->get_total_discount() > 0) : ?>
      <p class="g"><span>حسم <?php echo esc_html(strtoupper(implode('، ', $order->get_coupon_codes()))); ?></span><span dir="ltr">- <?php echo esc_html($m($order->get_total_discount())); ?></span></p>
    <?php endif; ?>
    <p><span>التوصيل</span><span><?php echo $order->get_shipping_total() > 0 ? esc_html($m($order->get_shipping_total())) : 'يُحدَّد عند التأكيد'; ?></span></p>
    <div class="grand"><span style="font-weight:700">الإجمالي</span><b dir="ltr"><?php echo esc_html($m($order->get_total())); ?></b></div>
  </div></div>
  <?php if ($order->get_customer_note()) : ?><div class="note"><strong style="color:#15181D">ملاحظات الزبون:</strong> <?php echo esc_html($order->get_customer_note()); ?></div><?php endif; ?>
  <div class="sp"></div>
  <div class="perks"><span><b style="color:#B56A00">●</b> كفالة 6 أشهر</span><span><b style="color:#B56A00">●</b> منتجات أصلية 100%</span><span><b style="color:#B56A00">●</b> توصيل لكل المحافظات</span></div>
  <div class="ft"><span>شكراً لثقتك بكوفيكس — سنتواصل معك لتأكيد الطلب</span><span dir="ltr" style="font-weight:600">coofix.sy · <?php echo esc_html($wa_pretty); ?></span></div>
</div>
</body></html><?php
    exit;
}, 1);
