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
      var row = document.createElement('span'); row.className = 'cfx-code-row';
      var l = document.createElement('span'); l.className = 'cfx-code-l'; l.textContent = 'كود المنتج';
      row.appendChild(l); row.appendChild(c); el.appendChild(row);
    } else { el.appendChild(c); }
    el.appendChild(n);
  });
})();
