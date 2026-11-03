<?php
/**
 * Website skin — makes coofix.sy look like the Coofix mobile app.
 *  - App-style CSS on top of the Blocksy theme (header, cards, buttons, WooCommerce, footer).
 *  - [coofix_home] : homepage built from the same control-panel settings as the app.
 *  - Optional: swaps the site's front page to the app-style homepage (and back).
 * WooCommerce keeps working untouched (cart, checkout, accounts, orders).
 */
if (!defined('ABSPATH')) {
    exit;
}

function cfx_site_on() {
    $c = coofix_app_get_config();
    return !empty($c['site']['enabled']);
}

/* ------------------------------------------------------------------ */
/* Icons (Material, inline SVG)                                        */
/* ------------------------------------------------------------------ */
function cfx_svg($key, $size = 24) {
    static $p = array(
        'battery'    => 'M15.67 4H14V2h-4v2H8.33C7.6 4 7 4.6 7 5.33v15.33C7 21.4 7.6 22 8.33 22h7.33c.74 0 1.34-.6 1.34-1.33V5.33C17 4.6 16.4 4 15.67 4zM11 20v-5.5H9L13 7v5.5h2L11 20z',
        'bolt'       => 'M11 21h-1l1-7H7.5c-.58 0-.57-.32-.38-.66.19-.34.05-.08.07-.12C8.48 10.94 10.42 7.54 13 3h1l-1 7h3.5c.49 0 .56.33.47.51l-.07.15C12.96 17.55 11 21 11 21z',
        'fuel'       => 'M19.77 7.23l.01-.01-3.72-3.72L15 4.56l2.11 2.11c-.94.36-1.61 1.26-1.61 2.33 0 1.38 1.12 2.5 2.5 2.5.36 0 .69-.08 1-.21v7.21c0 .55-.45 1-1 1s-1-.45-1-1V14c0-1.1-.9-2-2-2h-1V5c0-1.1-.9-2-2-2H6c-1.1 0-2 .9-2 2v16h10v-7.5h1.5v5c0 1.38 1.12 2.5 2.5 2.5s2.5-1.12 2.5-2.5V9c0-.69-.28-1.32-.73-1.77zM12 10H6V5h6v5zm6 0c-.55 0-1-.45-1-1s.45-1 1-1 1 .45 1 1-.45 1-1 1z',
        'air'        => 'M14.5 17c0 1.65-1.35 3-3 3s-3-1.35-3-3h2c0 .55.45 1 1 1s1-.45 1-1-.45-1-1-1H2v-2h9.5c1.65 0 3 1.35 3 3zM19 6.5C19 4.57 17.43 3 15.5 3S12 4.57 12 6.5h2c0-.83.67-1.5 1.5-1.5s1.5.67 1.5 1.5S16.33 8 15.5 8H2v2h13.5c1.93 0 3.5-1.57 3.5-3.5zm-.5 4.5H2v2h16.5c.83 0 1.5.67 1.5 1.5s-.67 1.5-1.5 1.5v2c1.93 0 3.5-1.57 3.5-3.5S20.43 11 18.5 11z',
        'build'      => 'M22.7 19l-9.1-9.1c.9-2.3.4-5-1.5-6.9-2-2-5-2.4-7.4-1.3L9 6 6 9 1.6 4.7C.4 7.1.9 10.1 2.9 12.1c1.9 1.9 4.6 2.4 6.9 1.5l9.1 9.1c.4.4 1 .4 1.4 0l2.3-2.3c.5-.4.5-1.1.1-1.4z',
        'extension'  => 'M20.5 11H19V7c0-1.1-.9-2-2-2h-4V3.5C13 2.12 11.88 1 10.5 1S8 2.12 8 3.5V5H4c-1.1 0-1.99.9-1.99 2v3.8H3.5c1.49 0 2.7 1.21 2.7 2.7s-1.21 2.7-2.7 2.7H2V20c0 1.1.9 2 2 2h3.8v-1.5c0-1.49 1.21-2.7 2.7-2.7 1.49 0 2.7 1.21 2.7 2.7V22H17c1.1 0 2-.9 2-2v-4h1.5c1.38 0 2.5-1.12 2.5-2.5S21.88 11 20.5 11z',
        'verified'   => 'M23 12l-2.44-2.79.34-3.69-3.61-.82-1.89-3.2L12 2.96 8.6 1.5 6.71 4.69 3.1 5.5l.34 3.7L1 12l2.44 2.79-.34 3.7 3.61.82L8.6 22.5l3.4-1.47 3.4 1.46 1.89-3.19 3.61-.82-.34-3.69L23 12zm-12.91 4.72l-3.8-3.81 1.48-1.48 2.32 2.33 5.85-5.87 1.48 1.48-7.33 7.35z',
        'shield'     => 'M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4z',
        'handshake'  => 'M1 21h4V9H1v12zm22-11c0-1.1-.9-2-2-2h-6.31l.95-4.57.03-.32c0-.41-.17-.79-.44-1.06L14.17 1 7.59 7.59C7.22 7.95 7 8.45 7 9v10c0 1.1.9 2 2 2h9c.83 0 1.54-.5 1.84-1.22l3.02-7.05c.09-.23.14-.47.14-.73v-2z',
        'truck'      => 'M20 8h-3V4H3c-1.1 0-2 .9-2 2v11h2c0 1.66 1.34 3 3 3s3-1.34 3-3h6c0 1.66 1.34 3 3 3s3-1.34 3-3h2v-5l-3-4zM6 18.5c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5zm13.5-9l1.96 2.5H17V9.5h2.5zm-1.5 9c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5z',
        'storefront' => 'M20 4H4v2h16V4zm1 10v-2l-1-5H4l-1 5v2h1v6h10v-6h4v6h2v-6h1zm-9 4H6v-4h6v4z',
        'star'       => 'M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z',
        'chat'       => 'M20 2H4c-1.1 0-1.99.9-1.99 2L2 22l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zM6 9h12v2H6V9zm8 5H6v-2h8v2zm4-6H6V6h12v2z',
        'phone'      => 'M20.01 15.38c-1.23 0-2.42-.2-3.53-.56-.35-.12-.74-.03-1.01.24l-1.57 1.97c-2.83-1.35-5.48-3.9-6.89-6.83l1.95-1.66c.27-.28.35-.67.24-1.02-.37-1.11-.56-2.3-.56-3.53 0-.54-.45-.99-.99-.99H4.19C3.65 3 3 3.24 3 3.99 3 13.28 10.73 21 20.01 21c.71 0 .99-.63.99-1.18v-3.45c0-.54-.45-.99-.99-.99z',
        'arrow'      => 'M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z',
        'cart'       => 'M7 18c-1.1 0-1.99.9-1.99 2S5.9 22 7 22s2-.9 2-2-.9-2-2-2zM1 2v2h2l3.6 7.59-1.35 2.45c-.16.28-.25.61-.25.96 0 1.1.9 2 2 2h12v-2H7.42c-.14 0-.25-.11-.25-.25l.03-.12.9-1.63h7.45c.75 0 1.41-.41 1.75-1.03l3.58-6.49A1.003 1.003 0 0 0 20 4H5.21l-.94-2H1zm16 16c-1.1 0-1.99.9-1.99 2s.89 2 1.99 2 2-.9 2-2-.9-2-2-2z',
        'plus'       => 'M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z',
        'megaphone'  => 'M18 11v2h4v-2h-4zm-2 6.61c.96.71 2.21 1.65 3.2 2.39.4-.53.8-1.07 1.2-1.6-.99-.74-2.24-1.68-3.2-2.4-.4.54-.8 1.08-1.2 1.61zM20.4 5.6c-.4-.53-.8-1.07-1.2-1.6-.99.74-2.24 1.68-3.2 2.4.4.53.8 1.07 1.2 1.6.96-.72 2.21-1.65 3.2-2.4zM4 9c-1.1 0-2 .9-2 2v2c0 1.1.9 2 2 2h1v4h2v-4h1l5 3V6L8 9H4zm11.5 3c0-1.33-.58-2.53-1.5-3.35v6.69c.92-.81 1.5-2.01 1.5-3.34z',
    );
    $aliases = array('handyman' => 'build', 'construction' => 'build', 'support' => 'chat', 'percent' => 'star', 'gift' => 'star', 'flash' => 'bolt',
        'garden' => 'extension', 'paint' => 'build', 'water' => 'fuel', 'measure' => 'build', 'safety' => 'shield', 'home' => 'storefront',
        'clock' => 'verified', 'location' => 'storefront', 'info' => 'verified');
    if (!isset($p[$key])) {
        $key = isset($aliases[$key]) ? $aliases[$key] : 'build';
    }
    return '<svg class="cfx-i" viewBox="0 0 24 24" width="' . intval($size) . '" height="' . intval($size) . '" aria-hidden="true"><path d="' . $p[$key] . '"/></svg>';
}

