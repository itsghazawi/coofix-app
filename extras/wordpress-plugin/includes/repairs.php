<?php
/**
 * Coofix maintenance (repairs) module.
 *
 * - Custom post type "cfx_repair" managed from WordPress (status, timeline, cost, warranty).
 * - Staff API (Android staff app) authenticated with a secret key: create + list repairs.
 * - Public API for the customer app: track repairs by phone number.
 */
if (!defined('ABSPATH')) {
    exit;
}

define('COOFIX_REPAIR_SETTINGS', 'coofix_repairs_settings');
// Key built into the staff app shipped with this plugin version (can be regenerated from settings).
define('COOFIX_STAFF_DEFAULT_KEY', 'nFyQljbse6TI3o41SpfE408P5CJsiEui');

function cfx_repair_statuses() {
    return array(
        'received'      => array('تم الاستلام', '#2563eb'),
        'diagnosing'    => array('قيد الفحص', '#7c3aed'),
        'waiting_parts' => array('بانتظار القطع', '#d97706'),
        'repairing'     => array('قيد الإصلاح', '#ea580c'),
        'ready'         => array('جاهزة للاستلام', '#16a34a'),
        'delivered'     => array('تم التسليم', '#0f766e'),
        'cancelled'     => array('ملغاة', '#dc2626'),
    );
}

function cfx_repair_status_label($s) {
    $all = cfx_repair_statuses();
    return isset($all[$s]) ? $all[$s][0] : $s;
}

function cfx_repair_settings() {
    $s = get_option(COOFIX_REPAIR_SETTINGS, array());
    if (!is_array($s)) {
        $s = array();
    }
    $s = wp_parse_args($s, array(
        'staff_key'  => '',
        'weekday'    => 3, // 0 = Sunday … 3 = Wednesday
        'pickup_days'=> 1, // delivery starts the next day (Thursday)
        'pickup_note'=> 'صباحاً',
        'prefix'     => 'CFX',
        'next'       => 1,
        'currency'   => 'ل.س',
        'notify_tpl' => "مرحباً {name} 👋\nطلب الصيانة رقم {code}\nالحالة: {status}\n{note}\nكوفيكس سوريا",
        'receipt_tpl'=> "مرحباً {name} 👋\nتم استلام عدّتك ({product}) للصيانة.\nرقم الطلب: {code}\nموعد الصيانة: {date}\nالتسليم ابتداءً من: {pickup}\nيمكنك متابعة الحالة من تطبيق كوفيكس سوريا برقم هاتفك.",
    ));
    if ($s['staff_key'] === '') {
        $s['staff_key'] = COOFIX_STAFF_DEFAULT_KEY;
        update_option(COOFIX_REPAIR_SETTINGS, $s, false);
    }
    return $s;
}

/** Digits only; the last 9 digits identify a Syrian mobile regardless of 0 / 963 prefix. */
function cfx_phone_key($phone) {
    // Arabic-Indic digits first, then keep digits only
    $d = strtr((string) $phone, array('٠' => '0', '١' => '1', '٢' => '2', '٣' => '3', '٤' => '4', '٥' => '5', '٦' => '6', '٧' => '7', '٨' => '8', '٩' => '9'));
    $d = preg_replace('/\D+/', '', $d);
    return strlen($d) > 9 ? substr($d, -9) : $d;
}

/** Next configured weekday after $ts (never the same day). Returns Y-m-d in site time. */
function cfx_next_service_date($ts = null) {
    $s = cfx_repair_settings();
    $tz = wp_timezone();
    $d = new DateTime('@' . ($ts ? $ts : time()));
    $d->setTimezone($tz);
    $today = intval($d->format('w'));
    $diff = (intval($s['weekday']) - $today + 7) % 7;
    if ($diff === 0) {
        $diff = 7;
    }
    $d->modify('+' . $diff . ' days');
    return $d->format('Y-m-d');
}

/** Pickup (delivery) date label: service day + N days, e.g. "الخميس 2026/11/05 صباحاً". */
function cfx_pickup_label($ymd) {
    if (!$ymd) {
        return '';
    }
    $s = cfx_repair_settings();
    $p = gmdate('Y-m-d', strtotime($ymd . ' 12:00:00') + 86400 * max(0, intval($s['pickup_days'])));
    return trim(cfx_arabic_date($p) . ' ' . $s['pickup_note']);
}

function cfx_arabic_date($ymd) {
    if (!$ymd) {
        return '';
    }
    $days = array('الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت');
    $t = strtotime($ymd . ' 12:00:00');
    return $days[intval(gmdate('w', $t))] . ' ' . gmdate('Y/m/d', $t);
}

function cfx_new_code() {
    $s = cfx_repair_settings();
    $n = max(1, intval($s['next']));
    // Skip any number already in use (e.g. after imports)
    do {
        $code = strtoupper($s['prefix']) . '-' . str_pad((string) $n, 4, '0', STR_PAD_LEFT);
        $n++;
    } while (cfx_repair_by_code($code));
    $s['next'] = $n;
    update_option(COOFIX_REPAIR_SETTINGS, $s, false);
    return $code;
}

