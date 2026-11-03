<?php
/**
 * Coofix — maintenance staff accounts.
 * Technicians are normal WordPress users with the "فني صيانة" role.
 * The staff app logs in with username + password and receives a token
 * (stored hashed in user meta) that is sent in the X-Coofix-Token header.
 */

if (!defined('ABSPATH')) {
    exit;
}

define('CFX_TOKEN_DAYS', 120);

/* ------------------------------------------------------------------ */
/* Role + capability                                                   */
/* ------------------------------------------------------------------ */

add_action('init', function () {
    if (get_option('cfx_staff_role_v') !== '1') {
        remove_role('cfx_technician');
        add_role('cfx_technician', 'فني صيانة', array('read' => true, 'cfx_repairs' => true));
        $admin = get_role('administrator');
        if ($admin) {
            $admin->add_cap('cfx_repairs');
        }
        update_option('cfx_staff_role_v', '1', false);
    }
});

function cfx_is_technician_only($user) {
    return $user && in_array('cfx_technician', (array) $user->roles, true) && !user_can($user, 'edit_posts');
}

function cfx_staff_disabled($user_id) {
    return get_user_meta($user_id, '_cfx_disabled', true) === '1';
}

// Technicians use the app only — keep them out of wp-admin and hide the admin bar.
add_action('admin_init', function () {
    if (wp_doing_ajax() || !is_user_logged_in()) {
        return;
    }
    if (cfx_is_technician_only(wp_get_current_user())) {
        wp_safe_redirect(home_url('/'));
        exit;
    }
});
add_filter('show_admin_bar', function ($show) {
    return cfx_is_technician_only(wp_get_current_user()) ? false : $show;
});
add_filter('wp_authenticate_user', function ($user) {
    if ($user instanceof WP_User && cfx_staff_disabled($user->ID)) {
        return new WP_Error('cfx_disabled', 'هذا الحساب موقوف. راجع الإدارة.');
    }
    return $user;
}, 20);

/* ------------------------------------------------------------------ */
/* Tokens                                                              */
/* ------------------------------------------------------------------ */

function cfx_tokens($uid) {
    $t = get_user_meta($uid, '_cfx_tokens', true);
    return is_array($t) ? $t : array();
}

function cfx_issue_token($uid, $device = '') {
    $raw = $uid . '.' . wp_generate_password(40, false, false);
    $tokens = cfx_tokens($uid);
    $now = time();
    foreach ($tokens as $h => $t) {
        if (intval($t['exp']) < $now) {
            unset($tokens[$h]);
        }
    }
    $tokens[hash('sha256', $raw)] = array(
        'exp'     => $now + CFX_TOKEN_DAYS * DAY_IN_SECONDS,
        'created' => $now,
        'seen'    => $now,
        'device'  => mb_substr(sanitize_text_field($device), 0, 60),
    );
    if (count($tokens) > 10) {
        uasort($tokens, function ($a, $b) { return $b['seen'] - $a['seen']; });
        $tokens = array_slice($tokens, 0, 10, true);
    }
    update_user_meta($uid, '_cfx_tokens', $tokens);
    return $raw;
}

/** Returns WP_User for a valid token, or null. */
function cfx_token_user($raw) {
    if (!is_string($raw) || !preg_match('/^(\d+)\.[A-Za-z0-9]{20,}$/', $raw, $m)) {
        return null;
    }
    $user = get_user_by('id', intval($m[1]));
    if (!$user || !user_can($user, 'cfx_repairs') || cfx_staff_disabled($user->ID)) {
        return null;
    }
    $tokens = cfx_tokens($user->ID);
    $h = hash('sha256', $raw);
    if (empty($tokens[$h]) || intval($tokens[$h]['exp']) < time()) {
        return null;
    }
    if (time() - intval($tokens[$h]['seen']) > 3600) {
        $tokens[$h]['seen'] = time();
        update_user_meta($user->ID, '_cfx_tokens', $tokens);
    }
    return $user;
}