function cfx_cat_icon_key($term, $cfg) {
    $over = isset($cfg['categories']['icons'][$term->term_id]) ? $cfg['categories']['icons'][$term->term_id] : '';
    if ($over && $over !== 'auto') {
        return $over;
    }
    $s = $term->slug . ' ' . $term->name;
    if (preg_match('/battery|bt\b|بطار|شحن/u', $s)) return 'battery';
    if (preg_match('/electric|كهرب/u', $s)) return 'bolt';
    if (preg_match('/fuel|وقود|بنزين/u', $s)) return 'fuel';
    if (preg_match('/air|هواء/u', $s)) return 'air';
    if (preg_match('/access|إكسس|اكسس/u', $s)) return 'extension';
    return 'build';
}

/* ------------------------------------------------------------------ */
/* Assets                                                              */
/* ------------------------------------------------------------------ */
add_action('wp_enqueue_scripts', function () {
    if (!cfx_site_on()) {
        return;
    }
    $c = coofix_app_get_config();
    $b = $c['brand'];
    wp_enqueue_style('cfx-fonts', 'https://fonts.googleapis.com/css2?family=Alexandria:wght@400;500;600;700;800&family=IBM+Plex+Sans+Arabic:wght@400;500;600;700&display=swap', array(), null);
    wp_enqueue_style('cfx-site', COOFIX_APP_URL . 'assets/site.css', array(), COOFIX_APP_VERSION);
    $vars = sprintf(':root{--cfx-amber:%s;--cfx-amber2:%s;--cfx-amber3:%s;--cfx-ink:%s;--cfx-ink2:%s;--cfx-bg:%s;--cfx-text:%s;--cfx-r:%dpx}',
        $b['primary'], $b['primary_light'], $b['primary_deep'], $b['dark'], $b['dark_light'], $b['background'], $b['text'], intval($b['corner_radius']));
    wp_add_inline_style('cfx-site', $vars);
    wp_enqueue_script('cfx-site', COOFIX_APP_URL . 'assets/site.js', array(), COOFIX_APP_VERSION, true);
    if (function_exists('WC')) {
        wp_enqueue_script('wc-add-to-cart');
    }
}, 99);