function cfx_repair_by_code($code) {
    $q = get_posts(array('post_type' => 'cfx_repair', 'post_status' => 'any', 'numberposts' => 1, 'meta_key' => '_cfx_code', 'meta_value' => strtoupper(trim($code)), 'fields' => 'ids'));
    return $q ? intval($q[0]) : 0;
}

function cfx_repair_get($id) {
    $d = get_post_meta($id, '_cfx_data', true);
    if (!is_array($d)) {
        $d = array();
    }
    return wp_parse_args($d, array(
        'code' => '', 'name' => '', 'phone' => '', 'product_code' => '', 'serial' => '', 'description' => '',
        'accessories' => false, 'accessories_text' => '', 'warranty' => false, 'purchase_date' => '',
        'photos' => array(), 'warranty_photo' => 0, 'status' => 'received', 'scheduled' => '', 'cost' => '',
        'work_done' => '', 'timeline' => array(), 'created_by' => '', 'created' => 0,
    ));
}

function cfx_repair_save($id, $d) {
    $d['code'] = strtoupper($d['code']);
    update_post_meta($id, '_cfx_data', $d);
    update_post_meta($id, '_cfx_code', $d['code']);
    update_post_meta($id, '_cfx_phone', cfx_phone_key($d['phone']));
    update_post_meta($id, '_cfx_status', $d['status']);
    // Title keeps the list searchable by code, name and phone.
    remove_action('save_post_cfx_repair', 'cfx_repair_admin_save', 10);
    wp_update_post(array('ID' => $id, 'post_title' => $d['code'] . ' — ' . $d['name'] . ' — ' . $d['phone']));
    add_action('save_post_cfx_repair', 'cfx_repair_admin_save', 10, 2);
}

/* ------------------------------------------------------------------ */
/* Post type                                                           */
/* ------------------------------------------------------------------ */

add_action('init', function () {
    register_post_type('cfx_repair', array(
        'labels' => array(
            'name' => 'طلبات الصيانة', 'singular_name' => 'طلب صيانة', 'menu_name' => 'الصيانة',
            'add_new' => 'طلب جديد', 'add_new_item' => 'طلب صيانة جديد', 'edit_item' => 'تعديل طلب الصيانة',
            'search_items' => 'بحث (كود، اسم، هاتف)', 'not_found' => 'لا توجد طلبات', 'all_items' => 'طلبات الصيانة',
        ),
        'public'       => false,
        'show_ui'      => true,
        'show_in_menu' => 'coofix-app',
        'supports'     => false,
        'capability_type' => 'post',
        'map_meta_cap' => true,
    ));
});

/* ------------------------------------------------------------------ */
/* Admin: list table                                                   */
/* ------------------------------------------------------------------ */

add_filter('manage_cfx_repair_posts_columns', function () {
    return array(
        'cb'       => '<input type="checkbox">',
        'cfx_code' => 'الكود',
        'cfx_cust' => 'الزبون',
        'cfx_prod' => 'المنتج',
        'cfx_stat' => 'الحالة',
        'cfx_date' => 'الصيانة / التسليم',
        'cfx_war'  => 'الكفالة',
        'cfx_cost' => 'التكلفة',
    );
});

add_action('manage_cfx_repair_posts_custom_column', function ($col, $id) {
    $d = cfx_repair_get($id);
    $st = cfx_repair_statuses();
    switch ($col) {
        case 'cfx_code':
            echo '<a class="row-title" href="' . esc_url(get_edit_post_link($id)) . '" dir="ltr">' . esc_html($d['code']) . '</a>';
            echo '<div class="row-actions"><span class="edit"><a href="' . esc_url(get_edit_post_link($id)) . '">تعديل</a></span></div>';
            break;
        case 'cfx_cust':
            echo '<strong>' . esc_html($d['name']) . '</strong><br><span dir="ltr" style="color:#777">' . esc_html($d['phone']) . '</span>';
            break;
        case 'cfx_prod':
            echo esc_html($d['product_code']) . ($d['serial'] ? '<br><small style="color:#777">S/N: ' . esc_html($d['serial']) . '</small>' : '');
            break;
        case 'cfx_stat':
            $c = isset($st[$d['status']]) ? $st[$d['status']][1] : '#555';
            echo '<span style="display:inline-block;padding:3px 10px;border-radius:20px;font-weight:600;font-size:12px;color:#fff;background:' . esc_attr($c) . '">' . esc_html(cfx_repair_status_label($d['status'])) . '</span>';
            break;
        case 'cfx_date':
            echo esc_html(cfx_arabic_date($d['scheduled'])) . '<br><small style="color:#16a34a">التسليم: ' . esc_html(cfx_pickup_label($d['scheduled'])) . '</small>';
            break;
        case 'cfx_war':
            echo $d['warranty'] ? '<span style="color:#16a34a;font-weight:600">✓ ضمن الكفالة</span>' : '<span style="color:#999">خارج الكفالة</span>';
            break;
        case 'cfx_cost':
            echo esc_html($d['cost']);
            break;
    }
}, 10, 2);