function cfx_revoke_token($raw) {
    $user = cfx_token_user($raw);
    if ($user) {
        $tokens = cfx_tokens($user->ID);
        unset($tokens[hash('sha256', $raw)]);
        update_user_meta($user->ID, '_cfx_tokens', $tokens);
    }
}

/** The technician behind the current staff request (set by cfx_staff_auth). */
function cfx_current_staff() {
    return isset($GLOBALS['cfx_staff_user']) ? $GLOBALS['cfx_staff_user'] : null;
}

function cfx_staff_payload($user) {
    return array(
        'id'       => $user->ID,
        'username' => $user->user_login,
        'name'     => $user->display_name,
        'admin'    => user_can($user, 'manage_options'),
    );
}

/* ------------------------------------------------------------------ */
/* REST: login / logout / me                                           */
/* ------------------------------------------------------------------ */

add_action('rest_api_init', function () {
    register_rest_route('coofix-app/v1', '/staff/login', array(
        'methods'             => 'POST',
        'permission_callback' => '__return_true',
        'callback'            => function (WP_REST_Request $r) {
            if (cfx_rate_limited('login', 12, 900)) {
                return new WP_Error('cfx_rate', 'محاولات كثيرة، انتظر ربع ساعة ثم حاول مجدداً', array('status' => 429));
            }
            $login = trim((string) $r->get_param('username'));
            $pass = (string) $r->get_param('password');
            if ($login === '' || $pass === '') {
                return new WP_Error('cfx_empty', 'أدخل اسم المستخدم وكلمة المرور', array('status' => 400));
            }
            if (is_email($login)) {
                $u = get_user_by('email', $login);
                if ($u) {
                    $login = $u->user_login;
                }
            }
            $user = wp_authenticate($login, $pass);
            if (is_wp_error($user)) {
                $code = $user->get_error_code();
                $msg = $code === 'cfx_disabled' ? 'هذا الحساب موقوف. راجع الإدارة.' : 'اسم المستخدم أو كلمة المرور غير صحيحة';
                return new WP_Error('cfx_login', $msg, array('status' => 401));
            }
            if (!user_can($user, 'cfx_repairs')) {
                return new WP_Error('cfx_login', 'هذا الحساب لا يملك صلاحية برنامج الصيانة', array('status' => 403));
            }
            $token = cfx_issue_token($user->ID, (string) $r->get_param('device'));
            update_user_meta($user->ID, '_cfx_last_login', time());
            return array('ok' => true, 'token' => $token, 'user' => cfx_staff_payload($user));
        },
    ));

    register_rest_route('coofix-app/v1', '/staff/logout', array(
        'methods'             => 'POST',
        'permission_callback' => '__return_true',
        'callback'            => function (WP_REST_Request $r) {
            cfx_revoke_token((string) $r->get_header('x-coofix-token'));
            return array('ok' => true);
        },
    ));

    register_rest_route('coofix-app/v1', '/staff/me', array(
        'methods'             => 'GET',
        'permission_callback' => 'cfx_staff_auth',
        'callback'            => function () {
            $u = cfx_current_staff();
            return $u ? array('ok' => true, 'user' => cfx_staff_payload($u)) : array('ok' => true, 'user' => null);
        },
    ));
});

/* ------------------------------------------------------------------ */
/* Admin: الموظفون                                                      */
/* ------------------------------------------------------------------ */

add_action('admin_menu', function () {
    add_submenu_page('edit.php?post_type=cfx_repair', 'موظفو الصيانة', 'الموظفون', 'manage_options', 'coofix-staff', 'cfx_staff_page');
}, 15);

function cfx_staff_users() {
    return get_users(array('role__in' => array('cfx_technician'), 'orderby' => 'display_name'));
}