add_filter('body_class', function ($cls) {
    if (cfx_site_on()) {
        $cls[] = 'cfx-skin';
        global $post;
        if ($post && has_shortcode((string) $post->post_content, 'coofix_home')) {
            $cls[] = 'cfx-home';
        }
    }
    return $cls;
});

/* ------------------------------------------------------------------ */
/* Product card (same as the app)                                      */
/* ------------------------------------------------------------------ */
function cfx_product_card($product) {
    if (!$product) {
        return '';
    }
    $c = coofix_app_get_config();
    $hide = !empty($c['products']['hide_prices']);
    $img = $product->get_image('woocommerce_thumbnail', array('loading' => 'lazy'));
    $cats = wc_get_product_terms($product->get_id(), 'product_cat', array('fields' => 'names'));
    $cat = $cats ? $cats[0] : '';
    $name = $product->get_name();
    if (strpos($name, '|') !== false) {
        $parts = array_map('trim', explode('|', $name, 2));
        $name = $parts[1];
    }
    $pct = 0;
    if ($product->is_on_sale() && $product->get_regular_price() > 0 && $product->get_price() > 0) {
        $pct = round((1 - $product->get_price() / $product->get_regular_price()) * 100);
    }
    $o = '<div class="cfx-card">';
    $o .= '<a class="cfx-card-img" href="' . esc_url($product->get_permalink()) . '">' . $img;
    if ($pct > 0 && !$hide && !empty($c['products']['show_discount'])) {
        $o .= '<span class="cfx-badge">-' . intval($pct) . '%</span>';
    }
    $o .= '</a><div class="cfx-card-body">';
    if ($cat) {
        $o .= '<span class="cfx-card-cat">' . esc_html($cat) . '</span>';
    }
    $o .= '<a class="cfx-card-title" href="' . esc_url($product->get_permalink()) . '">' . esc_html($name) . '</a>';
    $o .= '<div class="cfx-card-foot"><div class="cfx-card-price">' . ($hide ? '<span class="cfx-ask">' . esc_html($c['products']['hidden_price_text']) . '</span>' : $product->get_price_html()) . '</div>';
    if (!empty($c['products']['allow_cart']) && $product->is_purchasable() && $product->is_in_stock() && $product->is_type('simple')) {
        $o .= '<a href="' . esc_url($product->add_to_cart_url()) . '" data-quantity="1" data-product_id="' . esc_attr($product->get_id()) . '" data-product_sku="' . esc_attr($product->get_sku()) . '" class="cfx-add add_to_cart_button ajax_add_to_cart product_type_simple" rel="nofollow" aria-label="أضف إلى السلة">' . cfx_svg('plus', 20) . '</a>';
    } else {
        $o .= '<a class="cfx-add" href="' . esc_url($product->get_permalink()) . '" aria-label="عرض المنتج">' . cfx_svg('arrow', 18) . '</a>';
    }
    $o .= '</div></div></div>';
    return $o;
}

function cfx_section_head($title, $sub = '', $link = '', $link_text = 'عرض الكل') {
    $o = '<div class="cfx-sec-head"><div><h2>' . esc_html($title) . '</h2>';
    if ($sub) {
        $o .= '<p>' . esc_html($sub) . '</p>';
    }
    $o .= '</div>';
    if ($link) {
        $o .= '<a class="cfx-more" href="' . esc_url($link) . '">' . esc_html($link_text) . ' ‹</a>';
    }
    return $o . '</div>';
}

