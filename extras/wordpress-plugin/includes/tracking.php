<?php
/**
 * Website repair tracking — shortcode [coofix_repair_tracking]
 * Same experience as the mobile app: search by repair code (CFX-…) or phone.
 */
if (!defined('ABSPATH')) {
    exit;
}

add_shortcode('coofix_repair_tracking', 'cfx_tracking_shortcode');

function cfx_tracking_shortcode($atts) {
    $a = shortcode_atts(array(
        'title'    => 'تتبّع الصيانة',
        'subtitle' => 'أدخل رقم طلب الصيانة (CFX-…) أو رقم هاتفك المسجّل عند تسليم العدّة.',
    ), $atts, 'coofix_repair_tracking');
    wp_enqueue_script('cfx-status-img', COOFIX_APP_URL . 'assets/status-img.js', array(), COOFIX_APP_VERSION, true);
    $cfg = function_exists('coofix_app_get_config') ? coofix_app_get_config() : array();
    $primary = isset($cfg['brand']['primary']) ? $cfg['brand']['primary'] : '#FAA21B';
    $dark = isset($cfg['brand']['dark']) ? $cfg['brand']['dark'] : '#061922';
    $wa = isset($cfg['contact']['whatsapp_maintenance']) ? preg_replace('/\D+/', '', $cfg['contact']['whatsapp_maintenance']) : '';
    $id = 'cfxt' . wp_rand(1000, 9999);
    ob_start();
    ?>
<div id="<?php echo esc_attr($id); ?>" class="cfxt" dir="rtl" style="--cfx-amber:<?php echo esc_attr($primary); ?>;--cfx-ink:<?php echo esc_attr($dark); ?>">
  <div class="cfxt-head">
    <div class="cfxt-ico"><svg viewBox="0 0 24 24"><path d="M22.7 19.3 13.6 10.2c.9-2.3.4-5-1.5-6.9-2-2-5-2.4-7.4-1.3l4.3 4.3-3 3-4.4-4.3C.4 7.4.9 10.4 2.9 12.4c1.9 1.9 4.6 2.4 6.9 1.5l9.1 9.1c.4.4 1 .4 1.4 0l2.3-2.3c.5-.4.5-1.1.1-1.4Z"/></svg></div>
    <div>
      <h2><?php echo esc_html($a['title']); ?></h2>
      <p><?php echo esc_html($a['subtitle']); ?></p>
    </div>
  </div>
  <form class="cfxt-form" autocomplete="off">
    <input type="text" class="cfxt-in" dir="ltr" placeholder="CFX-0012  أو  09xx xxx xxx" inputmode="text">
    <button type="submit" class="cfxt-btn"><span class="cfxt-btn-t">عرض الطلبات</span><span class="cfxt-spin"></span></button>
  </form>
  <div class="cfxt-msg" hidden></div>
  <div class="cfxt-results"></div>
  <?php if ($wa) : ?>
  <a class="cfxt-wa" target="_blank" rel="noopener" href="https://wa.me/<?php echo esc_attr($wa); ?>?text=<?php echo rawurlencode('مرحباً، لدي استفسار عن الصيانة.'); ?>">
    <svg viewBox="0 0 24 24"><path d="M12 2a10 10 0 0 0-8.6 15.1L2 22l5-1.3A10 10 0 1 0 12 2Zm5.3 14.2c-.2.6-1.3 1.2-1.8 1.2-.5.1-1 .2-3.3-.7-2.8-1.1-4.5-4-4.7-4.2-.1-.2-1.1-1.5-1.1-2.8s.7-2 1-2.3c.2-.3.5-.3.7-.3h.5c.2 0 .4 0 .6.5l.8 2c.1.2.1.4 0 .5l-.4.6-.4.4c-.1.2-.3.3-.1.6.2.3.8 1.3 1.7 2.1 1.2 1 2.1 1.3 2.4 1.5.3.1.5.1.6-.1l.9-1.1c.2-.3.4-.2.7-.1l1.9.9c.3.1.5.2.5.3.2.2.2.7 0 1.2Z"/></svg>
    تواصل مع مركز الصيانة
  </a>
  <?php endif; ?>
</div>
<style>
@import url('https://fonts.googleapis.com/css2?family=Alexandria:wght@500;700;800&family=IBM+Plex+Sans+Arabic:wght@400;500;600;700&display=swap');
.cfxt{--line:#E6E3DD;--muted:#8A8F98;--bg:#F4F3F0;font-family:'IBM Plex Sans Arabic',Tahoma,sans-serif;max-width:720px;margin:24px auto;color:#15181D;text-align:right}
.cfxt *{box-sizing:border-box}
.cfxt-head{display:flex;gap:16px;align-items:center;padding:24px;border-radius:26px;color:#fff;background:radial-gradient(120% 140% at 100% 0%,#15394A 0%,var(--cfx-ink) 65%)}
.cfxt-ico{width:58px;height:58px;flex:none;border-radius:18px;display:grid;place-items:center;background:var(--cfx-amber)}
.cfxt-ico svg{width:28px;height:28px;fill:var(--cfx-ink)}
.cfxt-head h2{margin:0 0 4px;font-size:24px;font-weight:700;color:#fff;font-family:inherit}
.cfxt-head p{margin:0;color:rgba(255,255,255,.65);font-size:14px;line-height:1.7}
.cfxt-form{display:flex;gap:10px;margin:18px 0 0}
.cfxt-in{flex:1;min-width:0;height:58px;border:1px solid var(--line);border-radius:18px;padding:0 18px;font-size:19px;font-weight:700;letter-spacing:1px;text-align:center;font-family:inherit;background:#fff;color:#15181D}
.cfxt-in:focus{outline:none;border-color:var(--cfx-amber);box-shadow:0 0 0 3px color-mix(in srgb,var(--cfx-amber) 22%,transparent)}
.cfxt-btn{height:58px;padding:0 26px;border:0;border-radius:18px;cursor:pointer;font-family:inherit;font-size:16px;font-weight:700;color:var(--cfx-ink);background:linear-gradient(135deg,#FFC14F,var(--cfx-amber),#E08A00);display:flex;align-items:center;gap:8px;white-space:nowrap}
.cfxt-btn:disabled{opacity:.7;cursor:wait}
.cfxt-spin{display:none;width:20px;height:20px;border:2.5px solid var(--cfx-ink);border-top-color:transparent;border-radius:50%;animation:cfxs .8s linear infinite}
.cfxt-btn.is-loading .cfxt-spin{display:inline-block}.cfxt-btn.is-loading .cfxt-btn-t{display:none}
@keyframes cfxs{to{transform:rotate(360deg)}}
.cfxt-msg{margin-top:16px;padding:14px 16px;border-radius:16px;background:#FFF3F0;border:1px solid #F5C9BF;color:#9A3B26;font-weight:600;font-size:14px}
.cfxt-card{margin-top:18px;border:1px solid var(--line);border-radius:24px;background:#fff;overflow:hidden;animation:cfxin .35s ease}
@keyframes cfxin{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:none}}
.cfxt-card-h{display:flex;align-items:center;justify-content:space-between;gap:10px;padding:18px 20px;color:#fff;background:linear-gradient(#0F3041,var(--cfx-ink))}
.cfxt-card-h small{display:block;color:rgba(255,255,255,.55);font-size:12px}
.cfxt-card-h b{font-size:20px;letter-spacing:1px}
.cfxt-badge{padding:4px 12px;border-radius:30px;font-size:12.5px;font-weight:700;background:var(--cfx-amber);color:var(--cfx-ink)}
.cfxt-badge.is-x{background:#D64545;color:#fff}
.cfxt-steps{list-style:none;margin:0;padding:18px 20px 6px}
.cfxt-steps li{position:relative;display:flex;align-items:center;gap:12px;padding:0 0 18px}
.cfxt-steps li:not(:last-child):after{content:'';position:absolute;right:14px;top:30px;width:2px;height:18px;background:var(--line)}
.cfxt-steps li.done:not(:last-child):after{background:var(--cfx-amber)}
.cfxt-dot{width:30px;height:30px;border-radius:50%;flex:none;border:1px solid var(--line);background:var(--bg);display:grid;place-items:center;font-size:13px;color:var(--muted);font-weight:700}
.cfxt-steps li.done .cfxt-dot{background:var(--cfx-amber);border-color:var(--cfx-amber);color:var(--cfx-ink)}
.cfxt-steps li span{font-size:14.5px;color:var(--muted)}
.cfxt-steps li.done span{color:#15181D}
.cfxt-steps li.cur span{font-weight:700}
.cfxt-rows{padding:4px 20px 10px}
.cfxt-row{display:flex;justify-content:space-between;gap:16px;padding:9px 0;border-top:1px solid #f1efeb;font-size:14px}
.cfxt-row span{color:var(--muted)}.cfxt-row b{text-align:left}
.cfxt-box{margin:0 16px 16px;padding:14px 16px;border-radius:16px;background:var(--bg);font-size:14px;line-height:1.8}
.cfxt-box small{display:block;color:var(--muted);font-weight:600}
.cfxt-log{padding:0 20px 18px}
.cfxt-log div{display:flex;gap:10px;padding:5px 0;font-size:14px}
.cfxt-log i{width:7px;height:7px;border-radius:50%;background:var(--cfx-amber);margin-top:9px;flex:none}
.cfxt-log em{display:block;font-style:normal;color:var(--muted);font-size:12px}
.cfxt-wa{margin-top:22px;height:56px;border-radius:18px;background:#25D366;color:#fff!important;text-decoration:none!important;display:flex;align-items:center;justify-content:center;gap:10px;font-weight:700;font-size:16px}
.cfxt-wa svg{width:22px;height:22px;fill:#fff}
.cfxt-save{margin:0 20px 20px;width:calc(100% - 40px);height:50px;border:0;border-radius:16px;background:var(--cfx-ink,#061922);color:#fff;font:700 15px 'IBM Plex Sans Arabic',sans-serif;display:flex;align-items:center;justify-content:center;gap:8px;cursor:pointer}
.cfxt-save svg{color:#FAA21B}.cfxt-save:disabled{opacity:.7}
@media(max-width:560px){.cfxt-form{flex-direction:column}.cfxt-in{flex:none;width:100%}.cfxt-btn{justify-content:center}.cfxt-head{padding:20px}.cfxt-head h2{font-size:21px}}
</style>
<script>
(function(){
  var root=document.getElementById(<?php echo wp_json_encode($id); ?>);if(!root)return;
  var api=<?php echo wp_json_encode(esc_url_raw(rest_url('coofix-app/v1/'))); ?>;
  var form=root.querySelector('.cfxt-form'),inp=root.querySelector('.cfxt-in'),btn=root.querySelector('.cfxt-btn'),msg=root.querySelector('.cfxt-msg'),out=root.querySelector('.cfxt-results');
  var steps=[['received','تم الاستلام'],['diagnosing','قيد الفحص'],['waiting_parts','بانتظار القطع'],['repairing','قيد الإصلاح'],['ready','جاهزة للاستلام'],['delivered','تم التسليم']];
  function esc(s){return String(s==null?'':s).replace(/[&<>"']/g,function(c){return{'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];});}
  function digitsAr(s){return s.replace(/[٠-٩]/g,function(d){return String(d.charCodeAt(0)-1632);});}
  function show(t){msg.textContent=t;msg.hidden=!t;}
  function card(r){
    var idx=-1;steps.forEach(function(s,i){if(s[0]===r.status)idx=i;});
    var x=r.status==='cancelled';
    var h='<div class="cfxt-card"><div class="cfxt-card-h"><div><small>طلب رقم</small><b dir="ltr">'+esc(r.code)+'</b></div><span class="cfxt-badge'+(x?' is-x':'')+'">'+esc(r.status_label||'')+'</span></div>';
    if(!x&&idx>=0){h+='<ul class="cfxt-steps">';steps.forEach(function(s,i){h+='<li class="'+(i<=idx?'done':'')+(i===idx?' cur':'')+'"><span class="cfxt-dot">'+(i<=idx?'✓':(i+1))+'</span><span>'+s[1]+'</span></li>';});h+='</ul>';}
    var rows=[['العدّة',r.device],['الرقم التسلسلي',r.serial],['تاريخ الاستلام',r.received_at],['موعد الصيانة',r.service_at],['التسليم ابتداءً من',r.expected_at],['التكلفة',r.cost],['ضمن الكفالة',r.warranty===true?'نعم':(r.warranty===false?'لا':'')]];
    h+='<div class="cfxt-rows">';rows.forEach(function(w){if(w[1])h+='<div class="cfxt-row"><span>'+w[0]+'</span><b>'+esc(w[1])+'</b></div>';});h+='</div>';
    if(r.work_done)h+='<div class="cfxt-box"><small>ما تم في الصيانة</small>'+esc(r.work_done)+'</div>';
    var log=(r.timeline||[]).filter(function(t){return t&&t.note;}).reverse();
    if(log.length){h+='<div class="cfxt-log">';log.forEach(function(t){h+='<div><i></i><span>'+esc(t.note)+'<em>'+esc(t.date||'')+'</em></span></div>';});h+='</div>';}
    var ln=(r.timeline||[]).filter(function(t){return t&&t.note;}).pop();
    h+='<button type="button" class="cfxt-save" data-i="'+(window.cfxTrackItems=window.cfxTrackItems||[]).length+'">'+
      '<svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true"><path fill="currentColor" d="M5 20h14v-2H5v2zm7-18l-5.5 5.5 1.41 1.41L11 5.83V16h2V5.83l3.09 3.08 1.41-1.41L12 2z" transform="rotate(180 12 12)"/></svg>حفظ صورة الحالة</button>';
    window.cfxTrackItems.push({code:r.code,status:r.status,status_label:r.status_label,device:r.device,product_code:r.product_code||'',expected_at:r.expected_at,warranty:r.warranty,cost:r.cost,note:ln?ln.note:'',received_by:r.received_by||''});
    return h+'</div>';
  }
  document.addEventListener('click',function(e){var b=e.target.closest&&e.target.closest('.cfxt-save');if(!b||!window.cfxSaveStatus)return;window.cfxSaveStatus(window.cfxTrackItems[+b.dataset.i],'<?php echo esc_js(COOFIX_APP_URL . 'assets/icon.png'); ?>',b);});
  form.addEventListener('submit',function(e){
    e.preventDefault();
    var v=digitsAr(inp.value.trim()),d=v.replace(/\D/g,''),letters=/[A-Za-z]/.test(v),isCode=letters||(d.length>0&&d.length<=5);
    out.innerHTML='';
    if(!v||(!isCode&&d.length<7)){show('أدخل رقم طلب الصيانة أو رقم الهاتف المسجّل');return;}
    if(isCode&&!letters)v='CFX-'+('0000'+d).slice(-Math.max(4,d.length));
    show('');btn.disabled=true;btn.classList.add('is-loading');
    var url=isCode?api+'repair?code='+encodeURIComponent(v.toUpperCase()):api+'repairs?phone='+encodeURIComponent(v);
    fetch(url,{headers:{'Accept':'application/json'}}).then(function(r){return r.json().catch(function(){return{};}).then(function(j){return{s:r.status,j:j};});}).then(function(res){
      var items=res.j&&res.j.items?res.j.items:(res.j&&res.j.found?[res.j]:[]);
      if(res.s===429){show('محاولات كثيرة، حاول بعد قليل.');return;}
      if(!items.length){show(isCode?'لا يوجد طلب صيانة بهذا الرقم.':'لا توجد طلبات صيانة مسجّلة على هذا الهاتف.');return;}
      window.cfxTrackItems=[];out.innerHTML=items.map(card).join('');
    }).catch(function(){show('تعذّر الاتصال، حاول مجدداً.');}).then(function(){btn.disabled=false;btn.classList.remove('is-loading');});
  });
  var q=new URLSearchParams(location.search).get('repair');if(q){inp.value=q;form.dispatchEvent(new Event('submit'));}
})();
</script>
    <?php
    return ob_get_clean();
}