add_action('restrict_manage_posts', function ($type) {
    if ($type !== 'cfx_repair') {
        return;
    }
    $cur = isset($_GET['cfx_status']) ? sanitize_key($_GET['cfx_status']) : '';
    echo '<select name="cfx_status"><option value="">كل الحالات</option>';
    foreach (cfx_repair_statuses() as $k => $v) {
        echo '<option value="' . esc_attr($k) . '" ' . selected($cur, $k, false) . '>' . esc_html($v[0]) . '</option>';
    }
    echo '</select>';
});

add_action('pre_get_posts', function ($q) {
    if (!is_admin() || !$q->is_main_query() || $q->get('post_type') !== 'cfx_repair') {
        return;
    }
    if (!empty($_GET['cfx_status'])) {
        $q->set('meta_key', '_cfx_status');
        $q->set('meta_value', sanitize_key($_GET['cfx_status']));
    }
    if (!$q->get('orderby')) {
        $q->set('orderby', 'date');
        $q->set('order', 'DESC');
    }
});

add_filter('post_row_actions', function ($actions, $post) {
    if ($post->post_type === 'cfx_repair') {
        unset($actions['inline hide-if-no-js'], $actions['view']);
    }
    return $actions;
}, 10, 2);

/* ------------------------------------------------------------------ */
/* Admin: edit screen                                                  */
/* ------------------------------------------------------------------ */

add_action('add_meta_boxes_cfx_repair', function () {
    add_meta_box('cfx_repair_main', 'بيانات الطلب', 'cfx_repair_box_main', 'cfx_repair', 'normal', 'high');
    add_meta_box('cfx_repair_track', 'الحالة والتتبع', 'cfx_repair_box_track', 'cfx_repair', 'normal', 'high');
    add_meta_box('cfx_repair_photos', 'الصور', 'cfx_repair_box_photos', 'cfx_repair', 'side');
    add_meta_box('cfx_repair_notify', 'إبلاغ الزبون', 'cfx_repair_box_notify', 'cfx_repair', 'side');
});