function cfx_action_url($type, $value, $cfg) {
    $v = trim((string) $value);
    switch ($type) {
        case 'category':
            $t = is_numeric($v) ? get_term(intval($v), 'product_cat') : get_term_by('slug', $v, 'product_cat');
            return $t && !is_wp_error($t) ? get_term_link($t) : (function_exists('wc_get_page_permalink') ? wc_get_page_permalink('shop') : home_url('/'));
        case 'product':
            return get_permalink(intval($v));
        case 'search':
            return add_query_arg(array('s' => $v, 'post_type' => 'product'), home_url('/'));
        case 'tab':
            $map = array('categories' => wc_get_page_permalink('shop'), 'cart' => wc_get_cart_url(), 'more' => home_url('/'), 'favorites' => home_url('/'), 'home' => home_url('/'));
            return isset($map[$v]) ? $map[$v] : wc_get_page_permalink('shop');
        case 'whatsapp':
            return 'https://wa.me/' . preg_replace('/\D+/', '', $cfg['contact']['whatsapp_support']) . '?text=' . rawurlencode($v);
        case 'phone':
            return 'tel:+' . preg_replace('/\D+/', '', $v ? $v : $cfg['contact']['phone']);
        case 'url':
            return $v;
        case 'page':
            return $v === 'maintenance' ? home_url('/repair/') : home_url('/');
    }
    return '';
}

