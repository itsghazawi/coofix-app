/* Coofix website — hero carousel autoplay + dots (RTL safe) */
(function () {
  'use strict';
  document.querySelectorAll('.cfx-hero').forEach(function (hero) {
    var track = hero.querySelector('.cfx-hero-track');
    var slides = track ? track.children : [];
    var dots = hero.querySelectorAll('.cfx-dots i');
    if (!track || slides.length < 1) return;
    var cur = 0, timer = null, interval = parseInt(hero.getAttribute('data-interval'), 10) || 5000;

    function index() {
      var mid = track.getBoundingClientRect().left + track.clientWidth / 2, best = 0, dist = Infinity;
      for (var i = 0; i < slides.length; i++) {
        var r = slides[i].getBoundingClientRect(), d = Math.abs(r.left + r.width / 2 - mid);
        if (d < dist) { dist = d; best = i; }
      }
      return best;
    }
    function paint() {
      cur = index();
      dots.forEach(function (d, i) { d.classList.toggle('on', i === cur); });
    }
    function go(i) {
      var s = slides[(i + slides.length) % slides.length];
      var tr = track.getBoundingClientRect(), sr = s.getBoundingClientRect();
      // Works in RTL and LTR: scroll by the distance between the two centres.
      track.scrollBy({ left: (sr.left + sr.width / 2) - (tr.left + tr.width / 2), behavior: 'smooth' });
    }
    function play() {
      stop();
      if (slides.length > 1) timer = setInterval(function () { go(cur + 1); }, interval);
    }
    function stop() { if (timer) clearInterval(timer); timer = null; }

    var raf;
    track.addEventListener('scroll', function () { cancelAnimationFrame(raf); raf = requestAnimationFrame(paint); }, { passive: true });
    dots.forEach(function (d, i) { d.addEventListener('click', function () { go(i); play(); }); });
    ['pointerdown', 'touchstart', 'mouseenter'].forEach(function (e) { hero.addEventListener(e, stop, { passive: true }); });
    ['mouseleave', 'touchend'].forEach(function (e) { hero.addEventListener(e, play, { passive: true }); });
    paint();
    play();
  });

  // Small "added" feedback on app-style add buttons
  if (window.jQuery) {
    jQuery(document.body).on('added_to_cart', function (e, frag, hash, btn) {
      if (btn && btn.hasClass && btn.hasClass('cfx-add')) {
        btn.addClass('added');
        setTimeout(function () { btn.removeClass('added'); }, 1600);
      }
    });
  }
})();

/* Bottom nav: hide while scrolling down, show when scrolling up */
(function () {
  var nav = document.querySelector('.cfx-bnav');
  if (!nav) return;
  var last = window.scrollY, ticking = false;
  window.addEventListener('scroll', function () {
    if (ticking) return;
    ticking = true;
    requestAnimationFrame(function () {
      var y = window.scrollY, d = y - last;
      if (y < 80 || d < -6) nav.classList.remove('is-hidden');
      else if (d > 6) nav.classList.add('is-hidden');
      if (Math.abs(d) > 6) last = y;
      ticking = false;
    });
  }, { passive: true });
})();

/* Product page: put the specs section inside the product layout (under the image on desktop) */
(function () {
  var t = document.querySelector('.single-product .woocommerce-tabs');
  var w = document.querySelector('.single-product .product-entry-wrapper');
  if (t && w) { w.appendChild(t); t.classList.add('cfx-in-wrap'); }
})();