function cfx_staff_page() {
    if (!current_user_can('manage_options')) {
        return;
    }
    $msg = '';
    $err = '';
    if (!empty($_POST['cfx_st_nonce']) && wp_verify_nonce($_POST['cfx_st_nonce'], 'cfx_st')) {
        $act = sanitize_key(wp_unslash($_POST['act'] ?? ''));
        $uid = intval($_POST['uid'] ?? 0);
        $target = $uid ? get_user_by('id', $uid) : null;
        $is_tech = $target && in_array('cfx_technician', (array) $target->roles, true);

        if ($act === 'add') {
            $login = sanitize_user(wp_unslash($_POST['login'] ?? ''), true);
            $name = sanitize_text_field(wp_unslash($_POST['name'] ?? ''));
            $pass = (string) wp_unslash($_POST['pass'] ?? '');
            if ($login === '' || strlen($pass) < 6) {
                $err = 'اسم المستخدم مطلوب (أحرف إنكليزية/أرقام) وكلمة المرور 6 أحرف على الأقل.';
            } elseif (username_exists($login)) {
                $err = 'اسم المستخدم مستخدم مسبقاً.';
            } else {
                $new = wp_insert_user(array(
                    'user_login'   => $login,
                    'user_pass'    => $pass,
                    'display_name' => $name !== '' ? $name : $login,
                    'first_name'   => $name,
                    'user_email'   => '',
                    'role'         => 'cfx_technician',
                ));
                if (is_wp_error($new)) {
                    $err = $new->get_error_message();
                } else {
                    $msg = 'تمت إضافة الموظف «' . esc_html($name ?: $login) . '». يقدر يسجّل دخول من برنامج الصيانة الآن.';
                }
            }
        } elseif ($is_tech && $act === 'pass') {
            $pass = (string) wp_unslash($_POST['pass'] ?? '');
            if (strlen($pass) < 6) {
                $err = 'كلمة المرور 6 أحرف على الأقل.';
            } else {
                wp_set_password($pass, $uid);
                delete_user_meta($uid, '_cfx_tokens');
                $msg = 'تم تغيير كلمة المرور وتسجيل خروج الموظف من كل الأجهزة.';
            }
        } elseif ($is_tech && $act === 'name') {
            $name = sanitize_text_field(wp_unslash($_POST['name'] ?? ''));
            if ($name !== '') {
                wp_update_user(array('ID' => $uid, 'display_name' => $name, 'first_name' => $name));
                $msg = 'تم تعديل الاسم.';
            }
        } elseif ($is_tech && $act === 'toggle') {
            if (cfx_staff_disabled($uid)) {
                delete_user_meta($uid, '_cfx_disabled');
                $msg = 'تم تفعيل الحساب.';
            } else {
                update_user_meta($uid, '_cfx_disabled', '1');
                delete_user_meta($uid, '_cfx_tokens');
                $msg = 'تم إيقاف الحساب وتسجيل خروجه من كل الأجهزة.';
            }
        } elseif ($is_tech && $act === 'logout') {
            delete_user_meta($uid, '_cfx_tokens');
            $msg = 'تم تسجيل خروج الموظف من كل الأجهزة.';
        } elseif ($is_tech && $act === 'delete') {
            require_once ABSPATH . 'wp-admin/includes/user.php';
            wp_delete_user($uid, get_current_user_id());
            $msg = 'تم حذف الموظف (الطلبات التي أدخلها تبقى كما هي).';
        }
    }
    $users = cfx_staff_users();
    ?>
    <div class="wrap cfx-staff" dir="rtl">
        <h1>موظفو الصيانة</h1>
        <p class="description" style="font-size:14px">كل موظف يسجّل دخول على <strong>برنامج الصيانة</strong> باسم المستخدم وكلمة المرور يلي بتعطيه ياهم. اسم الموظف بيظهر على كل طلب بيدخله. حسابات الموظفين ما بتقدر تفوت على لوحة ووردبريس. (المدير كمان بيقدر يسجّل دخول على البرنامج بحسابه.)</p>
        <?php if ($msg) { echo '<div class="notice notice-success"><p>' . $msg . '</p></div>'; } ?>
        <?php if ($err) { echo '<div class="notice notice-error"><p>' . esc_html($err) . '</p></div>'; } ?>

        <div class="cfx-card">
            <h2>إضافة موظف</h2>
            <form method="post" class="cfx-add" autocomplete="off">
                <?php wp_nonce_field('cfx_st', 'cfx_st_nonce'); ?>
                <input type="hidden" name="act" value="add">
                <label>الاسم الظاهر<input type="text" name="name" placeholder="مثلاً: أحمد"></label>
                <label>اسم المستخدم<input type="text" name="login" dir="ltr" placeholder="ahmad" required autocomplete="off"></label>
                <label>كلمة المرور<input type="text" name="pass" dir="ltr" required minlength="6" value="<?php echo esc_attr(wp_generate_password(10, false, false)); ?>" autocomplete="new-password"></label>
                <button class="button button-primary button-large">إضافة</button>
            </form>
        </div>

        <div class="cfx-card">
            <h2>الموظفون (<?php echo count($users); ?>)</h2>
            <?php if (!$users) : ?>
                <p>لا يوجد موظفون بعد. أضف أول موظف من الأعلى.</p>
            <?php else : ?>
            <table class="widefat striped">
                <thead><tr><th>الموظف</th><th>اسم المستخدم</th><th>الحالة</th><th>آخر دخول</th><th>الأجهزة</th><th>الطلبات</th><th>إجراءات</th></tr></thead>
                <tbody>
                <?php foreach ($users as $u) :
                    $off = cfx_staff_disabled($u->ID);
                    $last = intval(get_user_meta($u->ID, '_cfx_last_login', true));
                    $devs = count(array_filter(cfx_tokens($u->ID), function ($t) { return intval($t['exp']) > time(); }));
                    $cnt = count(get_posts(array('post_type' => 'cfx_repair', 'numberposts' => -1, 'fields' => 'ids', 'meta_key' => '_cfx_by', 'meta_value' => $u->ID)));
                    $form = function ($act, $label, $cls = 'button', $confirm = '') use ($u) {
                        echo '<form method="post" style="display:inline">' . wp_nonce_field('cfx_st', 'cfx_st_nonce', true, false)
                            . '<input type="hidden" name="act" value="' . esc_attr($act) . '"><input type="hidden" name="uid" value="' . intval($u->ID) . '">'
                            . '<button class="' . esc_attr($cls) . '"' . ($confirm ? ' onclick="return confirm(\'' . esc_js($confirm) . '\')"' : '') . '>' . esc_html($label) . '</button></form> ';
                    };
                    ?>
                    <tr>
                        <td><strong><?php echo esc_html($u->display_name); ?></strong></td>
                        <td dir="ltr" style="text-align:right"><code><?php echo esc_html($u->user_login); ?></code></td>
                        <td><?php echo $off ? '<span class="cfx-pill off">موقوف</span>' : '<span class="cfx-pill on">فعّال</span>'; ?></td>
                        <td><?php echo $last ? esc_html(wp_date('Y/m/d H:i', $last)) : '—'; ?></td>
                        <td><?php echo intval($devs); ?></td>
                        <td><?php echo intval($cnt); ?></td>
                        <td class="cfx-acts">
                            <details><summary class="button">تعديل</summary>
                                <form method="post"><?php wp_nonce_field('cfx_st', 'cfx_st_nonce'); ?><input type="hidden" name="act" value="name"><input type="hidden" name="uid" value="<?php echo intval($u->ID); ?>">
                                    <input type="text" name="name" value="<?php echo esc_attr($u->display_name); ?>"> <button class="button">حفظ الاسم</button></form>
                                <form method="post"><?php wp_nonce_field('cfx_st', 'cfx_st_nonce'); ?><input type="hidden" name="act" value="pass"><input type="hidden" name="uid" value="<?php echo intval($u->ID); ?>">
                                    <input type="text" name="pass" dir="ltr" minlength="6" placeholder="كلمة مرور جديدة"> <button class="button">تغيير كلمة المرور</button></form>
                            </details>
                            <?php
                            $form('toggle', $off ? 'تفعيل' : 'إيقاف');
                            if ($devs) { $form('logout', 'تسجيل خروج'); }
                            $form('delete', 'حذف', 'button cfx-del', 'حذف الموظف نهائياً؟');
                            ?>
                        </td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
            <?php endif; ?>
        </div>
    </div>
    <style>
        .cfx-staff .cfx-card{background:#fff;border:1px solid #e3e6ea;border-radius:14px;padding:6px 20px 20px;margin:18px 0;max-width:1100px}
        .cfx-staff .cfx-add{display:flex;gap:14px;flex-wrap:wrap;align-items:flex-end}
        .cfx-staff .cfx-add label{display:flex;flex-direction:column;gap:6px;font-weight:600}
        .cfx-staff .cfx-add input{min-width:200px;padding:6px 10px}
        .cfx-staff .cfx-pill{padding:3px 10px;border-radius:20px;font-size:12px;font-weight:700}
        .cfx-staff .cfx-pill.on{background:#e3f6ea;color:#16794a}.cfx-staff .cfx-pill.off{background:#fde8e8;color:#b42318}
        .cfx-staff .cfx-acts details{display:inline-block;margin-left:4px}
        .cfx-staff .cfx-acts details[open]{display:block;margin:4px 0 8px}
        .cfx-staff .cfx-acts details form{margin-top:6px}
        .cfx-staff .cfx-del{color:#b42318!important;border-color:#f1b4ae!important}
        .cfx-staff table td{vertical-align:middle}
    </style>
    <?php
}

/* ------------------------------------------------------------------ */
/* Premium wp-login.php                                                */
/* ------------------------------------------------------------------ */

// If the LoginPress plugin is active the owner already designs wp-login there — don't fight it.
function cfx_login_skin_on() {
    return !defined('LOGINPRESS_VERSION') && !class_exists('LoginPress');
}

add_filter('login_headerurl', function () { return home_url('/'); });
add_filter('login_headertext', function () { return 'كوفيكس سوريا'; });

add_action('login_enqueue_scripts', function () {
    if (!cfx_login_skin_on()) {
        return;
    }
    $logo = COOFIX_APP_URL . 'assets/icon.png';
    $cfg = function_exists('coofix_app_get_config') ? coofix_app_get_config() : array();
    if (!empty($cfg['brand']['icon_url'])) {
        $logo = $cfg['brand']['icon_url'];
    }
    wp_enqueue_style('cfx-login-font', 'https://fonts.googleapis.com/css2?family=IBM+Plex+Sans+Arabic:wght@400;500;600;700&display=swap', array(), null);
    ?>
    <style>
    :root{--ink:#061922;--ink2:#0d2a36;--amber:#FAA21B;--amber2:#ffbf4d}
    body.login{min-height:100vh;display:flex;flex-direction:column;justify-content:center;background:
        radial-gradient(1200px 600px at 85% -10%,rgba(250,162,27,.18),transparent 60%),
        radial-gradient(900px 500px at -10% 110%,rgba(250,162,27,.10),transparent 60%),
        linear-gradient(160deg,#0b2531 0%,var(--ink) 55%,#030d12 100%);
        font-family:'IBM Plex Sans Arabic',system-ui,sans-serif;color:#e9eef1;position:relative;overflow-x:hidden}
    body.login:before{content:"";position:fixed;inset:0;pointer-events:none;opacity:.07;background-image:
        url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='56' height='98' viewBox='0 0 56 98'%3E%3Cpath d='M28 66L0 50V16L28 0l28 16v34L28 66zm0 32L0 82V66l28 16 28-16v16L28 98z' fill='none' stroke='%23FAA21B' stroke-width='1'/%3E%3C/svg%3E")}
    #login{width:380px;max-width:calc(100% - 32px);padding:0;margin:auto;position:relative;z-index:1}
    .login h1 a{background:url('<?php echo esc_url($logo); ?>') center/62% no-repeat,linear-gradient(145deg,#12384a,#061922);
        width:96px;height:96px;border-radius:28px;margin:0 auto 18px;box-shadow:0 0 0 1px rgba(250,162,27,.35),0 18px 50px rgba(250,162,27,.28),inset 0 1px 0 rgba(255,255,255,.08)}
    .login h1:after{content:"كوفيكس سوريا";display:block;text-align:center;font-size:22px;font-weight:700;color:#fff;letter-spacing:0}
    .login h1{margin-bottom:24px}
    .login form{background:rgba(255,255,255,.045);border:1px solid rgba(255,255,255,.09);border-radius:22px;padding:26px 24px 22px;
        box-shadow:0 30px 80px rgba(0,0,0,.45);backdrop-filter:blur(14px);-webkit-backdrop-filter:blur(14px);margin-top:0}
    .login label{color:#c9d5db;font-size:13px;font-weight:600;margin-bottom:6px}
    .login form .input,.login input[type=text],.login input[type=password],.login input[type=email]{background:rgba(3,13,18,.55);border:1px solid rgba(255,255,255,.12);
        border-radius:14px;color:#fff;font-size:16px;padding:10px 14px;min-height:50px;box-shadow:none;margin:4px 0 16px;transition:border-color .2s,box-shadow .2s}
    .login form .input:focus,.login input:focus{border-color:var(--amber);box-shadow:0 0 0 3px rgba(250,162,27,.22);outline:0}
    .login .wp-pwd{position:relative}
    .login .button.wp-hide-pw{color:#9fb2bc;height:50px;top:4px}
    .login .button.wp-hide-pw:focus{box-shadow:none;border-color:transparent}
    .login .forgetmenot{margin-top:4px}.login .forgetmenot label{color:#9fb2bc;font-weight:500}
    .login input[type=checkbox]{background:transparent;border-color:rgba(255,255,255,.3);border-radius:5px}
    .login input[type=checkbox]:checked:before{filter:hue-rotate(160deg) saturate(3)}
    .login .button-primary,.wp-core-ui .button-primary{background:linear-gradient(135deg,var(--amber2),var(--amber));border:0;color:#061922;
        font-weight:700;font-size:16px;border-radius:14px;min-height:50px;padding:0 24px;box-shadow:0 10px 28px rgba(250,162,27,.35);text-shadow:none;transition:transform .15s,box-shadow .2s}
    .login .button-primary:hover,.login .button-primary:focus{background:linear-gradient(135deg,#ffc964,var(--amber2));color:#061922;transform:translateY(-1px);box-shadow:0 14px 32px rgba(250,162,27,.45)}
    .login .submit{display:block;clear:both;padding-top:12px}.login .submit .button-primary{width:100%;float:none}
    .login #nav,.login #backtoblog{text-align:center;margin:16px 0 0;padding:0}
    .login #nav a,.login #backtoblog a,.login .privacy-policy-page-link a{color:#9fb2bc!important;font-size:13px}
    .login #nav a:hover,.login #backtoblog a:hover{color:var(--amber)!important}
    .login .message,.login .notice,.login .success,.login #login_error{background:rgba(255,255,255,.06);border:1px solid rgba(255,255,255,.1);
        border-inline-start:4px solid var(--amber);border-radius:14px;color:#e9eef1;box-shadow:none}
    .login #login_error{border-inline-start-color:#ff6b5b}
    .login #login_error a{color:var(--amber)}
    .language-switcher{display:none}
    .login .privacy-policy-page-link{margin:10px 0 0}
    .cfx-login-foot{position:relative;z-index:1;text-align:center;color:#5f7884;font-size:12px;padding:22px 0 26px}
    .cfx-login-foot b{color:var(--amber);font-weight:600}
    </style>
    <?php
});

add_action('login_footer', function () {
    if (!cfx_login_skin_on()) {
        return;
    }
    echo '<div class="cfx-login-foot">© ' . esc_html(wp_date('Y')) . ' <b>Coofix Syria</b> — عدّة بمواصفات احترافية</div>';
});

add_filter('gettext', function ($t, $text, $domain) {
    if ($domain === 'default' && did_action('login_init')) {
        if ($text === 'Username or Email Address') { return 'اسم المستخدم أو البريد'; }
        if ($text === 'Log In') { return 'تسجيل الدخول'; }
    }
    return $t;
}, 10, 3);