/* ------------------------------------------------------------------ */
/* [coofix_home]                                                       */
/* ------------------------------------------------------------------ */
add_shortcode('coofix_home', function () {
    if (!function_exists('wc_get_products')) {
        return '';
    }
    $c = coofix_app_get_config();
    $shop = wc_get_page_permalink('shop');
    $o = '<div class="cfxh" dir="rtl">';
    foreach ((array) $c['home']['sections'] as $sec) {
        if (empty($sec['enabled'])) {
            continue;
        }
        $title = isset($sec['title']) ? $sec['title'] : '';
        $sub = isset($sec['subtitle']) ? $sec['subtitle'] : '';
        switch ($sec['key']) {
            case 'announcement':
                $a = $c['announcement'];
                if (!empty($a['enabled']) && $a['text'] !== '') {
                    $u = cfx_action_url($a['action_type'], $a['action_value'], $c);
                    $o .= '<a class="cfx-ann" ' . ($u ? 'href="' . esc_url($u) . '"' : '') . ' style="background:' . esc_attr($a['bg']) . ';color:' . esc_attr($a['fg']) . '">' . cfx_svg('megaphone', 20) . '<span>' . esc_html($a['text']) . '</span></a>';
                }
                break;

            case 'hero':
                $slides = array_values(array_filter((array) $c['banners'], function ($b) {
                    return !empty($b['enabled']);
                }));
                if (!$slides) {
                    break;
                }
                $o .= '<div class="cfx-hero" data-interval="' . esc_attr(max(2, floatval($c['banner_seconds'])) * 1000) . '"><div class="cfx-hero-track">';
                foreach ($slides as $s) {
                    $u = cfx_action_url($s['action_type'], $s['action_value'], $c);
                    $style = in_array($s['style'], array('dark', 'dark2', 'accent', 'light', 'image'), true) ? $s['style'] : 'dark';
                    $bg = $s['image'] ? ' style="--img:url(' . esc_url($s['image']) . ')"' : '';
                    $o .= '<a class="cfx-slide is-' . $style . ($s['image'] ? ' has-img' : '') . '"' . ($u ? ' href="' . esc_url($u) . '"' : '') . $bg . ($u && strpos($u, 'http') === 0 && strpos($u, home_url()) !== 0 ? ' target="_blank" rel="noopener"' : '') . '>';
                    if ($style !== 'image') {
                        $o .= '<span class="cfx-slide-ghost">' . cfx_svg($s['icon'], 260) . '</span><span class="cfx-slide-ico">' . cfx_svg($s['icon'], 34) . '</span>';
                        $o .= '<span class="cfx-slide-txt">';
                        if ($s['kicker']) {
                            $o .= '<span class="cfx-kicker">' . esc_html($s['kicker']) . '</span>';
                        }
                        $o .= '<strong>' . nl2br(esc_html($s['title'])) . '</strong>';
                        $o .= '<span class="cfx-slide-foot"><span>' . esc_html($s['subtitle']) . '</span>' . ($s['cta'] ? '<em>' . esc_html($s['cta']) . '</em>' : '') . '</span></span>';
                    }
                    $o .= '</a>';
                }
                $o .= '</div>';
                if (count($slides) > 1) {
                    $o .= '<div class="cfx-dots">' . str_repeat('<i></i>', count($slides)) . '</div>';
                }
                $o .= '</div>';
                break;

            case 'categories':
                $terms = get_terms(array('taxonomy' => 'product_cat', 'hide_empty' => true));
                if (is_wp_error($terms) || !$terms) {
                    break;
                }
                $hidden = array_map('intval', (array) $c['categories']['hidden']);
                $order = array_map('intval', (array) $c['categories']['order']);
                $terms = array_values(array_filter($terms, function ($t) use ($hidden) {
                    return $t->slug !== 'uncategorized' && !in_array($t->term_id, $hidden, true);
                }));
                usort($terms, function ($a, $b) use ($order) {
                    $ia = array_search($a->term_id, $order, true);
                    $ib = array_search($b->term_id, $order, true);
                    return ($ia === false ? 999 : $ia) - ($ib === false ? 999 : $ib);
                });
                $o .= cfx_section_head($title ? $title : 'تسوّق حسب القسم', $sub, $shop, 'الكل');
                $o .= '<div class="cfx-cats">';
                foreach ($terms as $i => $t) {
                    $nm = isset($c['categories']['names'][$t->term_id]) && $c['categories']['names'][$t->term_id] !== '' ? $c['categories']['names'][$t->term_id] : $t->name;
                    $o .= '<a class="cfx-cat' . ($i === 0 ? ' is-dark' : '') . '" href="' . esc_url(get_term_link($t)) . '"><span class="cfx-cat-ico">' . cfx_svg(cfx_cat_icon_key($t, $c), 34) . '</span><span class="cfx-cat-nm">' . esc_html($nm) . '</span><span class="cfx-cat-n">' . intval($t->count) . ' منتج</span></a>';
                }
                $o .= '</div>';
                break;

            case 'deals':
                $ids = wc_get_product_ids_on_sale();
                if (!$ids) {
                    break;
                }
                $ps = wc_get_products(array('include' => $ids, 'limit' => 12, 'status' => 'publish', 'visibility' => 'catalog'));
                if (!$ps) {
                    break;
                }
                $o .= cfx_section_head($title ? $title : 'عروض حصرية', $sub, add_query_arg('orderby', 'price', $shop));
                $o .= '<div class="cfx-row">' . implode('', array_map('cfx_product_card', $ps)) . '</div>';
                break;

            case 'values':
                $vals = (array) $c['pages']['values'];
                if (!$vals) {
                    break;
                }
                $o .= '<div class="cfx-values">';
                foreach ($vals as $v) {
                    $o .= '<div class="cfx-val"><span>' . cfx_svg($v['icon'], 26) . '</span><strong>' . esc_html($v['title']) . '</strong><small>' . esc_html($v['sub']) . '</small></div>';
                }
                $o .= '</div>';
                break;

            case 'latest':
                $ps = wc_get_products(array('limit' => max(1, intval($c['products']['latest_count'])), 'orderby' => 'date', 'order' => 'DESC', 'status' => 'publish', 'visibility' => 'catalog'));
                if (!$ps) {
                    break;
                }
                $o .= cfx_section_head($title ? $title : 'وصل حديثاً', $sub, $shop);
                $o .= '<div class="cfx-row">' . implode('', array_map('cfx_product_card', $ps)) . '</div>';
                break;

            case 'featured':
                $n = max(1, intval($c['products']['featured_count']));
                $mode = $c['products']['featured_mode'];
                $args = array('limit' => $n, 'status' => 'publish', 'visibility' => 'catalog');
                if ($mode === 'manual' && $c['products']['featured_ids']) {
                    $args['include'] = array_map('intval', (array) $c['products']['featured_ids']);
                    $args['orderby'] = 'include';
                } elseif ($mode === 'sale') {
                    $args['include'] = wc_get_product_ids_on_sale() ?: array(0);
                } elseif ($mode === 'featured') {
                    $args['featured'] = true;
                } else {
                    $args['orderby'] = 'date';
                }
                $ps = wc_get_products($args);
                if (!$ps && $mode === 'featured') {
                    $ps = wc_get_products(array('limit' => $n, 'status' => 'publish', 'visibility' => 'catalog'));
                }
                if (!$ps) {
                    break;
                }
                $o .= cfx_section_head($title ? $title : 'الأكثر طلباً', $sub, $shop);
                $o .= '<div class="cfx-grid">' . implode('', array_map('cfx_product_card', $ps)) . '</div>';
                break;

            case 'maintenance':
                $o .= '<a class="cfx-maint" href="' . esc_url(home_url('/repair/')) . '"><span class="cfx-maint-ico">' . cfx_svg('build', 30) . '</span><span><strong>' . esc_html($title ? $title : 'مركز الصيانة المعتمد') . '</strong><small>' . esc_html($sub) . '</small></span><span class="cfx-maint-go">' . cfx_svg('arrow', 20) . '</span></a>';
                break;
        }
    }
    return $o . '</div>';
});