/* "CODE | name" titles → code chip + name (clean RTL alignment, like the app) */
(function () {
  var sel = '.woocommerce-loop-product__title a, .product_title, .cfx-card-title';
  document.querySelectorAll(sel).forEach(function (el) {
    if (el.dataset.cfxSplit) return;
    var t = (el.textContent || '').trim(), m = t.match(/^\s*([A-Za-z0-9][A-Za-z0-9\-_.\/ ]{1,24}?)\s*[|｜]\s*(.+)$/);
    if (!m) return;
    el.dataset.cfxSplit = '1';
    el.textContent = '';
    var c = document.createElement('small'); c.className = 'cfx-code'; c.dir = 'ltr'; c.textContent = m[1].trim();
    var n = document.createElement('span'); n.className = 'cfx-name'; n.textContent = m[2].trim();
    if (el.classList.contains('product_title')) {
      var row = document.createElement('button'); row.type = 'button'; row.className = 'cfx-sku'; row.title = 'نسخ الكود';
      row.innerHTML = '<span class="cfx-sku-ic"><svg viewBox="0 0 24 24" width="15" height="15"><path d="M12 2l8.66 5v10L12 22l-8.66-5V7z" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linejoin="round"/><circle cx="12" cy="12" r="3" fill="currentColor"/></svg></span>'
        + '<span class="cfx-sku-l">كود المنتج</span><span class="cfx-sku-v" dir="ltr"></span><span class="cfx-sku-ok">تم النسخ ✓</span>';
      row.querySelector('.cfx-sku-v').textContent = m[1].trim();
      row.addEventListener('click', function () {
        var v = m[1].trim();
        try { navigator.clipboard.writeText(v); } catch (e) {}
        row.classList.add('copied'); setTimeout(function () { row.classList.remove('copied'); }, 1600);
      });
      var idrow = document.querySelector('.cfx-idrow');
      if (idrow) idrow.insertBefore(row, idrow.firstChild); else el.parentNode.insertBefore(row, el);
    } else { el.appendChild(c); }
    el.appendChild(n);
  });
})();

/* Premium footer */
(function () {
  var tpl = document.getElementById('cfx-foot-tpl'), f = document.querySelector('footer.ct-footer, #footer');
  if (!tpl || !f || f.querySelector('.cfx-foot')) return;
  f.insertBefore(tpl.content.cloneNode(true), f.firstChild);
  f.classList.add('cfx-has-foot');
})();

/* Add-to-cart toast */
(function () {
  var t = document.querySelector('.cfx-toast'); if (!t) return;
  var timer;
  function show() { t.hidden = false; requestAnimationFrame(function () { t.classList.add('on'); }); clearTimeout(timer); timer = setTimeout(hide, 4500); }
  function hide() { t.classList.remove('on'); setTimeout(function () { t.hidden = true; }, 300); }
  if (window.jQuery) jQuery(document.body).on('added_to_cart', show);
  // Non-ajax add (single product page reload): Woo prints a message with a cart link.
  var msg = document.querySelector('.woocommerce-message .wc-forward, .woocommerce-message a[href*="cart"]');
  if (msg && !document.body.classList.contains('woocommerce-cart')) { var box = msg.closest('.woocommerce-message'); if (box) box.style.display = 'none'; show(); }
})();

