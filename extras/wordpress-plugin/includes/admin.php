<?php
if (!defined('ABSPATH')) {
    exit;
}

add_action('admin_menu', function () {
    $icon = 'data:image/svg+xml;base64,' . base64_encode('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="#a7aaad" d="M12 1.5 21.1 6.75v10.5L12 22.5l-9.1-5.25V6.75L12 1.5Zm0 4.2-5.4 3.1v6.4l5.4 3.1 5.4-3.1V8.8L12 5.7Z"/></svg>');
    add_menu_page('تطبيق كوفيكس', 'تطبيق كوفيكس', 'manage_options', 'coofix-app', 'coofix_app_admin_page', $icon, 56);
});

add_action('admin_init', function () {
    register_setting('coofix_app', COOFIX_APP_OPTION, array(
        'type'              => 'array',
        'sanitize_callback' => 'coofix_app_sanitize',
        'show_in_rest'      => false,
    ));

    // Export / import / reset
    if (!current_user_can('manage_options') || empty($_REQUEST['coofix_app_tool'])) {
        return;
    }
    $tool = sanitize_key($_REQUEST['coofix_app_tool']);
    check_admin_referer('coofix_app_tool');
    if ($tool === 'export') {
        nocache_headers();
        header('Content-Type: application/json; charset=utf-8');
        header('Content-Disposition: attachment; filename=coofix-app-settings-' . gmdate('Y-m-d') . '.json');
        echo wp_json_encode(coofix_app_get_config(), JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        exit;
    }
    if ($tool === 'reset') {
        $d = coofix_app_defaults();
        $d['meta']['updated'] = time();
        update_option(COOFIX_APP_OPTION, $d, false);
        wp_safe_redirect(admin_url('admin.php?page=coofix-app&cfx_msg=reset'));
        exit;
    }
    if ($tool === 'import' && !empty($_FILES['coofix_app_file']['tmp_name'])) {
        $json = json_decode(file_get_contents($_FILES['coofix_app_file']['tmp_name']), true);
        if (is_array($json)) {
            update_option(COOFIX_APP_OPTION, coofix_app_sanitize(coofix_app_prepare_import($json)), false);
            wp_safe_redirect(admin_url('admin.php?page=coofix-app&cfx_msg=imported'));
        } else {
            wp_safe_redirect(admin_url('admin.php?page=coofix-app&cfx_msg=badfile'));
        }
        exit;
    }
});

/** Imported JSON stores booleans as true/false; the sanitizer expects form-style 0/1. */
function coofix_app_prepare_import($a) {
    foreach ($a as $k => $v) {
        if (is_bool($v)) {
            $a[$k] = $v ? '1' : '0';
        } elseif (is_array($v)) {
            $a[$k] = coofix_app_prepare_import($v);
        }
    }
    return $a;
}

add_action('admin_enqueue_scripts', function ($hook) {
    if ($hook !== 'toplevel_page_coofix-app') {
        return;
    }
    wp_enqueue_media();
    wp_enqueue_style('wp-color-picker');
    wp_enqueue_style('coofix-app-admin', COOFIX_APP_URL . 'assets/admin.css', array(), COOFIX_APP_VERSION);
    wp_enqueue_script('coofix-app-admin', COOFIX_APP_URL . 'assets/admin.js', array('jquery', 'jquery-ui-sortable', 'wp-color-picker'), COOFIX_APP_VERSION, true);
});

/* ------------------------------------------------------------------ */
/* Field helpers                                                       */
/* ------------------------------------------------------------------ */

function coofix_app_name($path) {
    $parts = explode('.', $path);
    return COOFIX_APP_OPTION . '[' . implode('][', $parts) . ']';
}

function coofix_app_val($cfg, $path) {
    foreach (explode('.', $path) as $p) {
        if (!is_array($cfg) || !array_key_exists($p, $cfg)) {
            return null;
        }
        $cfg = $cfg[$p];
    }
    return $cfg;
}

/**
 * Render one field.
 * $type: text | textarea | color | toggle | number | select | media | url
 */
function coofix_app_field($cfg, $path, $label, $type = 'text', $args = array()) {
    $name = isset($args['name']) ? $args['name'] : coofix_app_name($path);
    $val  = array_key_exists('value', $args) ? $args['value'] : coofix_app_val($cfg, $path);
    $help = isset($args['help']) ? $args['help'] : '';
    $wide = !empty($args['wide']) ? ' cfx-wide' : '';
    $id   = 'cfx_' . md5($name);
    echo '<div class="cfx-field cfx-type-' . esc_attr($type) . $wide . '">';
    if ($type !== 'toggle') {
        echo '<label for="' . esc_attr($id) . '">' . esc_html($label) . '</label>';
    }
    switch ($type) {
        case 'textarea':
            echo '<textarea id="' . esc_attr($id) . '" name="' . esc_attr($name) . '" rows="' . (isset($args['rows']) ? intval($args['rows']) : 3) . '">' . esc_textarea((string) $val) . '</textarea>';
            break;
        case 'color':
            echo '<input type="text" class="cfx-color" id="' . esc_attr($id) . '" name="' . esc_attr($name) . '" value="' . esc_attr((string) $val) . '" data-default-color="' . esc_attr((string) $val) . '">';
            break;
        case 'toggle':
            echo '<input type="hidden" name="' . esc_attr($name) . '" value="0">';
            echo '<label class="cfx-toggle"><input type="checkbox" id="' . esc_attr($id) . '" name="' . esc_attr($name) . '" value="1" ' . checked((bool) $val, true, false) . '><span class="cfx-slider"></span><span class="cfx-toggle-label">' . esc_html($label) . '</span></label>';
            break;
        case 'number':
            $step = isset($args['step']) ? $args['step'] : '1';
            echo '<input type="number" id="' . esc_attr($id) . '" step="' . esc_attr($step) . '" min="' . esc_attr(isset($args['min']) ? $args['min'] : '0') . '" name="' . esc_attr($name) . '" value="' . esc_attr((string) $val) . '">';
            break;
        case 'select':
            echo '<select id="' . esc_attr($id) . '" name="' . esc_attr($name) . '">';
            foreach ($args['options'] as $k => $l) {
                echo '<option value="' . esc_attr($k) . '" ' . selected((string) $val, (string) $k, false) . '>' . esc_html($l) . '</option>';
            }
            echo '</select>';
            break;
        case 'media':
            echo '<div class="cfx-media">';
            echo '<div class="cfx-media-preview">' . ($val ? '<img src="' . esc_url($val) . '" alt="">' : '<span>لا توجد صورة</span>') . '</div>';
            echo '<input type="url" id="' . esc_attr($id) . '" name="' . esc_attr($name) . '" value="' . esc_attr((string) $val) . '" placeholder="https://">';
            echo '<button type="button" class="button cfx-media-pick">اختر صورة</button> <button type="button" class="button-link cfx-media-clear">إزالة</button>';
            echo '</div>';
            break;
        default:
            $t = $type === 'url' ? 'url' : 'text';
            $ph = isset($args['placeholder']) ? $args['placeholder'] : '';
            $dir = !empty($args['ltr']) ? ' dir="ltr"' : '';
            echo '<input type="' . $t . '" id="' . esc_attr($id) . '" name="' . esc_attr($name) . '" value="' . esc_attr((string) $val) . '" placeholder="' . esc_attr($ph) . '"' . $dir . '>';
    }
    if ($help) {
        echo '<p class="cfx-help">' . esc_html($help) . '</p>';
    }
    echo '</div>';
}

function coofix_app_card_open($title, $desc = '', $icon = 'admin-generic') {
    echo '<div class="cfx-card"><div class="cfx-card-head"><span class="dashicons dashicons-' . esc_attr($icon) . '"></span><div><h2>' . esc_html($title) . '</h2>';
    if ($desc) {
        echo '<p>' . esc_html($desc) . '</p>';
    }
    echo '</div></div><div class="cfx-grid">';
}

function coofix_app_card_close() {
    echo '</div></div>';
}

/** Action (type + value) pair used by banners, announcement and popup. */
function coofix_app_action_fields($cfg, $base, $name_base = null, $vals = null) {
    $n = function ($k) use ($base, $name_base) {
        return $name_base ? $name_base . '[' . $k . ']' : coofix_app_name($base . '.' . $k);
    };
    $type = $vals ? $vals['action_type'] : coofix_app_val($cfg, $base . '.action_type');
    $value = $vals ? $vals['action_value'] : coofix_app_val($cfg, $base . '.action_value');
    coofix_app_field($cfg, '', 'عند الضغط', 'select', array('name' => $n('action_type'), 'value' => $type, 'options' => coofix_app_actions()));
    coofix_app_field($cfg, '', 'قيمة الإجراء', 'text', array('name' => $n('action_value'), 'value' => $value, 'help' => 'رقم القسم/المنتج، كلمة البحث، الرابط، نص الواتساب أو اسم التبويب حسب النوع.'));
}

/* ------------------------------------------------------------------ */
/* Repeater rendering                                                  */
/* ------------------------------------------------------------------ */

/**
 * $fields: [key => [label, type, args]]
 * Items are posted as option[path][i][key]. JS re-indexes on save.
 */
function coofix_app_repeater($cfg, $path, $fields, $title_key, $add_label, $opts = array()) {
    $items = coofix_app_val($cfg, $path);
    if (!is_array($items)) {
        $items = array();
    }
    $base = coofix_app_name($path);
    $fixed = !empty($opts['fixed']);
    echo '<div class="cfx-repeater' . ($fixed ? ' cfx-fixed' : '') . '" data-base="' . esc_attr($base) . '">';
    echo '<div class="cfx-items">';
    foreach ($items as $i => $item) {
        coofix_app_repeater_item($cfg, $base, $i, $item, $fields, $title_key, $opts);
    }
    echo '</div>';
    if (!$fixed) {
        echo '<script type="text/template" class="cfx-tpl">';
        $blank = array();
        foreach ($fields as $k => $f) {
            $blank[$k] = isset($f[2]['default']) ? $f[2]['default'] : ($f[1] === 'toggle' ? true : '');
        }
        ob_start();
        coofix_app_repeater_item($cfg, $base, '__i__', $blank, $fields, $title_key, $opts);
        echo str_replace('</script', '<\/script', ob_get_clean());
        echo '</script>';
        echo '<button type="button" class="button button-secondary cfx-add"><span class="dashicons dashicons-plus-alt2"></span> ' . esc_html($add_label) . '</button>';
    }
    echo '</div>';
}

function coofix_app_repeater_item($cfg, $base, $i, $item, $fields, $title_key, $opts) {
    $fixed = !empty($opts['fixed']);
    $title = isset($item[$title_key]) && $item[$title_key] !== '' ? $item[$title_key] : 'عنصر جديد';
    if (!empty($opts['title_map']) && isset($opts['title_map'][$title])) {
        $title = $opts['title_map'][$title];
    }
    echo '<div class="cfx-item">';
    echo '<div class="cfx-item-head"><span class="dashicons dashicons-menu cfx-handle" title="اسحب للترتيب"></span><strong class="cfx-item-title">' . esc_html(str_replace("\n", ' ', $title)) . '</strong>';
    echo '<span class="cfx-item-actions"><button type="button" class="button-link cfx-toggle-item">تعديل</button>';
    if (!$fixed) {
        echo ' <button type="button" class="button-link cfx-dup">نسخ</button> <button type="button" class="button-link cfx-remove">حذف</button>';
    }
    echo '</span></div><div class="cfx-item-body cfx-grid">';
    foreach ($fields as $k => $f) {
        list($label, $type) = $f;
        $args = isset($f[2]) ? $f[2] : array();
        $args['name'] = $base . '[' . $i . '][' . $k . ']';
        $args['value'] = isset($item[$k]) ? $item[$k] : '';
        if ($type === 'hidden') {
            echo '<input type="hidden" name="' . esc_attr($args['name']) . '" value="' . esc_attr((string) $args['value']) . '">';
            continue;
        }
        if ($type === 'action') {
            coofix_app_action_fields($cfg, '', $base . '[' . $i . ']', array(
                'action_type'  => isset($item['action_type']) ? $item['action_type'] : 'none',
                'action_value' => isset($item['action_value']) ? $item['action_value'] : '',
            ));
            continue;
        }
        if (!empty($args['title_input'])) {
            $args['wide'] = true;
        }
        coofix_app_field($cfg, '', $label, $type, $args);
    }
    echo '</div></div>';
}

/* ------------------------------------------------------------------ */
/* Page                                                                */
/* ------------------------------------------------------------------ */

function coofix_app_admin_page() {
    if (!current_user_can('manage_options')) {
        return;
    }
    $cfg   = coofix_app_get_config();
    $icons = coofix_app_icons();
    $tabs  = array(
        'general'    => array('عام', 'admin-home'),
        'brand'      => array('الهوية والألوان', 'art'),
        'home'       => array('الصفحة الرئيسية', 'layout'),
        'banners'    => array('البانرات', 'images-alt2'),
        'promo'      => array('الإعلانات والنوافذ', 'megaphone'),
        'categories' => array('الأقسام', 'category'),
        'products'   => array('المنتجات والأسعار', 'products'),
        'order'      => array('الطلب عبر واتساب', 'cart'),
        'contact'    => array('التواصل والروابط', 'phone'),
        'pages'      => array('الصفحات والنصوص', 'media-text'),
        'nav'        => array('التنقل', 'menu'),
        'status'     => array('الصيانة والتحديثات', 'update'),
        'tools'      => array('أدوات', 'admin-tools'),
    );
    $updated = intval(coofix_app_val($cfg, 'meta.updated'));
    $endpoint = rest_url('coofix-app/v1/config');
    ?>
    <div class="wrap cfx-wrap" dir="rtl">
        <div class="cfx-hero">
            <div class="cfx-hero-mark"><svg viewBox="0 0 24 24"><path d="M12 1.5 21.1 6.75v10.5L12 22.5l-9.1-5.25V6.75L12 1.5Z"/></svg></div>
            <div class="cfx-hero-text">
                <h1>تطبيق كوفيكس</h1>
                <p>تحكّم بكل تفاصيل التطبيق من هنا — تظهر التغييرات في التطبيق عند فتحه التالي أو عند سحب الشاشة الرئيسية للأسفل.</p>
            </div>
            <div class="cfx-hero-meta">
                <span class="cfx-pill <?php echo coofix_app_val($cfg, 'general.maintenance.enabled') ? 'is-warn' : 'is-ok'; ?>">
                    <?php echo coofix_app_val($cfg, 'general.maintenance.enabled') ? 'وضع الصيانة مفعّل' : 'التطبيق يعمل'; ?>
                </span>
                <span class="cfx-muted">آخر حفظ: <?php echo $updated ? esc_html(wp_date('Y/m/d H:i', $updated)) : '—'; ?></span>
            </div>
        </div>

        <?php if (isset($_GET['settings-updated'])) : ?>
            <div class="cfx-notice is-ok">✓ تم حفظ الإعدادات، ستظهر في التطبيق فوراً.</div>
        <?php endif; ?>
        <?php if (isset($_GET['cfx_msg'])) :
            $m = sanitize_key($_GET['cfx_msg']);
            $msgs = array('reset' => 'تمت إعادة الإعدادات الافتراضية.', 'imported' => 'تم استيراد الإعدادات بنجاح.', 'badfile' => 'الملف غير صالح.');
            if (isset($msgs[$m])) {
                echo '<div class="cfx-notice ' . ($m === 'badfile' ? 'is-warn' : 'is-ok') . '">' . esc_html($msgs[$m]) . '</div>';
            }
        endif; ?>

        <div class="cfx-layout">
            <nav class="cfx-tabs">
                <?php foreach ($tabs as $k => $t) : ?>
                    <a href="#<?php echo esc_attr($k); ?>" data-tab="<?php echo esc_attr($k); ?>"><span class="dashicons dashicons-<?php echo esc_attr($t[1]); ?>"></span><?php echo esc_html($t[0]); ?></a>
                <?php endforeach; ?>
            </nav>

            <div class="cfx-main">
            <form method="post" action="options.php" id="cfx-form">
                <?php settings_fields('coofix_app'); ?>

                <!-- عام -->
                <section class="cfx-panel" data-panel="general">
                    <?php
                    coofix_app_card_open('معلومات التطبيق', 'الاسم والنصوص الظاهرة في رأس الصفحة الرئيسية.', 'admin-home');
                    coofix_app_field($cfg, 'general.app_name', 'اسم التطبيق داخل الصفحات');
                    coofix_app_field($cfg, 'general.tagline', 'الشعار النصي');
                    coofix_app_field($cfg, 'general.welcome_small', 'نص الترحيب الصغير');
                    coofix_app_field($cfg, 'general.welcome_big', 'نص الترحيب الكبير');
                    coofix_app_field($cfg, 'general.search_hint', 'النص داخل مربع البحث', 'text', array('wide' => true));
                    coofix_app_card_close();
                    ?>
                </section>

                <!-- الهوية -->
                <section class="cfx-panel" data-panel="brand">
                    <?php
                    coofix_app_card_open('ألوان الهوية', 'تتغير ألوان التطبيق كاملاً حسب هذه القيم.', 'art');
                    coofix_app_field($cfg, 'brand.primary', 'اللون الأساسي', 'color');
                    coofix_app_field($cfg, 'brand.primary_light', 'الأساسي – فاتح', 'color');
                    coofix_app_field($cfg, 'brand.primary_deep', 'الأساسي – غامق', 'color');
                    coofix_app_field($cfg, 'brand.dark', 'اللون الداكن (الكحلي)', 'color');
                    coofix_app_field($cfg, 'brand.dark_light', 'الداكن – فاتح', 'color');
                    coofix_app_field($cfg, 'brand.background', 'لون الخلفية', 'color');
                    coofix_app_field($cfg, 'brand.text', 'لون النصوص', 'color');
                    coofix_app_field($cfg, 'brand.corner_radius', 'استدارة الزوايا (بكسل)', 'number', array('help' => 'الافتراضي 24'));
                    coofix_app_card_close();

                    coofix_app_card_open('الشعار والأيقونة', 'تظهر داخل التطبيق (أيقونة التطبيق على الشاشة الرئيسية للهاتف تتغير فقط مع نسخة جديدة).', 'format-image');
                    coofix_app_field($cfg, 'brand.icon_url', 'الأيقونة المربعة (رأس الصفحة وشاشة البداية)', 'media');
                    coofix_app_field($cfg, 'brand.logo_url', 'اللوغو العريض (صفحة من نحن)', 'media');
                    coofix_app_card_close();

                    coofix_app_card_open('شاشة البداية', '', 'welcome-view-site');
                    coofix_app_field($cfg, 'brand.splash_title', 'العنوان الكبير');
                    coofix_app_field($cfg, 'brand.splash_sub', 'العنوان الفرعي');
                    coofix_app_field($cfg, 'brand.splash_note', 'السطر الصغير');
                    coofix_app_field($cfg, 'brand.splash_seconds', 'مدة الظهور (ثوانٍ)', 'number', array('step' => '0.1'));
                    coofix_app_card_close();
                    ?>
                </section>

                <!-- الرئيسية -->
                <section class="cfx-panel" data-panel="home">
                    <?php
                    coofix_app_card_open('أقسام الصفحة الرئيسية', 'اسحب لتغيير الترتيب، فعّل أو أخفِ أي قسم، وعدّل عنوانه.', 'layout');
                    echo '<div class="cfx-wide">';
                    coofix_app_repeater($cfg, 'home.sections', array(
                        'key'      => array('', 'hidden'),
                        'enabled'  => array('ظاهر', 'toggle'),
                        'title'    => array('العنوان', 'text'),
                        'subtitle' => array('العنوان الفرعي', 'text'),
                    ), 'key', '', array('fixed' => true, 'title_map' => coofix_app_section_keys()));
                    echo '</div>';
                    coofix_app_card_close();

                    coofix_app_card_open('مميزات كوفيكس (الشريط الداكن)', '', 'awards');
                    echo '<div class="cfx-wide">';
                    coofix_app_repeater($cfg, 'pages.values', array(
                        'icon'  => array('الأيقونة', 'select', array('options' => $icons)),
                        'title' => array('العنوان', 'text'),
                        'sub'   => array('الوصف', 'text'),
                    ), 'title', 'إضافة ميزة');
                    echo '</div>';
                    coofix_app_card_close();
                    ?>
                </section>

                <!-- البانرات -->
                <section class="cfx-panel" data-panel="banners">
                    <?php
                    coofix_app_card_open('البانرات المتحركة', 'أضف أي عدد من البانرات، رتّبها بالسحب. يمكن استخدام صورة كاملة بدلاً من التصميم الجاهز.', 'images-alt2');
                    coofix_app_field($cfg, 'banner_seconds', 'مدة كل بانر (ثوانٍ)', 'number');
                    coofix_app_field($cfg, 'banner_height', 'ارتفاع البانر (بكسل)', 'number', array('help' => 'الافتراضي 196'));
                    echo '<div class="cfx-wide">';
                    coofix_app_repeater($cfg, 'banners', array(
                        'enabled'  => array('ظاهر', 'toggle', array('default' => true)),
                        'style'    => array('النمط', 'select', array('options' => array('dark' => 'داكن', 'dark2' => 'داكن 2', 'accent' => 'لون الهوية', 'light' => 'فاتح', 'image' => 'صورة فقط'))),
                        'icon'     => array('الأيقونة', 'select', array('options' => $icons, 'default' => 'bolt')),
                        'image'    => array('صورة (اختياري)', 'media'),
                        'kicker'   => array('الشارة الصغيرة', 'text'),
                        'title'    => array('العنوان (سطر جديد = Enter)', 'textarea', array('rows' => 2)),
                        'subtitle' => array('النص الصغير', 'text'),
                        'cta'      => array('نص الزر', 'text'),
                        'action'   => array('', 'action'),
                    ), 'title', 'إضافة بانر');
                    echo '</div>';
                    coofix_app_card_close();
                    ?>
                </section>

                <!-- الإعلانات -->
                <section class="cfx-panel" data-panel="promo">
                    <?php
                    coofix_app_card_open('شريط الإعلان', 'شريط ملوّن أعلى الصفحة الرئيسية.', 'megaphone');
                    coofix_app_field($cfg, 'announcement.enabled', 'إظهار الشريط', 'toggle');
                    coofix_app_field($cfg, 'announcement.text', 'النص', 'text', array('wide' => true));
                    coofix_app_field($cfg, 'announcement.bg', 'لون الخلفية', 'color');
                    coofix_app_field($cfg, 'announcement.fg', 'لون النص', 'color');
                    coofix_app_action_fields($cfg, 'announcement');
                    coofix_app_card_close();

                    coofix_app_card_open('نافذة منبثقة', 'تظهر عند فتح التطبيق — مرة واحدة لكل مستخدم ما لم تغيّر "المعرّف" أو تختر الظهور كل مرة.', 'format-status');
                    coofix_app_field($cfg, 'popup.enabled', 'تفعيل النافذة', 'toggle');
                    coofix_app_field($cfg, 'popup.every_launch', 'تظهر عند كل فتح', 'toggle');
                    coofix_app_field($cfg, 'popup.id', 'المعرّف', 'text', array('help' => 'غيّره (مثلاً offer-2) لإظهار النافذة من جديد لكل المستخدمين.', 'ltr' => true));
                    coofix_app_field($cfg, 'popup.title', 'العنوان');
                    coofix_app_field($cfg, 'popup.body', 'النص', 'textarea', array('wide' => true));
                    coofix_app_field($cfg, 'popup.image', 'صورة', 'media');
                    coofix_app_field($cfg, 'popup.button', 'نص الزر');
                    coofix_app_action_fields($cfg, 'popup');
                    coofix_app_card_close();
                    ?>
                </section>

                <!-- الأقسام -->
                <section class="cfx-panel" data-panel="categories">
                    <?php
                    coofix_app_card_open('أقسام المتجر', 'هذه أقسام WooCommerce. اسحب للترتيب، أخفِ ما لا تريده، واختر أيقونة واسماً مختصراً للتطبيق.', 'category');
                    echo '<div class="cfx-wide">';
                    $terms = taxonomy_exists('product_cat') ? get_terms(array('taxonomy' => 'product_cat', 'hide_empty' => false)) : array();
                    if (is_wp_error($terms) || empty($terms)) {
                        echo '<p class="cfx-muted">لا توجد أقسام بعد. أضف أقساماً من المنتجات ← التصنيفات.</p>';
                    } else {
                        $order = (array) coofix_app_val($cfg, 'categories.order');
                        $hidden = (array) coofix_app_val($cfg, 'categories.hidden');
                        $cicons = (array) coofix_app_val($cfg, 'categories.icons');
                        $cnames = (array) coofix_app_val($cfg, 'categories.names');
                        usort($terms, function ($a, $b) use ($order) {
                            $ia = array_search($a->term_id, $order);
                            $ib = array_search($b->term_id, $order);
                            $ia = $ia === false ? 9999 : $ia;
                            $ib = $ib === false ? 9999 : $ib;
                            return $ia === $ib ? strcmp($a->name, $b->name) : $ia - $ib;
                        });
                        echo '<div class="cfx-cats">';
                        foreach ($terms as $t) {
                            if ($t->slug === 'uncategorized') {
                                continue;
                            }
                            $id = $t->term_id;
                            echo '<div class="cfx-cat">';
                            echo '<span class="dashicons dashicons-menu cfx-handle"></span>';
                            echo '<input type="hidden" name="' . esc_attr(coofix_app_name('categories.order')) . '[]" value="' . esc_attr($id) . '">';
                            echo '<div class="cfx-cat-name"><strong>' . esc_html($t->name) . '</strong><span>#' . esc_html($id) . ' · ' . esc_html($t->count) . ' منتج</span></div>';
                            echo '<label class="cfx-mini">اسم في التطبيق<input type="text" name="' . esc_attr(coofix_app_name('categories.names')) . '[' . esc_attr($id) . ']" value="' . esc_attr(isset($cnames[$id]) ? $cnames[$id] : '') . '" placeholder="' . esc_attr($t->name) . '"></label>';
                            echo '<label class="cfx-mini">الأيقونة<select name="' . esc_attr(coofix_app_name('categories.icons')) . '[' . esc_attr($id) . ']">';
                            foreach ($icons as $k => $l) {
                                echo '<option value="' . esc_attr($k) . '" ' . selected(isset($cicons[$id]) ? $cicons[$id] : 'auto', $k, false) . '>' . esc_html($l) . '</option>';
                            }
                            echo '</select></label>';
                            echo '<label class="cfx-check"><input type="checkbox" name="' . esc_attr(coofix_app_name('categories.hidden')) . '[]" value="' . esc_attr($id) . '" ' . checked(in_array($id, $hidden), true, false) . '> إخفاء</label>';
                            echo '</div>';
                        }
                        echo '</div>';
                    }
                    echo '</div>';
                    coofix_app_field($cfg, 'categories.dark_every', 'تلوين كل قسم رقم … بالداكن', 'number', array('help' => '3 = الأول والرابع والسابع…، 0 = بدون'));
                    coofix_app_card_close();
                    ?>
                </section>

                <!-- المنتجات -->
                <section class="cfx-panel" data-panel="products">
                    <?php
                    coofix_app_card_open('عرض المنتجات', '', 'products');
                    coofix_app_field($cfg, 'products.featured_mode', 'مصدر قسم "الأكثر طلباً"', 'select', array('options' => array(
                        'featured' => 'المنتجات المميزة (نجمة WooCommerce)',
                        'manual'   => 'اختيار يدوي (أرقام المنتجات)',
                        'latest'   => 'الأحدث',
                        'sale'     => 'المخفّضة',
                        'all'      => 'كل المنتجات',
                    )));
                    coofix_app_field($cfg, 'products.featured_ids', 'أرقام المنتجات (للاختيار اليدوي)', 'text', array('value' => implode(', ', (array) coofix_app_val($cfg, 'products.featured_ids')), 'help' => 'مثال: 427, 1463, 1464', 'ltr' => true));
                    coofix_app_field($cfg, 'products.featured_count', 'عدد منتجات "الأكثر طلباً"', 'number');
                    coofix_app_field($cfg, 'products.latest_count', 'عدد منتجات "وصل حديثاً"', 'number');
                    coofix_app_field($cfg, 'products.show_out_of_stock', 'إظهار المنتجات غير المتوفرة', 'toggle');
                    coofix_app_field($cfg, 'products.allow_cart', 'تفعيل السلة والطلب', 'toggle');
                    coofix_app_card_close();

                    coofix_app_card_open('الأسعار', '', 'tag');
                    coofix_app_field($cfg, 'products.hide_prices', 'إخفاء الأسعار', 'toggle');
                    coofix_app_field($cfg, 'products.hidden_price_text', 'النص بدل السعر');
                    coofix_app_field($cfg, 'products.currency_label', 'رمز العملة', 'text', array('help' => 'اتركه فارغاً لاستخدام رمز WooCommerce'));
                    coofix_app_field($cfg, 'products.show_old_price', 'إظهار السعر القديم المشطوب', 'toggle');
                    coofix_app_field($cfg, 'products.show_discount', 'إظهار نسبة الخصم', 'toggle');
                    coofix_app_card_close();

                    coofix_app_card_open('صفحة المنتج', '', 'media-document');
                    coofix_app_field($cfg, 'products.show_sku', 'إظهار رمز المنتج', 'toggle');
                    coofix_app_field($cfg, 'products.show_specs', 'إظهار جدول المواصفات', 'toggle');
                    coofix_app_field($cfg, 'products.parse_specs_from_description', 'قراءة المواصفات من الوصف (سطر "الاسم: القيمة")', 'toggle');
                    coofix_app_field($cfg, 'products.show_related', 'إظهار منتجات مشابهة', 'toggle');
                    coofix_app_field($cfg, 'products.ask_text', 'نص زر السؤال على واتساب', 'text', array('wide' => true));
                    echo '<div class="cfx-wide"><h4 class="cfx-sub">البطاقات الثلاث (كفالة / أصلي / توصيل)</h4>';
                    coofix_app_repeater($cfg, 'products.perks', array(
                        'icon'  => array('الأيقونة', 'select', array('options' => $icons)),
                        'title' => array('العنوان', 'text'),
                        'sub'   => array('الوصف', 'text'),
                    ), 'title', 'إضافة بطاقة');
                    echo '</div>';
                    coofix_app_card_close();

                    coofix_app_card_open('المنتجات التجريبية', 'تُستخدم لملء الأقسام أثناء تجهيز المتجر.', 'admin-page');
                    coofix_app_field($cfg, 'products.use_demo', 'إظهار المنتجات التجريبية', 'toggle');
                    coofix_app_field($cfg, 'products.min_catalogue', 'إخفاؤها تلقائياً عند وصول المتجر إلى (منتج)', 'number');
                    coofix_app_card_close();
                    ?>
                </section>

                <!-- الطلب -->
                <section class="cfx-panel" data-panel="order">
                    <?php
                    coofix_app_card_open('نافذة إتمام الطلب', '', 'cart');
                    coofix_app_field($cfg, 'order.button', 'نص زر الطلب');
                    coofix_app_field($cfg, 'order.sheet_title', 'عنوان النافذة');
                    coofix_app_field($cfg, 'order.sheet_note', 'ملاحظة أسفل العنوان', 'text', array('wide' => true));
                    coofix_app_field($cfg, 'order.show_total', 'إظهار الإجمالي', 'toggle');
                    coofix_app_field($cfg, 'order.total_label', 'تسمية الإجمالي');
                    coofix_app_card_close();

                    coofix_app_card_open('الحقول المطلوبة من الزبون', '', 'id');
                    coofix_app_field($cfg, 'order.ask_name', 'حقل الاسم', 'toggle');
                    coofix_app_field($cfg, 'order.require_name', 'الاسم إلزامي', 'toggle');
                    coofix_app_field($cfg, 'order.ask_city', 'حقل المدينة', 'toggle');
                    coofix_app_field($cfg, 'order.require_city', 'المدينة إلزامية', 'toggle');
                    coofix_app_field($cfg, 'order.ask_phone', 'حقل الهاتف', 'toggle');
                    coofix_app_field($cfg, 'order.require_phone', 'الهاتف إلزامي', 'toggle');
                    coofix_app_field($cfg, 'order.ask_note', 'حقل الملاحظات', 'toggle');
                    coofix_app_card_close();

                    coofix_app_card_open('نص رسالة الواتساب', 'المنتجات والكميات تُضاف تلقائياً بين البداية والنهاية.', 'format-chat');
                    coofix_app_field($cfg, 'order.header', 'بداية الرسالة', 'textarea', array('wide' => true));
                    coofix_app_field($cfg, 'order.footer', 'نهاية الرسالة', 'textarea', array('wide' => true, 'rows' => 2));
                    coofix_app_card_close();
                    ?>
                </section>

                <!-- التواصل -->
                <section class="cfx-panel" data-panel="contact">
                    <?php
                    coofix_app_card_open('الأرقام', 'اكتب الأرقام بالصيغة الدولية بدون + (مثال 963955791888).', 'phone');
                    coofix_app_field($cfg, 'contact.whatsapp_orders', 'واتساب الطلبات', 'text', array('ltr' => true));
                    coofix_app_field($cfg, 'contact.whatsapp_support', 'واتساب الاستفسارات', 'text', array('ltr' => true));
                    coofix_app_field($cfg, 'contact.whatsapp_maintenance', 'واتساب الصيانة', 'text', array('ltr' => true));
                    coofix_app_field($cfg, 'contact.phone', 'رقم الاتصال', 'text', array('ltr' => true));
                    coofix_app_field($cfg, 'contact.email', 'البريد الإلكتروني', 'text', array('ltr' => true));
                    coofix_app_field($cfg, 'contact.hours', 'أوقات الدوام', 'text', array('placeholder' => 'السبت – الخميس، 9 ص – 6 م'));
                    coofix_app_card_close();

                    coofix_app_card_open('الروابط والعنوان', '', 'admin-links');
                    coofix_app_field($cfg, 'contact.website', 'الموقع الإلكتروني', 'url', array('ltr' => true));
                    coofix_app_field($cfg, 'contact.catalogue_url', 'رابط الكتالوج (PDF أو صفحة)', 'url', array('ltr' => true));
                    coofix_app_field($cfg, 'contact.address', 'العنوان', 'text', array('wide' => true));
                    coofix_app_field($cfg, 'contact.maps_url', 'رابط الموقع على الخريطة', 'url', array('ltr' => true));
                    coofix_app_card_close();

                    coofix_app_card_open('التواصل الاجتماعي', 'تظهر أيقونات الحسابات المعبّأة فقط.', 'share');
                    foreach (array('facebook' => 'فيسبوك', 'instagram' => 'إنستغرام', 'tiktok' => 'تيك توك', 'telegram' => 'تلغرام', 'youtube' => 'يوتيوب') as $k => $l) {
                        coofix_app_field($cfg, 'contact.socials.' . $k, $l, 'url', array('ltr' => true, 'placeholder' => 'https://'));
                    }
                    coofix_app_card_close();
                    ?>
                </section>

                <!-- الصفحات -->
                <section class="cfx-panel" data-panel="pages">
                    <?php
                    coofix_app_card_open('صفحة من نحن', '', 'info');
                    coofix_app_field($cfg, 'pages.about_title', 'العنوان');
                    coofix_app_field($cfg, 'pages.about_body', 'النص', 'textarea', array('wide' => true, 'rows' => 7));
                    coofix_app_card_close();

                    coofix_app_card_open('صفحة الكفالة', '', 'shield');
                    coofix_app_field($cfg, 'pages.warranty_title', 'العنوان');
                    echo '<div class="cfx-wide">';
                    coofix_app_repeater($cfg, 'pages.warranty_points', array(
                        'title' => array('العنوان', 'text'),
                        'body'  => array('الشرح', 'textarea', array('rows' => 2)),
                    ), 'title', 'إضافة بند');
                    echo '</div>';
                    coofix_app_card_close();

                    coofix_app_card_open('صفحة الصيانة والتجار', '', 'hammer');
                    coofix_app_field($cfg, 'pages.maintenance_title', 'عنوان صفحة الصيانة');
                    coofix_app_field($cfg, 'pages.maintenance_intro', 'نص تعريفي', 'textarea', array('wide' => true));
                    coofix_app_field($cfg, 'pages.trader_message', 'رسالة واتساب للتجار', 'textarea', array('wide' => true, 'rows' => 2));
                    coofix_app_card_close();

                    coofix_app_card_open('البحث', '', 'search');
                    coofix_app_field($cfg, 'pages.search_suggestions', 'كلمات البحث الشائعة (كل كلمة بسطر)', 'textarea', array('value' => implode("\n", (array) coofix_app_val($cfg, 'pages.search_suggestions')), 'rows' => 6));
                    coofix_app_card_close();

                    coofix_app_card_open('صفحة "المزيد"', 'اختر العناصر الظاهرة.', 'menu-alt');
                    $labels = array('maintenance' => 'طلب صيانة', 'warranty' => 'الكفالة', 'catalogue' => 'تحميل الكتالوج', 'traders' => 'للتجار', 'whatsapp' => 'واتساب', 'call' => 'اتصال مباشر', 'website' => 'الموقع الإلكتروني', 'email' => 'البريد', 'location' => 'العنوان والخريطة', 'socials' => 'التواصل الاجتماعي', 'about' => 'من نحن');
                    foreach ($labels as $k => $l) {
                        coofix_app_field($cfg, 'pages.more_items.' . $k, $l, 'toggle');
                    }
                    coofix_app_field($cfg, 'pages.footer_note', 'النص أسفل الصفحة', 'text', array('wide' => true));
                    coofix_app_card_close();
                    ?>
                </section>

                <!-- التنقل -->
                <section class="cfx-panel" data-panel="nav">
                    <?php
                    coofix_app_card_open('الشريط السفلي', '', 'menu');
                    coofix_app_field($cfg, 'nav.home', 'الرئيسية');
                    coofix_app_field($cfg, 'nav.categories', 'الأقسام');
                    coofix_app_field($cfg, 'nav.cart', 'السلة');
                    coofix_app_field($cfg, 'nav.favorites', 'المفضلة');
                    coofix_app_field($cfg, 'nav.more', 'المزيد');
                    coofix_app_field($cfg, 'nav.show_favorites', 'إظهار تبويب المفضلة', 'toggle');
                    coofix_app_card_close();
                    ?>
                </section>

                <!-- الحالة -->
                <section class="cfx-panel" data-panel="status">
                    <?php
                    coofix_app_card_open('وضع الصيانة', 'عند التفعيل تظهر للمستخدمين شاشة بدل التطبيق مع زر واتساب.', 'warning');
                    coofix_app_field($cfg, 'general.maintenance.enabled', 'تفعيل وضع الصيانة', 'toggle');
                    coofix_app_field($cfg, 'general.maintenance.title', 'العنوان');
                    coofix_app_field($cfg, 'general.maintenance.message', 'الرسالة', 'textarea', array('wide' => true));
                    coofix_app_card_close();

                    coofix_app_card_open('التحديثات', 'إذا كانت نسخة التطبيق أقدم من "أقل نسخة مسموحة" يُطلب من المستخدم التحديث.', 'update');
                    coofix_app_field($cfg, 'general.update.min_version', 'أقل نسخة مسموحة', 'text', array('ltr' => true));
                    coofix_app_field($cfg, 'general.update.latest_version', 'أحدث نسخة', 'text', array('ltr' => true, 'help' => 'إذا كانت أحدث من نسخة المستخدم يظهر تنبيه اختياري.'));
                    coofix_app_field($cfg, 'general.update.force', 'التحديث إجباري', 'toggle');
                    coofix_app_field($cfg, 'general.update.title', 'عنوان التنبيه');
                    coofix_app_field($cfg, 'general.update.message', 'نص التنبيه', 'textarea', array('wide' => true));
                    coofix_app_field($cfg, 'general.update.android_url', 'رابط نسخة أندرويد', 'url', array('ltr' => true));
                    coofix_app_field($cfg, 'general.update.ios_url', 'رابط نسخة آيفون', 'url', array('ltr' => true));
                    coofix_app_card_close();
                    ?>
                </section>

                <div class="cfx-savebar">
                    <span class="cfx-muted">التغييرات تظهر في التطبيق مباشرة بعد الحفظ.</span>
                    <button type="submit" class="button button-primary button-hero">حفظ الإعدادات</button>
                </div>
            </form>

            <!-- أدوات (خارج نموذج الحفظ) -->
            <section class="cfx-panel" data-panel="tools">
                <?php coofix_app_card_open('رابط إعدادات التطبيق', 'يقرأ التطبيق إعداداته من هذا الرابط.', 'rest-api'); ?>
                <div class="cfx-wide"><code class="cfx-code" dir="ltr"><?php echo esc_html($endpoint); ?></code>
                    <p><a class="button" target="_blank" rel="noopener" href="<?php echo esc_url($endpoint); ?>">فتح الرابط</a></p></div>
                <?php coofix_app_card_close(); ?>

                <?php coofix_app_card_open('نسخ احتياطي', 'صدّر الإعدادات كملف أو استورد ملفاً سابقاً.', 'database-export'); ?>
                <div class="cfx-wide cfx-tools">
                    <a class="button button-secondary" href="<?php echo esc_url(wp_nonce_url(admin_url('admin.php?page=coofix-app&coofix_app_tool=export'), 'coofix_app_tool')); ?>"><span class="dashicons dashicons-download"></span> تصدير الإعدادات</a>
                    <form method="post" enctype="multipart/form-data" action="<?php echo esc_url(admin_url('admin.php?page=coofix-app')); ?>">
                        <?php wp_nonce_field('coofix_app_tool'); ?>
                        <input type="hidden" name="coofix_app_tool" value="import">
                        <input type="file" name="coofix_app_file" accept=".json,application/json" required>
                        <button class="button">استيراد</button>
                    </form>
                    <a class="button cfx-danger" onclick="return confirm('إعادة كل الإعدادات للوضع الافتراضي؟');" href="<?php echo esc_url(wp_nonce_url(admin_url('admin.php?page=coofix-app&coofix_app_tool=reset'), 'coofix_app_tool')); ?>">إعادة الضبط الافتراضي</a>
                </div>
                <?php coofix_app_card_close(); ?>
            </section>
            </div>
        </div>
    </div>
    <?php
}