/* ------------------------------------------------------------------ */
/* Single product: perks + WhatsApp question (like the app)            */
/* ------------------------------------------------------------------ */
add_action('woocommerce_single_product_summary', function () {
    if (!cfx_site_on()) {
        return;
    }
    $c = coofix_app_get_config();
    global $product;
    $perks = (array) $c['products']['perks'];
    if ($perks) {
        echo '<div class="cfx-perks">';
        foreach ($perks as $p) {
            echo '<div><span>' . cfx_svg($p['icon'], 24) . '</span><strong>' . esc_html($p['title']) . '</strong><small>' . esc_html($p['sub']) . '</small></div>';
        }
        echo '</div>';
    }
    $num = preg_replace('/\D+/', '', $c['contact']['whatsapp_support']);
    if ($num && $product) {
        $msg = 'مرحباً، لدي استفسار عن المنتج: ' . $product->get_name();
        echo '<a class="cfx-ask-wa" target="_blank" rel="noopener" href="https://wa.me/' . esc_attr($num) . '?text=' . rawurlencode($msg) . '">' . cfx_svg('chat', 22) . '<span>' . esc_html($c['products']['ask_text']) . '</span></a>';
    }
}, 35);

/* ------------------------------------------------------------------ */
/* Front page swap (app-style homepage) — reversible from the panel    */
/* ------------------------------------------------------------------ */
function cfx_home_page_id() {
    $id = intval(get_option('cfx_home_page_id'));
    if ($id && get_post_status($id)) {
        return $id;
    }
    $id = wp_insert_post(array(
        'post_type'    => 'page',
        'post_status'  => 'publish',
        'post_title'   => 'الرئيسية',
        'post_name'    => 'coofix-home',
        'post_content' => '[coofix_home]',
    ));
    if ($id && !is_wp_error($id)) {
        update_option('cfx_home_page_id', $id, false);
        return $id;
    }
    return 0;
}

function cfx_sync_front_page() {
    $c = coofix_app_get_config();
    $want = !empty($c['site']['enabled']) && !empty($c['site']['app_home']);
    $current = intval(get_option('page_on_front'));
    if ($want) {
        $id = cfx_home_page_id();
        if ($id && $current !== $id) {
            if (get_option('show_on_front') === 'page' && $current) {
                update_option('cfx_prev_front_page', $current, false);
            }
            update_option('show_on_front', 'page');
            update_option('page_on_front', $id);
        }
    } else {
        $mine = intval(get_option('cfx_home_page_id'));
        $prev = intval(get_option('cfx_prev_front_page'));
        if ($mine && $current === $mine && $prev && get_post_status($prev)) {
            update_option('page_on_front', $prev);
        }
    }
}

add_action('update_option_' . COOFIX_APP_OPTION, 'cfx_sync_front_page', 20);
add_action('init', function () {
    if (get_option('cfx_site_synced') !== COOFIX_APP_VERSION) {
        update_option('cfx_site_synced', COOFIX_APP_VERSION, false);
        cfx_sync_front_page();
    }
}, 30);

/* ------------------------------------------------------------------ */
/* Mobile bottom navigation (same as the app)                          */
/* ------------------------------------------------------------------ */
add_action('wp_footer', function () {
    if (!cfx_site_on() || !function_exists('WC')) {
        return;
    }
    $c = coofix_app_get_config();
    if (empty($c['site']['bottom_nav'])) {
        return;
    }
    $count = WC()->cart ? WC()->cart->get_cart_contents_count() : 0;
    $is = function ($cond) {
        return $cond ? ' is-on' : '';
    };
    $items = array(
        array(home_url('/'), 'storefront', $c['nav']['home'], $is(is_front_page())),
        array(wc_get_page_permalink('shop'), 'extension', $c['nav']['categories'], $is(is_shop() || is_product_category() || is_product())),
        array(wc_get_cart_url(), 'cart', $c['nav']['cart'], $is(is_cart() || is_checkout()), true),
        array(home_url('/repair/'), 'build', 'الصيانة', $is(is_page('repair'))),
        array(wc_get_page_permalink('myaccount'), 'verified', 'حسابي', $is(is_account_page())),
    );
    $render = function ($cls) use ($items, $count) {
        $o = '';
        foreach ($items as $it) {
            $o .= '<a class="' . $cls . $it[3] . '" href="' . esc_url($it[0]) . '">' . cfx_svg($it[1], 22);
            if (!empty($it[4])) {
                $o .= '<b class="cfx-bnav-n"' . ($count ? '' : ' hidden') . '>' . intval($count) . '</b>';
            }
            $o .= '<span>' . esc_html($it[2]) . '</span></a>';
        }
        return $o;
    };
    // Mobile: floating bottom bar
    echo '<nav class="cfx-bnav" dir="rtl">' . $render('cfx-bnav-i') . '</nav>';

    // Desktop: vertical rail on the right
    $logo = $c['brand']['logo_url'] ? $c['brand']['logo_url'] : '';
    if (!$logo && function_exists('get_custom_logo') && has_custom_logo()) {
        $logo = wp_get_attachment_image_url(get_theme_mod('custom_logo'), 'medium');
    }
    $icon = $c['brand']['icon_url'] ? $c['brand']['icon_url'] : COOFIX_APP_URL . 'assets/icon.png';
    echo '<aside class="cfx-side" dir="rtl"><a class="cfx-side-logo" href="' . esc_url(home_url('/')) . '">';
    echo $logo ? '<img src="' . esc_url($logo) . '" alt="' . esc_attr(get_bloginfo('name')) . '">' : '<img class="sq" src="' . esc_url($icon) . '" alt="">';
    echo '</a><nav class="cfx-side-nav">' . $render('cfx-side-i') . '</nav>';
    $wa = preg_replace('/\D+/', '', $c['contact']['whatsapp_support']);
    if ($wa) {
        echo '<a class="cfx-side-wa" target="_blank" rel="noopener" href="https://wa.me/' . esc_attr($wa) . '">' . cfx_svg('chat', 20) . '<span>تواصل واتساب</span></a>';
    }
    echo '</aside>';
});

