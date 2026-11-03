/* Coofix — maintenance status image (1080×1350), drawn in the browser on a canvas.
   Nothing is uploaded or stored: the PNG is built here and downloaded / shared. */
(function () {
  'use strict';
  var STAGES = [
    ['received', 'تم الاستلام', '#7FB2FF'],
    ['diagnosing', 'قيد الفحص', '#C4A6FF'],
    ['repairing', 'قيد الإصلاح', '#FFC14F'],
    ['ready', 'جاهزة للاستلام', '#6FE3A1'],
    ['delivered', 'تم التسليم', '#5FD3C4']
  ];
  var MAP = { waiting_parts: 'repairing', cancelled: null };
  var HEAD = '"Alexandria", "IBM Plex Sans Arabic", sans-serif';
  var BODY = '"IBM Plex Sans Arabic", "Alexandria", sans-serif';

  function rr(c, x, y, w, h, r) {
    c.beginPath(); c.moveTo(x + r, y); c.arcTo(x + w, y, x + w, y + h, r); c.arcTo(x + w, y + h, x, y + h, r);
    c.arcTo(x, y + h, x, y, r); c.arcTo(x, y, x + w, y, r); c.closePath();
  }
  function wrap(c, text, x, y, maxW, lh, maxLines) {
    var words = String(text || '').split(/\s+/), line = '', n = 0;
    for (var i = 0; i < words.length; i++) {
      var t = line ? line + ' ' + words[i] : words[i];
      if (c.measureText(t).width > maxW && line) { c.fillText(line, x, y); y += lh; line = words[i]; if (++n >= maxLines - 1) { line = words.slice(i).join(' '); break; } }
      else line = t;
    }
    if (line) { while (c.measureText(line).width > maxW && line.length > 3) line = line.slice(0, -2); c.fillText(line, x, y); }
  }
  function loadImg(src) {
    return new Promise(function (res) { var i = new Image(); i.crossOrigin = 'anonymous'; i.onload = function () { res(i); }; i.onerror = function () { res(null); }; i.src = src; });
  }

  /** r: {code, status, status_label, device, product_code, expected_at, warranty, cost, note, received_by} */
  window.cfxStatusImage = function (r, logoUrl) {
    var fontsReady = (document.fonts && document.fonts.ready) ? document.fonts.ready : Promise.resolve();
    return Promise.all([loadImg(logoUrl), fontsReady]).then(function (a) {
      var logo = a[0], W = 1080, H = 1350, cv = document.createElement('canvas');
      cv.width = W; cv.height = H;
      var c = cv.getContext('2d');
      c.direction = 'rtl'; c.textBaseline = 'alphabetic';
      // background + honeycomb
      c.fillStyle = '#061922'; c.fillRect(0, 0, W, H);
      c.strokeStyle = 'rgba(250,162,27,0.06)'; c.lineWidth = 1.5;
      for (var yy = -50; yy < H + 100; yy += 73) for (var xx = -50 + ((Math.round(yy / 73) % 2) ? 42 : 0); xx < W + 100; xx += 84) {
        c.beginPath(); for (var k = 0; k < 6; k++) { var an = Math.PI / 180 * (60 * k - 30), px = xx + 48 * Math.cos(an), py = yy + 48 * Math.sin(an); k ? c.lineTo(px, py) : c.moveTo(px, py); } c.closePath(); c.stroke();
      }
      var R = W - 72; // right edge (RTL start)
      // header
      rr(c, R - 96, 72, 96, 96, 28); c.fillStyle = '#0F3041'; c.fill(); c.strokeStyle = 'rgba(250,162,27,0.5)'; c.lineWidth = 2; c.stroke();
      if (logo) c.drawImage(logo, R - 82, 86, 68, 68);
      c.textAlign = 'right'; c.fillStyle = '#fff'; c.font = '800 40px ' + HEAD; c.fillText('صيانة كوفيكس', R - 120, 118);
      c.fillStyle = 'rgba(255,255,255,0.6)'; c.font = '500 24px ' + BODY; c.fillText('مركز الصيانة المعتمد', R - 120, 154);
      // code chip (left)
      c.font = '800 30px ' + HEAD; c.direction = 'ltr'; var cw = c.measureText(r.code || '').width + 52;
      rr(c, 72, 84, cw, 70, 22); c.fillStyle = 'rgba(250,162,27,0.12)'; c.fill(); c.strokeStyle = 'rgba(250,162,27,0.4)'; c.stroke();
      c.fillStyle = '#FAA21B'; c.textAlign = 'left'; c.fillText(r.code || '', 98, 130); c.direction = 'rtl';
      // status card
      var st = MAP.hasOwnProperty(r.status) ? MAP[r.status] : r.status, idx = -1;
      STAGES.forEach(function (s, i) { if (s[0] === st) idx = i; });
      var color = idx >= 0 ? STAGES[idx][2] : '#FF8A7D';
      rr(c, 72, 214, W - 144, 300, 44); c.fillStyle = color; c.fill();
      c.textAlign = 'right'; c.fillStyle = 'rgba(6,25,34,0.75)'; c.font = '600 28px ' + BODY; c.fillText('حالة عدّتك الآن', R - 56, 286);
      c.fillStyle = '#061922'; c.font = '800 80px ' + HEAD; c.fillText(r.status_label || (idx >= 0 ? STAGES[idx][1] : ''), R - 56, 386);
      if (r.note) { c.fillStyle = 'rgba(6,25,34,0.85)'; c.font = '500 28px ' + BODY; wrap(c, r.note, R - 56, 448, W - 256, 40, 2); }
      // steps
      var y0 = 600, gap = (W - 144 - 170) / 4;
      c.strokeStyle = 'rgba(255,255,255,0.15)'; c.lineWidth = 4; c.beginPath(); c.moveTo(R - 85, y0); c.lineTo(72 + 85, y0); c.stroke();
      STAGES.forEach(function (s, i) {
        var cx = R - 85 - i * gap, done = idx >= 0 && i <= idx;
        c.beginPath(); c.arc(cx, y0, 32, 0, Math.PI * 2); c.fillStyle = done ? '#FAA21B' : '#061922'; c.fill();
        c.lineWidth = 3; c.strokeStyle = done ? '#FAA21B' : 'rgba(255,255,255,0.25)'; c.stroke();
        c.textAlign = 'center'; c.fillStyle = done ? '#061922' : 'rgba(255,255,255,0.5)'; c.font = '800 26px ' + HEAD; c.fillText(done ? '✓' : String(i + 1), cx, y0 + 10);
        c.fillStyle = done ? '#fff' : 'rgba(255,255,255,0.45)'; c.font = '700 22px ' + BODY; c.fillText(s[1], cx, y0 + 74);
      });
      // info grid
      var cells = [['العدّة', r.device || '—', r.product_code || ''], ['التسليم المتوقع', r.expected_at || '—', ''], ['الكفالة', r.warranty === true ? 'ضمن الكفالة' : (r.warranty === false ? 'خارج الكفالة' : '—'), ''], ['التكلفة', r.cost || '—', '']];
      var gw = (W - 144 - 18) / 2;
      cells.forEach(function (cl, i) {
        var col = i % 2, row = Math.floor(i / 2), x = R - (col + 1) * gw - col * 18, y = 730 + row * 168;
        rr(c, x, y, gw, 150, 28); c.fillStyle = 'rgba(255,255,255,0.06)'; c.fill(); c.strokeStyle = 'rgba(255,255,255,0.1)'; c.lineWidth = 1.5; c.stroke();
        c.textAlign = 'right'; c.fillStyle = 'rgba(255,255,255,0.55)'; c.font = '500 22px ' + BODY; c.fillText(cl[0], x + gw - 30, y + 46);
        c.fillStyle = '#fff'; c.font = '700 30px ' + BODY; wrap(c, cl[1], x + gw - 30, y + 92, gw - 60, 36, 1);
        if (cl[2]) { c.fillStyle = '#FFC14F'; c.font = '700 22px ' + HEAD; c.direction = 'ltr'; c.textAlign = 'right'; c.fillText(cl[2], x + gw - 30, y + 128); c.direction = 'rtl'; }
      });
      // received by
      if (r.received_by) {
        c.textAlign = 'right'; c.fillStyle = 'rgba(255,255,255,0.6)'; c.font = '500 24px ' + BODY;
        c.fillText('استلمها الموظف: ' + r.received_by, R, 1110);
      }
      // footer
      c.strokeStyle = 'rgba(255,255,255,0.1)'; c.lineWidth = 1.5; c.beginPath(); c.moveTo(72, 1240); c.lineTo(R, 1240); c.stroke();
      c.textAlign = 'right'; c.fillStyle = 'rgba(255,255,255,0.6)'; c.font = '500 24px ' + BODY; c.fillText('تابع حالة عدّتك من تطبيق كوفيكس أو الموقع', R, 1292);
      c.textAlign = 'left'; c.direction = 'ltr'; c.fillStyle = '#fff'; c.font = '600 24px ' + BODY; c.fillText('coofix.sy', 72, 1292);
      return new Promise(function (res) { cv.toBlob(function (b) { res(b); }, 'image/png'); });
    });
  };

  /** Download, or open the phone's share sheet when available. */
  window.cfxSaveStatus = function (r, logoUrl, btn) {
    if (btn) { btn.disabled = true; btn.dataset.t = btn.textContent; btn.textContent = 'جاري التجهيز…'; }
    return window.cfxStatusImage(r, logoUrl).then(function (blob) {
      var name = 'Coofix-' + (r.code || 'status') + '.png';
      var file = null;
      try { file = new File([blob], name, { type: 'image/png' }); } catch (e) {}
      if (file && navigator.canShare && navigator.canShare({ files: [file] })) {
        return navigator.share({ files: [file], title: 'حالة الصيانة ' + (r.code || '') }).catch(function () {});
      }
      var a = document.createElement('a'); a.href = URL.createObjectURL(blob); a.download = name;
      document.body.appendChild(a); a.click(); setTimeout(function () { URL.revokeObjectURL(a.href); a.remove(); }, 1500);
    }).then(function () { if (btn) { btn.disabled = false; btn.textContent = btn.dataset.t; } });
  };
})();
