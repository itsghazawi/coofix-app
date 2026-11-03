/* Coofix — order invoice drawn on a canvas in the browser and wrapped in a one-page PDF.
   Nothing is sent to or stored on the server. */
(function () {
  'use strict';
  var HEAD = '"Alexandria", "IBM Plex Sans Arabic", sans-serif';
  var BODY = '"IBM Plex Sans Arabic", "Alexandria", sans-serif';
  var S = 1.5625; // 794 css px → 1240 px (150 dpi A4)

  function rr(c, x, y, w, h, r) {
    c.beginPath(); c.moveTo(x + r, y); c.arcTo(x + w, y, x + w, y + h, r); c.arcTo(x + w, y + h, x, y + h, r);
    c.arcTo(x, y + h, x, y, r); c.arcTo(x, y, x + w, y, r); c.closePath();
  }
  function fit(c, t, max) { t = String(t || ''); while (t.length > 2 && c.measureText(t).width > max) t = t.slice(0, -2); return t; }
  function img(src) { return new Promise(function (res) { if (!src) return res(null); var i = new Image(); i.onload = function () { res(i); }; i.onerror = function () { res(null); }; i.src = src; }); }

  /** o: {number, date, items:[{n,s,q,p,t}], sub, disc, coupons, total, hide, ship:{gov,area,name,phone}, wa, logo} */
  function draw(o) {
    var ready = document.fonts && document.fonts.ready ? document.fonts.ready : Promise.resolve();
    return Promise.all([img(o.logo), ready]).then(function (a) {
      var logo = a[0], W = 794, H = 1123, cv = document.createElement('canvas');
      cv.width = Math.round(W * S); cv.height = Math.round(H * S);
      var c = cv.getContext('2d'); c.scale(S, S); c.direction = 'rtl';
      c.fillStyle = '#fff'; c.fillRect(0, 0, W, H);
      var R = W - 48;
      // header
      c.fillStyle = '#061922'; c.fillRect(0, 0, W, 140); c.fillStyle = '#FAA21B'; c.fillRect(0, 140, W, 5);
      rr(c, R - 64, 38, 64, 64, 18); c.fillStyle = '#0F3041'; c.fill(); c.strokeStyle = 'rgba(250,162,27,.45)'; c.lineWidth = 1; c.stroke();
      if (logo) c.drawImage(logo, R - 56, 46, 48, 48);
      c.textAlign = 'right'; c.fillStyle = '#fff'; c.font = '800 24px ' + HEAD; c.fillText('كوفيكس سوريا', R - 80, 70);
      c.fillStyle = 'rgba(255,255,255,.62)'; c.font = '500 13px ' + BODY; c.fillText('الوكيل الحصري والرسمي في سوريا', R - 80, 92);
      c.textAlign = 'left'; c.fillStyle = '#FAA21B'; c.font = '700 13px ' + HEAD; c.fillText('ORDER', 48, 52);
      c.fillStyle = '#fff'; c.font = '800 26px ' + HEAD; c.direction = 'rtl'; c.textAlign = 'left'; c.fillText('طلب شراء', 48, 86);
      c.direction = 'ltr'; c.fillStyle = 'rgba(255,255,255,.62)'; c.font = '500 13px ' + BODY; c.fillText(o.number, 48, 108); c.direction = 'rtl';
      // info boxes
      var sh = o.ship || {}, gw = (W - 96 - 24) / 3, y = 172;
      [['الزبون', sh.name], ['رقم الهاتف', String(sh.phone || '').replace(/[\s\-]/g, '')], ['التاريخ', o.date]].forEach(function (b, i) {
        var x = R - (i + 1) * gw - i * 12; rr(c, x, y, gw, 62, 16); c.fillStyle = '#F4F3F0'; c.fill();
        c.textAlign = 'right'; c.fillStyle = '#6B7079'; c.font = '500 12px ' + BODY; c.fillText(b[0], x + gw - 16, y + 24);
        c.fillStyle = '#15181D'; c.font = '700 15px ' + BODY; c.fillText(fit(c, b[1] || '—', gw - 32), x + gw - 16, y + 48);
      });
      y += 74;
      var w2 = gw * 2 + 12;
      rr(c, R - w2, y, w2, 62, 16); c.fillStyle = '#F4F3F0'; c.fill();
      c.fillStyle = '#6B7079'; c.font = '500 12px ' + BODY; c.fillText('العنوان', R - 16, y + 24);
      c.fillStyle = '#15181D'; c.font = '700 15px ' + BODY; c.fillText(fit(c, [sh.gov, sh.area].filter(Boolean).join(' — ') || '—', w2 - 32), R - 16, y + 48);
      rr(c, 48, y, gw, 62, 16); c.fillStyle = '#F4F3F0'; c.fill();
      c.fillStyle = '#6B7079'; c.font = '500 12px ' + BODY; c.fillText('طريقة الدفع', 48 + gw - 16, y + 24);
      c.fillStyle = '#15181D'; c.font = '700 15px ' + BODY; c.fillText('تحويل قبل الاستلام', 48 + gw - 16, y + 48);
      // table
      y += 98;
      c.fillStyle = '#6B7079'; c.font = '600 12px ' + BODY; c.textAlign = 'right'; c.fillText('المنتج', R - 14, y);
      if (!o.hide) { c.textAlign = 'center'; c.fillText('السعر', 48 + 290, y); }
      c.textAlign = 'center'; c.fillText('الكمية', 48 + 190, y);
      if (!o.hide) { c.textAlign = 'left'; c.fillText('المجموع', 62, y); }
      y += 10; c.fillStyle = '#061922'; c.fillRect(48, y, W - 96, 2); y += 2;
      o.items.slice(0, 10).forEach(function (it) {
        var rowH = it.s ? 66 : 50;
        c.textAlign = 'right'; c.fillStyle = '#15181D'; c.font = '700 15px ' + BODY; c.fillText(fit(c, it.n, 360), R - 14, y + 28);
        if (it.s) {
          c.font = '700 11px ' + HEAD; c.direction = 'ltr'; var sw = c.measureText(it.s).width + 16;
          rr(c, R - 14 - sw, y + 38, sw, 18, 7); c.fillStyle = 'rgba(250,162,27,.16)'; c.fill();
          c.fillStyle = '#7A4700'; c.textAlign = 'center'; c.fillText(it.s, R - 14 - sw / 2, y + 51); c.direction = 'rtl';
        }
        c.direction = 'ltr';
        if (!o.hide) { c.textAlign = 'center'; c.fillStyle = '#15181D'; c.font = '500 14px ' + BODY; c.fillText(it.p, 48 + 290, y + 32); }
        c.textAlign = 'center'; c.font = '700 15px ' + BODY; c.fillText(String(it.q), 48 + 190, y + 32);
        if (!o.hide && it.t) { c.textAlign = 'left'; c.font = '700 15px ' + HEAD; c.fillText(it.t, 62, y + 32); }
        c.direction = 'rtl';
        y += rowH; c.fillStyle = '#E6E3DD'; c.fillRect(48, y, W - 96, 1); y += 1;
      });
      // totals
      if (!o.hide) {
        y += 22; var tx = 48, tw = 330;
        c.font = '500 14px ' + BODY; c.fillStyle = '#4A4F57';
        if (o.sub) { c.textAlign = 'right'; c.fillText('المجموع الفرعي', tx + tw, y); c.textAlign = 'left'; c.direction = 'ltr'; c.fillText(o.sub, tx, y); c.direction = 'rtl'; y += 26; }
        if (o.disc) { c.fillStyle = '#16794A'; c.font = '700 14px ' + BODY; c.textAlign = 'right'; c.fillText('حسم ' + (o.coupons || []).join('، '), tx + tw, y); c.textAlign = 'left'; c.direction = 'ltr'; c.fillText('- ' + o.disc, tx, y); c.direction = 'rtl'; y += 26; }
        c.fillStyle = '#4A4F57'; c.font = '500 14px ' + BODY; c.textAlign = 'right'; c.fillText('رسوم التوصيل', tx + tw, y); c.textAlign = 'left'; c.font = '600 14px ' + BODY; c.fillText('يدفعها الزبون', tx, y); y += 16;
        rr(c, tx, y, tw, 52, 16); c.fillStyle = '#061922'; c.fill();
        c.fillStyle = '#fff'; c.font = '700 15px ' + BODY; c.textAlign = 'right'; c.fillText('الإجمالي', tx + tw - 18, y + 33);
        c.fillStyle = '#FAA21B'; c.font = '800 22px ' + HEAD; c.textAlign = 'left'; c.direction = 'ltr'; c.fillText(o.total, tx + 18, y + 35); c.direction = 'rtl';
      }
      // footer
      c.fillStyle = '#4A4F57'; c.font = '500 12.5px ' + BODY; c.textAlign = 'right';
      ['كفالة 6 أشهر', 'منتجات أصلية 100%', 'توصيل لكل المحافظات'].forEach(function (t, i) { c.fillText('● ' + t, R - i * 240, H - 74); });
      c.fillStyle = '#F4F3F0'; c.fillRect(0, H - 52, W, 52);
      c.fillStyle = '#4A4F57'; c.fillText('شكراً لثقتك بكوفيكس — سنتواصل معك لتأكيد الطلب', R, H - 21);
      c.textAlign = 'left'; c.direction = 'ltr'; c.font = '600 12.5px ' + BODY; c.fillText('coofix.sy · ' + (o.wa || ''), 48, H - 21);
      return cv;
    });
  }

  // Minimal one-page A4 PDF holding a JPEG.
  function pdfFromCanvas(cv) {
    var b64 = cv.toDataURL('image/jpeg', 0.9).split(',')[1], bin = atob(b64), jpg = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) jpg[i] = bin.charCodeAt(i);
    var enc = function (s) { var u = new Uint8Array(s.length); for (var i = 0; i < s.length; i++) u[i] = s.charCodeAt(i) & 255; return u; };
    var pw = 595.28, ph = 841.89, content = 'q ' + pw + ' 0 0 ' + ph + ' 0 0 cm /Im0 Do Q';
    var parts = [], offs = [], len = 0;
    function add(x) { var u = typeof x === 'string' ? enc(x) : x; parts.push(u); len += u.length; }
    add('%PDF-1.4\n%\xE2\xE3\xCF\xD3\n');
    offs[1] = len; add('1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n');
    offs[2] = len; add('2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n');
    offs[3] = len; add('3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 ' + pw + ' ' + ph + ']/Resources<</XObject<</Im0 4 0 R>>>>/Contents 5 0 R>>endobj\n');
    offs[4] = len; add('4 0 obj<</Type/XObject/Subtype/Image/Width ' + cv.width + '/Height ' + cv.height + '/ColorSpace/DeviceRGB/BitsPerComponent 8/Filter/DCTDecode/Length ' + jpg.length + '>>stream\n'); add(jpg); add('\nendstream endobj\n');
    offs[5] = len; add('5 0 obj<</Length ' + content.length + '>>stream\n' + content + '\nendstream endobj\n');
    var xref = len, x = 'xref\n0 6\n0000000000 65535 f \n';
    for (var k = 1; k <= 5; k++) x += String(offs[k]).padStart(10, '0') + ' 00000 n \n';
    add(x + 'trailer<</Size 6/Root 1 0 R>>\nstartxref\n' + xref + '\n%%EOF');
    return new Blob(parts, { type: 'application/pdf' });
  }

  window.cfxInvoicePdf = function (o) { return draw(o).then(pdfFromCanvas); };
})();