// Keep the cart count fresh after ajax add-to-cart.
add_filter('woocommerce_add_to_cart_fragments', function ($f) {
    $n = WC()->cart ? WC()->cart->get_cart_contents_count() : 0;
    $f['.cfx-bnav b.cfx-bnav-n'] = '<b class="cfx-bnav-n"' . ($n ? '' : ' hidden') . '>' . intval($n) . '</b>';
    $f['.cfx-side b.cfx-bnav-n'] = '<b class="cfx-bnav-n"' . ($n ? '' : ' hidden') . '>' . intval($n) . '</b>';
    return $f;
});

/* ------------------------------------------------------------------ */
/* Mobile app header (replaces the theme header on phones)             */
/* ------------------------------------------------------------------ */
add_action('wp_body_open', function () {
    if (!cfx_site_on() || !function_exists('WC')) {
        return;
    }
    $c = coofix_app_get_config();
    $icon = $c['brand']['icon_url'] ? $c['brand']['icon_url'] : COOFIX_APP_URL . 'assets/icon.png';
    $wa = preg_replace('/\D+/', '', $c['contact']['whatsapp_support']);
    $show_search = is_front_page() || is_shop() || is_product_taxonomy() || is_search();
    $title = '';
    if (!is_front_page()) {
        if (is_shop()) {
            $title = 'الأقسام';
        } elseif (is_product_category()) {
            $title = single_term_title('', false);
        } elseif (is_cart()) {
            $title = 'سلة الطلب';
        } elseif (is_checkout()) {
            $title = 'إتمام الطلب';
        } elseif (is_account_page()) {
            $title = 'حسابي';
        } elseif (is_search()) {
            $title = 'نتائج البحث';
        } elseif (is_singular() && !is_product()) {
            $title = get_the_title();
        }
    }
    echo '<div class="cfx-mhead" dir="rtl"><div class="cfx-mhead-row">';
    if (is_front_page() || !$title) {
        echo '<a class="cfx-mhead-brand" href="' . esc_url(home_url('/')) . '"><img src="' . esc_url($icon) . '" alt="" width="46" height="46"><span><small>' . esc_html($c['general']['welcome_small']) . '</small><strong>' . esc_html($c['general']['welcome_big']) . '</strong></span></a>';
    } else {
        echo '<a class="cfx-mhead-back" href="javascript:history.length>1?history.back():location.assign(\'' . esc_js(home_url('/')) . '\')" aria-label="رجوع">' . cfx_svg('arrow', 22) . '</a><strong class="cfx-mhead-title">' . esc_html($title) . '</strong>';
    }
    if ($wa) {
        echo '<a class="cfx-mhead-btn" target="_blank" rel="noopener" href="https://wa.me/' . esc_attr($wa) . '" aria-label="الدعم">' . cfx_svg('chat', 22) . '</a>';
    }
    echo '</div>';
    if ($show_search) {
        echo '<form class="cfx-mhead-search" role="search" method="get" action="' . esc_url(home_url('/')) . '"><span>' . '<svg class="cfx-i" viewBox="0 0 24 24" width="22" height="22"><path d="M15.5 14h-.79l-.28-.27A6.47 6.47 0 0 0 16 9.5 6.5 6.5 0 1 0 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z"/></svg>' . '</span><input type="search" name="s" value="' . esc_attr(get_search_query()) . '" placeholder="' . esc_attr($c['general']['search_hint']) . '"><input type="hidden" name="post_type" value="product"></form>';
    }
    echo '</div>';
}, 5);

