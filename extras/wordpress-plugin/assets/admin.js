/* Coofix App — admin panel behaviour */
(function ($) {
  'use strict';

  // ---- Tabs (remember last tab) ----
  function openTab(key) {
    var $a = $('.cfx-tabs a[data-tab="' + key + '"]');
    if (!$a.length) { $a = $('.cfx-tabs a').first(); key = $a.data('tab'); }
    $('.cfx-tabs a').removeClass('is-active');
    $a.addClass('is-active');
    $('.cfx-panel').removeClass('is-active');
    $('.cfx-panel[data-panel="' + key + '"]').addClass('is-active');
    $('.cfx-savebar').toggle(key !== 'tools');
    try { localStorage.setItem('cfxTab', key); } catch (e) {}
  }
  $(document).on('click', '.cfx-tabs a', function (e) {
    e.preventDefault();
    var k = $(this).data('tab');
    history.replaceState(null, '', '#' + k);
    openTab(k);
  });

  // ---- Colour pickers ----
  function initColors(ctx) {
    $(ctx).find('.cfx-color').each(function () {
      if (!$(this).closest('.wp-picker-container').length) { $(this).wpColorPicker(); }
    });
  }

  // ---- Media picker ----
  $(document).on('click', '.cfx-media-pick', function (e) {
    e.preventDefault();
    var $box = $(this).closest('.cfx-media');
    var frame = wp.media({ title: 'اختر صورة', button: { text: 'استخدام الصورة' }, library: { type: 'image' }, multiple: false });
    frame.on('select', function () {
      var a = frame.state().get('selection').first().toJSON();
      $box.find('input[type=url]').val(a.url).trigger('change');
    });
    frame.open();
  });
  $(document).on('click', '.cfx-media-clear', function (e) {
    e.preventDefault();
    $(this).closest('.cfx-media').find('input[type=url]').val('').trigger('change');
  });
  $(document).on('change input', '.cfx-media input[type=url]', function () {
    var v = $(this).val();
    $(this).closest('.cfx-media').find('.cfx-media-preview').html(v ? '<img src="' + $('<div>').text(v).html() + '" alt="">' : '<span>لا توجد صورة</span>');
  });

  // ---- Repeaters ----
  function reindex($rep) {
    var base = $rep.data('base');
    var esc = base.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    var re = new RegExp('^' + esc + '\\[(?:\\d+|__i__)\\]');
    $rep.find('> .cfx-items > .cfx-item').each(function (i) {
      $(this).find('[name]').each(function () {
        this.name = this.name.replace(re, base + '[' + i + ']');
      });
    });
  }
  function initSortable(ctx) {
    $(ctx).find('.cfx-repeater > .cfx-items').sortable({
      handle: '.cfx-handle', placeholder: 'cfx-placeholder', axis: 'y',
      update: function () { reindex($(this).closest('.cfx-repeater')); }
    });
    $(ctx).find('.cfx-cats').sortable({ handle: '.cfx-handle', placeholder: 'cfx-placeholder', axis: 'y' });
  }
  $(document).on('click', '.cfx-toggle-item, .cfx-item-title', function () {
    $(this).closest('.cfx-item').toggleClass('is-open');
  });
  $(document).on('click', '.cfx-add', function () {
    var $rep = $(this).closest('.cfx-repeater');
    var html = $rep.children('script.cfx-tpl').html().replace(/<\\\/script/g, '</script');
    var $item = $(html);
    $rep.find('> .cfx-items').append($item);
    $item.addClass('is-open');
    reindex($rep);
    initColors($item);
    $item.find('input[type=text], textarea').first().trigger('focus');
  });
  $(document).on('click', '.cfx-remove', function () {
    if (!confirm('حذف هذا العنصر؟')) { return; }
    var $rep = $(this).closest('.cfx-repeater');
    $(this).closest('.cfx-item').slideUp(150, function () { $(this).remove(); reindex($rep); });
  });
  $(document).on('click', '.cfx-dup', function () {
    var $item = $(this).closest('.cfx-item');
    var $rep = $item.closest('.cfx-repeater');
    var $copy = $item.clone();
    // keep values of selects (clone() drops them)
    $item.find('select').each(function (i) { $copy.find('select').eq(i).val($(this).val()); });
    $copy.find('.wp-picker-container').each(function () {
      var $in = $(this).find('input.cfx-color'); $(this).replaceWith($in.removeAttr('style'));
    });
    $item.after($copy);
    reindex($rep);
    initColors($copy);
  });
  // Live title in repeater headers
  $(document).on('input', '.cfx-item-body input[type=text], .cfx-item-body textarea', function () {
    var $item = $(this).closest('.cfx-item');
    if ($item.closest('.cfx-fixed').length) { return; }
    var $first = $item.find('.cfx-item-body').find('input[type=text], textarea').filter(function () {
      return /\[(title|kicker)\]$/.test(this.name);
    }).first();
    if ($first.length && this === $first[0]) {
      $item.find('.cfx-item-title').text(($(this).val() || 'عنصر جديد').replace(/\n/g, ' '));
    }
  });

  $('#cfx-form').on('submit', function () {
    $('.cfx-repeater').each(function () { reindex($(this)); });
  });

  // ---- Unsaved changes warning ----
  var dirty = false;
  $(document).on('change input', '#cfx-form :input', function () { dirty = true; });
  $('#cfx-form').on('submit', function () { dirty = false; });
  $(window).on('beforeunload', function () { if (dirty) { return 'لديك تغييرات غير محفوظة'; } });

  $(function () {
    initColors(document);
    initSortable(document);
    var start = (location.hash || '').replace('#', '');
    if (!start) { try { start = localStorage.getItem('cfxTab') || ''; } catch (e) {} }
    openTab(start || 'general');
  });
})(jQuery);