add_action('admin_head', function () {
    $screen = function_exists('get_current_screen') ? get_current_screen() : null;
    if (!$screen || $screen->post_type !== 'cfx_repair') {
        return;
    }
    ?>
    <style>
        .cfx-r-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:14px 18px}
        .cfx-r-grid label{display:block;font-weight:600;margin-bottom:5px}
        .cfx-r-grid input[type=text],.cfx-r-grid input[type=date],.cfx-r-grid select,.cfx-r-wide textarea,.cfx-r-grid textarea{width:100%;border-radius:10px;padding:7px 10px;border:1px solid #d4d0c8}
        .cfx-r-wide{grid-column:1/-1}
        .cfx-r-code{font-size:20px;font-weight:700;letter-spacing:1px;color:#061922}
        .cfx-tl{margin:0;padding:0;list-style:none;border-right:2px solid #e6e3dd;margin-right:8px}
        .cfx-tl li{position:relative;padding:4px 18px 14px 0}
        .cfx-tl li:before{content:'';position:absolute;right:-7px;top:8px;width:12px;height:12px;border-radius:50%;background:#FAA21B;border:2px solid #fff;box-shadow:0 0 0 1px #FAA21B}
        .cfx-tl .t{color:#888;font-size:12px}
        .cfx-tl .s{font-weight:700}
        .cfx-tl .priv{color:#a00;font-size:11px}
        .cfx-photos{display:flex;flex-wrap:wrap;gap:6px}
        .cfx-photos a img{width:78px;height:78px;object-fit:cover;border-radius:10px;border:1px solid #ddd}
        #post-body-content{margin-bottom:0}
    </style>
    <?php
});

function cfx_repair_box_main($post) {
    $d = cfx_repair_get($post->ID);
    if (!$d['code']) {
        $d['scheduled'] = cfx_next_service_date();
    }
    wp_nonce_field('cfx_repair_save', 'cfx_repair_nonce');
    $f = function ($k, $label, $type = 'text', $extra = '') use ($d) {
        echo '<div class="' . ($type === 'textarea' ? 'cfx-r-wide' : '') . '"><label>' . esc_html($label) . '</label>';
        if ($type === 'textarea') {
            echo '<textarea name="cfx[' . esc_attr($k) . ']" rows="3">' . esc_textarea($d[$k]) . '</textarea>';
        } else {
            echo '<input type="' . esc_attr($type) . '" name="cfx[' . esc_attr($k) . ']" value="' . esc_attr($d[$k]) . '" ' . $extra . '>';
        }
        echo '</div>';
    };
    echo '<p class="cfx-r-code" dir="ltr">' . esc_html($d['code'] ? $d['code'] : 'سيُنشأ الكود عند الحفظ') . '</p>';
    echo '<div class="cfx-r-grid">';
    $f('name', 'اسم الزبون');
    $f('phone', 'رقم الزبون', 'text', 'dir="ltr"');
    $f('product_code', 'كود المنتج', 'text', 'dir="ltr"');
    $f('serial', 'الرقم التسلسلي (Serial)', 'text', 'dir="ltr"');
    $f('scheduled', 'موعد الصيانة', 'date');
    $f('purchase_date', 'تاريخ الشراء', 'date');
    echo '<div><label>الكفالة</label><label style="font-weight:400"><input type="checkbox" name="cfx[warranty]" value="1" ' . checked($d['warranty'], true, false) . '> ضمن الكفالة</label></div>';
    echo '<div><label>الملحقات</label><label style="font-weight:400"><input type="checkbox" name="cfx[accessories]" value="1" ' . checked($d['accessories'], true, false) . '> مع ملحقات</label></div>';
    $f('accessories_text', 'تفاصيل الملحقات');
    $f('description', 'وصف المشكلة', 'textarea');
    echo '</div>';
    if ($d['created_by']) {
        echo '<p style="color:#888">أُدخل بواسطة: ' . esc_html($d['created_by']) . ($d['created'] ? ' — ' . esc_html(wp_date('Y/m/d H:i', $d['created'])) : '') . '</p>';
    }
}

function cfx_repair_box_track($post) {
    $d = cfx_repair_get($post->ID);
    $s = cfx_repair_settings();
    echo '<div class="cfx-r-grid">';
    echo '<div><label>الحالة</label><select name="cfx[status]">';
    foreach (cfx_repair_statuses() as $k => $v) {
        echo '<option value="' . esc_attr($k) . '" ' . selected($d['status'], $k, false) . '>' . esc_html($v[0]) . '</option>';
    }
    echo '</select></div>';
    echo '<div><label>التكلفة</label><input type="text" name="cfx[cost]" value="' . esc_attr($d['cost']) . '" placeholder="مثال: 150.000 ' . esc_attr($s['currency']) . '"></div>';
    echo '<div class="cfx-r-wide"><label>ما الذي تم / القطع المستبدلة (يظهر للزبون)</label><textarea name="cfx[work_done]" rows="2" placeholder="مثال: تم تغيير قلب المحرك والفحمات">' . esc_textarea($d['work_done']) . '</textarea></div>';
    echo '<div class="cfx-r-wide"><label>إضافة ملاحظة على التتبع</label><textarea name="cfx_note" rows="2" placeholder="تُضاف للسجل مع التاريخ — مثال: تم تغيير قلب ساعة الراحة"></textarea>';
    echo '<label style="font-weight:400"><input type="checkbox" name="cfx_note_public" value="1" checked> إظهار الملاحظة للزبون في التطبيق</label></div>';
    echo '</div>';

    if ($d['timeline']) {
        echo '<h4>سجل التتبع</h4><ul class="cfx-tl">';
        foreach (array_reverse($d['timeline'], true) as $i => $t) {
            echo '<li><div class="t">' . esc_html(wp_date('Y/m/d H:i', intval($t['time']))) . (!empty($t['by']) ? ' — ' . esc_html($t['by']) : '') . '</div>';
            echo '<div class="s">' . esc_html(cfx_repair_status_label($t['status'])) . '</div>';
            if (!empty($t['note'])) {
                echo '<div>' . nl2br(esc_html($t['note'])) . (empty($t['public']) ? ' <span class="priv">(داخلية)</span>' : '') . '</div>';
            }
            echo '<label style="font-size:11px;color:#a00"><input type="checkbox" name="cfx_del_tl[]" value="' . intval($i) . '"> حذف</label></li>';
        }
        echo '</ul>';
    }
}

function cfx_repair_box_photos($post) {
    $d = cfx_repair_get($post->ID);
    echo '<div class="cfx-photos">';
    foreach ((array) $d['photos'] as $aid) {
        $u = wp_get_attachment_image_url($aid, 'thumbnail');
        if ($u) {
            echo '<a href="' . esc_url(wp_get_attachment_url($aid)) . '" target="_blank">' . '<img src="' . esc_url($u) . '" alt=""></a>';
        }
    }
    if ($d['warranty_photo']) {
        $u = wp_get_attachment_image_url($d['warranty_photo'], 'thumbnail');
        if ($u) {
            echo '<div style="width:100%"><strong>بطاقة الكفالة:</strong></div><a href="' . esc_url(wp_get_attachment_url($d['warranty_photo'])) . '" target="_blank"><img src="' . esc_url($u) . '" alt=""></a>';
        }
    }
    if (!$d['photos'] && !$d['warranty_photo']) {
        echo '<p style="color:#888">تُضاف الصور من برنامج الموظف.</p>';
    }
    echo '</div>';
}

function cfx_repair_box_notify($post) {
    $d = cfx_repair_get($post->ID);
    if (!$d['phone']) {
        echo '<p style="color:#888">احفظ الطلب أولاً.</p>';
        return;
    }
    $last = end($d['timeline']);
    $msg = cfx_repair_fill(cfx_repair_settings()['notify_tpl'], $d, $last && !empty($last['public']) ? $last['note'] : '');
    $num = preg_replace('/\D+/', '', $d['phone']);
    if (strpos($num, '0') === 0) {
        $num = '963' . substr($num, 1);
    }
    echo '<p>أرسل للزبون آخر تحديث على واتساب:</p>';
    echo '<a class="button button-primary" target="_blank" rel="noopener" href="' . esc_url('https://wa.me/' . $num . '?text=' . rawurlencode($msg)) . '">إرسال عبر واتساب</a>';
}

function cfx_repair_fill($tpl, $d, $note = '') {
    return trim(strtr($tpl, array(
        '{name}'    => $d['name'],
        '{code}'    => $d['code'],
        '{status}'  => cfx_repair_status_label($d['status']),
        '{product}' => $d['product_code'],
        '{date}'    => cfx_arabic_date($d['scheduled']),
        '{pickup}'  => cfx_pickup_label($d['scheduled']),
        '{cost}'    => $d['cost'],
        '{note}'    => $note,
    )));
}

function cfx_repair_admin_save($id, $post) {
    if (!isset($_POST['cfx_repair_nonce']) || !wp_verify_nonce($_POST['cfx_repair_nonce'], 'cfx_repair_save')) {
        return;
    }
    if (defined('DOING_AUTOSAVE') && DOING_AUTOSAVE) {
        return;
    }
    if (!current_user_can('edit_post', $id)) {
        return;
    }
    $in = isset($_POST['cfx']) && is_array($_POST['cfx']) ? wp_unslash($_POST['cfx']) : array();
    $d = cfx_repair_get($id);
    $old_status = $d['code'] ? $d['status'] : '';
    foreach (array('name', 'phone', 'product_code', 'serial', 'accessories_text', 'cost', 'scheduled', 'purchase_date') as $k) {
        if (isset($in[$k])) {
            $d[$k] = sanitize_text_field($in[$k]);
        }
    }
    foreach (array('description', 'work_done') as $k) {
        if (isset($in[$k])) {
            $d[$k] = sanitize_textarea_field($in[$k]);
        }
    }
    $d['warranty'] = !empty($in['warranty']);
    $d['accessories'] = !empty($in['accessories']);
    if (isset($in['status']) && array_key_exists($in['status'], cfx_repair_statuses())) {
        $d['status'] = $in['status'];
    }
    if (!$d['code']) {
        $d['code'] = cfx_new_code();
        $d['created'] = time();
        $d['created_by'] = wp_get_current_user()->display_name;
        if (!$d['scheduled']) {
            $d['scheduled'] = cfx_next_service_date();
        }
        $old_status = '';
    }
    // Remove ticked timeline entries
    if (!empty($_POST['cfx_del_tl']) && is_array($_POST['cfx_del_tl'])) {
        foreach (array_map('intval', $_POST['cfx_del_tl']) as $i) {
            unset($d['timeline'][$i]);
        }
        $d['timeline'] = array_values($d['timeline']);
    }
    $note = isset($_POST['cfx_note']) ? sanitize_textarea_field(wp_unslash($_POST['cfx_note'])) : '';
    if ($note !== '' || $d['status'] !== $old_status) {
        $d['timeline'][] = array(
            'time'   => time(),
            'status' => $d['status'],
            'note'   => $note,
            'public' => $note === '' ? true : !empty($_POST['cfx_note_public']),
            'by'     => wp_get_current_user()->display_name,
        );
    }
    cfx_repair_save($id, $d);
}
add_action('save_post_cfx_repair', 'cfx_repair_admin_save', 10, 2);

// Publish straight away (no drafts for repair records).
add_filter('wp_insert_post_data', function ($data) {
    if ($data['post_type'] === 'cfx_repair' && in_array($data['post_status'], array('draft', 'pending', 'auto-draft'), true) && !empty($_POST['cfx_repair_nonce'])) {
        $data['post_status'] = 'publish';
    }
    return $data;
});

/* ------------------------------------------------------------------ */
/* Admin: settings page                                                */
/* ------------------------------------------------------------------ */

add_action('admin_menu', function () {
    add_submenu_page('coofix-app', 'إعدادات الصيانة', 'إعدادات الصيانة', 'manage_options', 'coofix-repairs-settings', 'cfx_repair_settings_page');
}, 20);

function cfx_repair_settings_page() {
    if (!current_user_can('manage_options')) {
        return;
    }
    $s = cfx_repair_settings();
    if (!empty($_POST['cfx_rs_nonce']) && wp_verify_nonce($_POST['cfx_rs_nonce'], 'cfx_rs')) {
        $s['weekday'] = max(0, min(6, intval($_POST['weekday'])));
        $s['prefix'] = strtoupper(preg_replace('/[^A-Za-z0-9]/', '', wp_unslash($_POST['prefix']))) ?: 'CFX';
        $s['next'] = max(1, intval($_POST['next']));
        $s['pickup_days'] = max(0, min(14, intval($_POST['pickup_days'])));
        $s['pickup_note'] = sanitize_text_field(wp_unslash($_POST['pickup_note']));
        $s['currency'] = sanitize_text_field(wp_unslash($_POST['currency']));
        $s['notify_tpl'] = sanitize_textarea_field(wp_unslash($_POST['notify_tpl']));
        $s['receipt_tpl'] = sanitize_textarea_field(wp_unslash($_POST['receipt_tpl']));
        if (!empty($_POST['regen'])) {
            $s['staff_key'] = wp_generate_password(32, false, false);
        }
        update_option(COOFIX_REPAIR_SETTINGS, $s, false);
        echo '<div class="notice notice-success"><p>تم الحفظ.</p></div>';
    }
    $days = array('الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت');
    ?>
    <div class="wrap" dir="rtl">
        <h1>إعدادات الصيانة</h1>
        <form method="post">
            <?php wp_nonce_field('cfx_rs', 'cfx_rs_nonce'); ?>
            <table class="form-table">
                <tr><th>يوم الصيانة الدورية</th><td><select name="weekday"><?php foreach ($days as $i => $n) { echo '<option value="' . $i . '" ' . selected($s['weekday'], $i, false) . '>' . esc_html($n) . '</option>'; } ?></select>
                    <p class="description">يُحدَّد موعد كل طلب جديد على أقرب يوم قادم من هذا اليوم (إذا كان الاستلام في نفس اليوم فالموعد بعد أسبوع). الموعد القادم: <strong><?php echo esc_html(cfx_arabic_date(cfx_next_service_date())); ?></strong></p></td></tr>
                <tr><th>بدء التسليم بعد يوم الصيانة</th><td><input type="number" name="pickup_days" min="0" max="14" value="<?php echo esc_attr($s['pickup_days']); ?>" style="width:70px"> يوم &nbsp; <input type="text" name="pickup_note" value="<?php echo esc_attr($s['pickup_note']); ?>" style="width:120px" placeholder="صباحاً">
                    <p class="description">التسليم القادم: <strong><?php echo esc_html(cfx_pickup_label(cfx_next_service_date())); ?></strong></p></td></tr>
                <tr><th>بادئة الكود</th><td><input type="text" name="prefix" value="<?php echo esc_attr($s['prefix']); ?>" dir="ltr"> <span class="description">مثال: CFX ← CFX-0001</span></td></tr>
                <tr><th>الرقم التالي</th><td><input type="number" name="next" min="1" value="<?php echo esc_attr($s['next']); ?>"></td></tr>
                <tr><th>العملة</th><td><input type="text" name="currency" value="<?php echo esc_attr($s['currency']); ?>"></td></tr>
                <tr><th>رسالة الاستلام (برنامج الموظف)</th><td><textarea name="receipt_tpl" rows="5" class="large-text"><?php echo esc_textarea($s['receipt_tpl']); ?></textarea>
                    <p class="description">المتغيرات: {name} {code} {product} {date} {pickup} {status}</p></td></tr>
                <tr><th>رسالة التحديث (واتساب)</th><td><textarea name="notify_tpl" rows="5" class="large-text"><?php echo esc_textarea($s['notify_tpl']); ?></textarea>
                    <p class="description">المتغيرات: {name} {code} {status} {note} {cost} {date} {product}</p></td></tr>
                <tr><th>مفتاح برنامج الموظف</th><td><code dir="ltr" style="font-size:14px;padding:6px 10px;display:inline-block"><?php echo esc_html($s['staff_key']); ?></code>
                    <p class="description">هذا المفتاح مدمج في برنامج الموظف. توليد مفتاح جديد يوقف كل نسخ البرنامج القديمة فوراً (مثلاً عند ضياع جهاز).</p>
                    <label><input type="checkbox" name="regen" value="1"> توليد مفتاح جديد</label></td></tr>
            </table>
            <?php submit_button('حفظ'); ?>
        </form>
    </div>
    <?php
}

/* ------------------------------------------------------------------ */
/* REST API                                                            */
/* ------------------------------------------------------------------ */

function cfx_staff_auth(WP_REST_Request $r) {
    $key = $r->get_header('x-coofix-key');
    if (!$key) {
        $key = $r->get_param('key');
    }
    $s = cfx_repair_settings();
    return is_string($key) && $key !== '' && hash_equals($s['staff_key'], $key)
        ? true
        : new WP_Error('cfx_forbidden', 'مفتاح غير صالح', array('status' => 401));
}

/** Data the customer may see. */
function cfx_repair_public($id) {
    $d = cfx_repair_get($id);
    $tl = array();
    foreach ($d['timeline'] as $t) {
        if (empty($t['public'])) {
            continue;
        }
        $tl[] = array(
            'date'         => wp_date('Y/m/d H:i', intval($t['time'])),
            'status'       => $t['status'],
            'status_label' => cfx_repair_status_label($t['status']),
            'note'         => $t['note'],
        );
    }
    $name = $d['name'];
    return array(
        'code'         => $d['code'],
        'status'       => $d['status'],
        'status_label' => cfx_repair_status_label($d['status']),
        'device'       => $d['product_code'],
        'serial'       => $d['serial'],
        'customer'     => $name,
        'received_at'  => $d['created'] ? wp_date('Y/m/d', $d['created']) : get_the_date('Y/m/d', $id),
        'service_at'   => cfx_arabic_date($d['scheduled']),
        'expected_at'  => cfx_pickup_label($d['scheduled']),
        'cost'         => $d['cost'],
        'warranty'     => (bool) $d['warranty'],
        'work_done'    => $d['work_done'],
        'notes'        => $d['work_done'],
        'timeline'     => $tl,
    );
}

/** Staff list item (full data). */
function cfx_repair_staff($id) {
    $d = cfx_repair_get($id);
    $d['id'] = $id;
    $d['status_label'] = cfx_repair_status_label($d['status']);
    $d['scheduled_label'] = cfx_arabic_date($d['scheduled']);
    $d['pickup_label'] = cfx_pickup_label($d['scheduled']);
    $d['photo_urls'] = array_values(array_filter(array_map(function ($a) {
        return wp_get_attachment_image_url($a, 'medium');
    }, (array) $d['photos'])));
    $d['created_label'] = $d['created'] ? wp_date('Y/m/d H:i', $d['created']) : '';
    return $d;
}

function cfx_rate_limited($bucket, $max = 30, $window = 600) {
    $ip = isset($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : 'x';
    $k = 'cfx_rl_' . $bucket . '_' . md5($ip);
    $n = intval(get_transient($k));
    if ($n >= $max) {
        return true;
    }
    set_transient($k, $n + 1, $window);
    return false;
}

add_action('rest_api_init', function () {
    // ---- Customer: track by phone
    register_rest_route('coofix-app/v1', '/repairs', array(
        'methods'             => 'GET',
        'permission_callback' => '__return_true',
        'callback'            => function (WP_REST_Request $r) {
            if (cfx_rate_limited('pub')) {
                return new WP_REST_Response(array('items' => array(), 'error' => 'كثرة المحاولات، حاول بعد قليل'), 429);
            }
            $key = cfx_phone_key($r->get_param('phone'));
            if (strlen($key) < 7) {
                return new WP_REST_Response(array('items' => array()), 200);
            }
            $ids = get_posts(array('post_type' => 'cfx_repair', 'post_status' => 'publish', 'numberposts' => 30,
                'meta_key' => '_cfx_phone', 'meta_value' => $key, 'fields' => 'ids', 'orderby' => 'date', 'order' => 'DESC'));
            $res = new WP_REST_Response(array('items' => array_map('cfx_repair_public', $ids)), 200);
            $res->header('Cache-Control', 'no-store');
            return $res;
        },
    ));

    // ---- Staff: check key + settings
    register_rest_route('coofix-app/v1', '/staff/info', array(
        'methods'             => 'GET',
        'permission_callback' => 'cfx_staff_auth',
        'callback'            => function () {
            $s = cfx_repair_settings();
            $st = array();
            foreach (cfx_repair_statuses() as $k => $v) {
                $st[] = array('key' => $k, 'label' => $v[0], 'color' => $v[1]);
            }
            return array(
                'ok'           => true,
                'next_date'    => cfx_next_service_date(),
                'next_label'   => cfx_arabic_date(cfx_next_service_date()),
                'pickup_label' => cfx_pickup_label(cfx_next_service_date()),
                'statuses'     => $st,
                'receipt_tpl'  => $s['receipt_tpl'],
                'site_name'    => get_bloginfo('name'),
            );
        },
    ));

    // ---- Staff: list / search
    register_rest_route('coofix-app/v1', '/staff/repairs', array(
        array(
            'methods'             => 'GET',
            'permission_callback' => 'cfx_staff_auth',
            'callback'            => function (WP_REST_Request $r) {
                $args = array('post_type' => 'cfx_repair', 'post_status' => 'publish', 'posts_per_page' => 30,
                    'paged' => max(1, intval($r->get_param('page'))), 'fields' => 'ids', 'orderby' => 'date', 'order' => 'DESC');
                $q = trim((string) $r->get_param('q'));
                if ($q !== '') {
                    $args['s'] = $q;
                }
                if ($r->get_param('status')) {
                    $args['meta_key'] = '_cfx_status';
                    $args['meta_value'] = sanitize_key($r->get_param('status'));
                }
                $wq = new WP_Query($args);
                return array('items' => array_map('cfx_repair_staff', $wq->posts), 'total' => intval($wq->found_posts));
            },
        ),
        // ---- Staff: create (multipart: fields + photos[] + warranty_photo)
        array(
            'methods'             => 'POST',
            'permission_callback' => 'cfx_staff_auth',
            'callback'            => 'cfx_staff_create',
        ),
    ));
});

function cfx_staff_create(WP_REST_Request $r) {
    $p = $r->get_params();
    $name = sanitize_text_field(isset($p['name']) ? $p['name'] : '');
    $phone = sanitize_text_field(isset($p['phone']) ? $p['phone'] : '');
    if ($name === '' || strlen(cfx_phone_key($phone)) < 7) {
        return new WP_Error('cfx_invalid', 'الاسم ورقم الهاتف مطلوبان', array('status' => 400));
    }
    $id = wp_insert_post(array('post_type' => 'cfx_repair', 'post_status' => 'publish', 'post_title' => $name), true);
    if (is_wp_error($id)) {
        return $id;
    }
    $staff = sanitize_text_field(isset($p['staff']) ? $p['staff'] : '');
    $d = cfx_repair_get($id);
    $d['code'] = cfx_new_code();
    $d['name'] = $name;
    $d['phone'] = $phone;
    $d['product_code'] = sanitize_text_field(isset($p['product_code']) ? $p['product_code'] : '');
    $d['serial'] = sanitize_text_field(isset($p['serial']) ? $p['serial'] : '');
    $d['description'] = sanitize_textarea_field(isset($p['description']) ? $p['description'] : '');
    $d['accessories'] = !empty($p['accessories']) && $p['accessories'] !== 'false' && $p['accessories'] !== '0';
    $d['accessories_text'] = sanitize_text_field(isset($p['accessories_text']) ? $p['accessories_text'] : '');
    $d['warranty'] = !empty($p['warranty']) && $p['warranty'] !== 'false' && $p['warranty'] !== '0';
    $d['purchase_date'] = sanitize_text_field(isset($p['purchase_date']) ? $p['purchase_date'] : '');
    $d['status'] = 'received';
    $d['scheduled'] = cfx_next_service_date();
    $d['created'] = time();
    $d['created_by'] = $staff !== '' ? $staff : 'برنامج الصيانة';
    $d['timeline'] = array(array('time' => time(), 'status' => 'received', 'note' => '', 'public' => true, 'by' => $d['created_by']));

    // Photos
    if (file_exists(ABSPATH . 'wp-admin/includes/file.php')) { require_once ABSPATH . 'wp-admin/includes/file.php'; }
    if (file_exists(ABSPATH . 'wp-admin/includes/media.php')) { require_once ABSPATH . 'wp-admin/includes/media.php'; }
    if (file_exists(ABSPATH . 'wp-admin/includes/image.php')) { require_once ABSPATH . 'wp-admin/includes/image.php'; }
    $files = $r->get_file_params();
    $photos = array();
    foreach ($files as $field => $f) {
        $list = array();
        if (is_array($f['name'])) {
            foreach ($f['name'] as $i => $n) {
                $list[] = array('name' => $n, 'type' => $f['type'][$i], 'tmp_name' => $f['tmp_name'][$i], 'error' => $f['error'][$i], 'size' => $f['size'][$i]);
            }
        } else {
            $list[] = $f;
        }
        foreach ($list as $one) {
            if (!empty($one['error']) || empty($one['tmp_name'])) {
                continue;
            }
            $check = wp_check_filetype_and_ext($one['tmp_name'], $one['name']);
            if (empty($check['type']) || strpos($check['type'], 'image/') !== 0) {
                continue;
            }
            $aid = media_handle_sideload($one, $id, $d['code']);
            if (is_wp_error($aid)) {
                continue;
            }
            if (strpos($field, 'warranty') === 0) {
                $d['warranty_photo'] = $aid;
            } else {
                $photos[] = $aid;
            }
        }
    }
    $d['photos'] = $photos;
    cfx_repair_save($id, $d);

    $s = cfx_repair_settings();
    $out = cfx_repair_staff($id);
    $out['receipt_message'] = cfx_repair_fill($s['receipt_tpl'], $d);
    return new WP_REST_Response($out, 201);
}

/** Built-in lookup by code for /repair?code= */
add_filter('coofix_app_repair_lookup', function ($result, $code) {
    if (is_array($result)) {
        return $result;
    }
    $id = cfx_repair_by_code($code);
    return $id ? cfx_repair_public($id) : null;
}, 5, 2);