/* ------------------------------------------------------------------ */
/* Shop page = app "الأقسام" screen: category tiles above the products */
/* ------------------------------------------------------------------ */
add_action('woocommerce_before_shop_loop', function () {
    if (!cfx_site_on() || !is_shop() || is_search() || get_query_var('paged') > 1) {
        return;
    }
    $c = coofix_app_get_config();
    $terms = get_terms(array('taxonomy' => 'product_cat', 'hide_empty' => true, 'parent' => 0));
    if (is_wp_error($terms) || !$terms) {
        return;
    }
    $hidden = array_map('intval', (array) $c['categories']['hidden']);
    $order = array_map('intval', (array) $c['categories']['order']);
    $terms = array_values(array_filter($terms, function ($t) use ($hidden) {
        return $t->slug !== 'uncategorized' && !in_array($t->term_id, $hidden, true);
    }));
    usort($terms, function ($a, $b) use ($order) {
        $ia = array_search($a->term_id, $order, true);
        $ib = array_search($b->term_id, $order, true);
        return ($ia === false ? 999 : $ia) - ($ib === false ? 999 : $ib);
    });
    $every = max(0, intval($c['categories']['dark_every']));
    echo '<div class="cfx-catlist" dir="rtl">';
    foreach ($terms as $i => $t) {
        $nm = isset($c['categories']['names'][$t->term_id]) && $c['categories']['names'][$t->term_id] !== '' ? $c['categories']['names'][$t->term_id] : $t->name;
        $dark = $every > 0 && $i % $every === 0;
        $ic = cfx_cat_icon_key($t, $c);
        echo '<a class="cfx-ctile' . ($dark ? ' is-dark' : '') . '" href="' . esc_url(get_term_link($t)) . '"><span class="cfx-ctile-ghost">' . cfx_svg($ic, 150) . '</span><span class="cfx-ctile-ico">' . cfx_svg($ic, 34) . '</span><span class="cfx-ctile-txt"><strong>' . esc_html($nm) . '</strong><small>' . intval($t->count) . ' منتج</small></span><span class="cfx-ctile-go">' . cfx_svg('arrow', 20) . '</span></a>';
    }
    echo '</div><div class="cfx-sec-head cfx-shop-head"><div><h2>كل المنتجات</h2></div></div>';
}, 5);

/* Product tabs: "المواصفات الفنية" first (opens by default), then "وصف المنتج". */
add_filter('woocommerce_product_tabs', function ($tabs) {
    if (!cfx_site_on()) {
        return $tabs;
    }
    if (isset($tabs['additional_information'])) {
        $tabs['additional_information']['title'] = 'المواصفات الفنية';
        $tabs['additional_information']['priority'] = 5;
    }
    if (isset($tabs['description'])) {
        $tabs['description']['title'] = 'وصف المنتج';
        $tabs['description']['priority'] = 10;
    }
    unset($tabs['reviews']);
    return $tabs;
}, 99);
add_filter('woocommerce_product_additional_information_heading', function ($h) { return cfx_site_on() ? 'المواصفات الفنية' : $h; });
add_filter('woocommerce_product_description_heading', function ($h) { return cfx_site_on() ? 'وصف المنتج' : $h; });

// No reviews on the website: hide star ratings too.
add_action('wp', function () {
    if (cfx_site_on()) {
        remove_action('woocommerce_single_product_summary', 'woocommerce_template_single_rating', 10);
        remove_action('woocommerce_after_shop_loop_item_title', 'woocommerce_template_loop_rating', 5);
    }
});

// Product meta (category / SKU) as app-style chips.
add_action('wp', function () {
    if (!cfx_site_on() || !is_product()) {
        return;
    }
    remove_action('woocommerce_single_product_summary', 'woocommerce_template_single_meta', 40);
    add_action('woocommerce_single_product_summary', function () {
        global $product;
        if (!$product) {
            return;
        }
        $cfg = coofix_app_get_config();
        $terms = get_the_terms($product->get_id(), 'product_cat');
        echo '<div class="cfx-meta">';
        if ($terms && !is_wp_error($terms)) {
            foreach ($terms as $t) {
                if ($t->slug === 'uncategorized') {
                    continue;
                }
                echo '<a class="cfx-meta-cat" href="' . esc_url(get_term_link($t)) . '">'
                    . '<span class="cfx-meta-ic">' . cfx_svg(cfx_cat_icon_key($t, $cfg), 20) . '</span>'
                    . '<span class="cfx-meta-tx"><small>القسم</small><b>' . esc_html($t->name) . '</b></span>'
                    . '<span class="cfx-meta-go">' . cfx_svg('arrow', 18) . '</span></a>';
            }
        }
        if ($product->get_sku()) {
            echo '<span class="cfx-meta-sku"><small>رمز المنتج</small><b dir="ltr">' . esc_html($product->get_sku()) . '</b></span>';
        }
        echo '</div>';
    }, 40);
});