/* WhatsApp order on the cart page — shipping info is inline; the live cart comes from the Store API */
(function () {
  // Open WhatsApp exactly once: phones → same tab (hands over to the app), computers → new tab.
  function openWA(url) {
    var touch = window.matchMedia && window.matchMedia('(pointer:coarse)').matches;
    if (touch) { location.href = url; return; }
    window.open(url, '_blank', 'noopener');
  }
  // window.cfxOrder is printed after this file (footer), so read it lazily.
  var live = null, KEY = 'cfx_ship';
  function money(v, t) {
    var mu = t.currency_minor_unit || 0, n = (parseInt(v, 10) || 0) / Math.pow(10, mu);
    var p = n.toFixed(mu).split('.'), th = t.currency_thousand_separator || ',', ds = t.currency_decimal_separator || '.';
    var s = p[0].replace(/\B(?=(\d{3})+(?!\d))/g, th) + (p[1] ? ds + p[1] : '');
    return (t.currency_prefix || '') + s + (t.currency_suffix || '');
  }
  function load() {
    fetch('/wp-json/wc/store/v1/cart', { credentials: 'same-origin', headers: { Accept: 'application/json' } })
      .then(function (r) { return r.json(); })
      .then(function (c) {
        var t = c.totals || {};
        live = {
          items: (c.items || []).map(function (it) {
            var n = it.name || '', sku = it.sku || '', m = n.match(/^\s*([A-Za-z0-9][A-Za-z0-9\-_.\/ ]{1,24}?)\s*\|\s*(.+)$/);
            if (!sku && m) { sku = m[1].trim(); n = m[2].trim(); }
            var pr = it.prices || t;
            return { n: n, s: sku, q: it.quantity, p: money(pr.price, pr), t: money((parseInt(pr.price, 10) || 0) * it.quantity, pr) };
          }),
          coupons: (c.coupons || []).map(function (x) { return String(x.code || '').toUpperCase(); }),
          sub: money(t.total_items, t),
          disc: parseInt(t.total_discount, 10) > 0 ? money(t.total_discount, t) : '',
          total: money(t.total_price, t)
        };
      }).catch(function () {});
  }
  function box() { return document.querySelector('.cfx-ship'); }
  function read() { var b = box(), o = {}; if (!b) return o; ['gov', 'area', 'name', 'phone'].forEach(function (k) { var el = b.querySelector('[name=' + k + ']'); o[k] = el ? el.value.trim() : ''; }); return o; }
  function restore() {
    var b = box(); if (!b) return; var o = {};
    try { o = JSON.parse(localStorage.getItem(KEY) || '{}'); } catch (e) {}
    Object.keys(o).forEach(function (k) { var el = b.querySelector('[name=' + k + ']'); if (el && !el.value) el.value = o[k]; });
  }
  document.addEventListener('input', function (e) { if (e.target.closest && e.target.closest('.cfx-ship')) { try { localStorage.setItem(KEY, JSON.stringify(read())); } catch (x) {} } });
  document.addEventListener('change', function (e) { if (e.target.closest && e.target.closest('.cfx-ship')) { try { localStorage.setItem(KEY, JSON.stringify(read())); } catch (x) {} } });
  if (window.jQuery) jQuery(document.body).on('updated_cart_totals applied_coupon removed_coupon updated_wc_div', function () { restore(); load(); });
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', function () { restore(); load(); }); else setTimeout(function () { restore(); load(); }, 0);
  document.addEventListener('click', function (e) {
    if (!e.target.closest('[data-cfx-order]')) return;
    e.preventDefault();
    var d = window.cfxOrder || { items: [], coupons: [], disc: '', total: '', header: '', footer: '', wa: '963955791888' };
    var v = read(), b = box(), err = b ? b.querySelector('.cfx-ship-err') : null;
    var miss = !v.gov ? 'المحافظة' : !v.area ? 'المنطقة' : !v.name ? 'الاسم الثلاثي' : !v.phone ? 'رقم الهاتف' : '';
    if (miss) {
      if (err) { err.textContent = 'الرجاء تعبئة ' + miss; err.hidden = false; }
      var el = b && b.querySelector('[name=' + ({ 'المحافظة': 'gov', 'المنطقة': 'area', 'الاسم الثلاثي': 'name', 'رقم الهاتف': 'phone' })[miss] + ']');
      if (el) { el.focus(); el.scrollIntoView({ block: 'center', behavior: 'smooth' }); }
      return;
    }
    if (err) err.hidden = true;
    var x = live || { items: d.items, coupons: d.coupons, disc: d.disc, total: d.total };
    var now = new Date(), p2 = function (n) { return String(n).padStart(2, '0'); };
    var num = 'WEB-' + String(now.getFullYear()).slice(2) + p2(now.getMonth() + 1) + p2(now.getDate()) + '-' + p2(now.getHours()) + p2(now.getMinutes()) + p2(now.getSeconds());
    var L = ['رقم الطلب: ' + num];
    if (d.header) L.push(d.header, '');
    x.items.forEach(function (it, i) {
      L.push((i + 1) + ') ' + it.n);
      if (it.s) L.push('   الرمز: ' + it.s);
      L.push(d.hide ? '   الكمية: ' + it.q : '   الكمية: ' + it.q + ' × ' + it.p);
    });
    if (!d.hide) {
      L.push('');
      if (x.disc) L.push('كود الحسم: ' + x.coupons.join('، '), 'الحسم: ' + x.disc);
      L.push('الإجمالي: ' + x.total);
    }
    L.push('', 'معلومات الشحن:', 'المحافظة: ' + v.gov, 'المنطقة: ' + v.area, 'الاسم: ' + v.name, 'الهاتف: ' + v.phone);
    if (d.footer) L.push('', d.footer);
    var btn = e.target.closest('[data-cfx-order]'), lbl = btn.querySelector('span');
    if (btn.dataset.busy) return;
    btn.dataset.busy = '1';
    if (!btn.dataset.l && lbl) btn.dataset.l = lbl.textContent;
    var touch = window.matchMedia && window.matchMedia('(pointer:coarse)').matches;
    var win = touch ? null : window.open('', '_blank'); // computers: open the tab now (popup rules)
    var url = 'https://wa.me/' + d.wa + '?text=' + encodeURIComponent(L.join('\n'));
    if (lbl) lbl.textContent = btn.dataset.l;
    delete btn.dataset.busy;
    if (win) { win.location.href = url; } else { location.href = url; }
  });
})();
