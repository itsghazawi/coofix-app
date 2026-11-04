import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App language: Arabic (default) or English. Content from the site is translated
/// by the server (requests carry `lang=en`); the app's own texts are below.
class Lang {
  static final ValueNotifier<String> code = ValueNotifier('ar');
  static bool get en => code.value == 'en';

  /// Query suffix for site requests.
  static String get q => en ? '&lang=en' : '';
  static Map<String, String> get headers => en ? {'X-Coofix-Lang': 'en'} : {};

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      code.value = p.getString('lang') == 'en' ? 'en' : 'ar';
    } catch (_) {}
  }

  static Future<void> set(String c) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('lang', c);
    } catch (_) {}
    code.value = c;
  }
}

/// Translate an Arabic UI text (returns it unchanged in Arabic mode).
String tr(String s) => Lang.en ? (_en[s] ?? s) : s;

/// Translate a text with {placeholders}.
String trf(String s, List<Object?> a) {
  var t = tr(s);
  for (var i = 0; i < a.length; i++) {
    t = t.replaceAll('{$i}', '${a[i] ?? ''}');
  }
  return t;
}

const Map<String, String> _en = {
  // Brand & general
  'كوفيكس سوريا': 'COOFIX Syria',
  'الوكيل الحصري والرسمي في سوريا': 'Exclusive Official Distributor in Syria',
  'الوكيل الحصري والرسمي': 'Exclusive Official Distributor',
  'الوكيل المعتمد لعدّة كوفيكس': 'Authorized COOFIX Tools Distributor',
  '© {0} {1} — الوكالة الرسمية في سوريا': '© {0} {1} — Official Distributor in Syria',
  'الإصدار {0}': 'Version {0}',
  'الإصدار': 'Version',
  'أهلاً بك في': 'Welcome to',
  'مرحباً {0} 👋': 'Hello {0} 👋',
  'مرحباً {0}': 'Hello {0}',
  'ل.س': 'SYP',
  // Navigation
  'الرئيسية': 'Home',
  'الأقسام': 'Categories',
  'السلة': 'Cart',
  'المفضلة': 'Wishlist',
  'المزيد': 'More',
  'الصيانة': 'Service',
  // Home
  'تسوّق حسب القسم': 'Shop by Category',
  'الكل': 'All',
  'عروض حصرية': 'Exclusive Deals',
  'وصل حديثاً': 'New Arrivals',
  'الأكثر طلباً': 'Best Sellers',
  'مركز الصيانة المعتمد': 'Authorized Service Center',
  'تابع حالة عدّتك برقم الطلب أو الهاتف': 'Track your tool by order number or phone',
  'ابحث عن مثقب، جلاخة، كمبريسور...': 'Search drills, grinders, compressors…',
  // Search
  'ابحث في منتجات كوفيكس': 'Search COOFIX products',
  'عمليات بحث شائعة': 'Popular searches',
  'لا توجد نتائج لـ "{0}"': 'No results for "{0}"',
  'مثقب': 'Drill',
  'جلاخة': 'Angle Grinder',
  'شحن': 'Cordless',
  'كمبريسور': 'Compressor',
  'منشار': 'Saw',
  'مولدة': 'Generator',
  'طقم': 'Tool Set',
  // Categories
  '{0} منتج في {1} أقسام': '{0} products in {1} categories',
  '{0} منتج': '{0} products',
  'المقترح': 'Recommended',
  'الأقل سعراً': 'Price: Low to High',
  'الأعلى سعراً': 'Price: High to Low',
  'العروض': 'On Sale',
  'لا توجد منتجات في هذا القسم حالياً': 'No products in this category yet',
  // Favorites
  'احفظ المنتجات التي تعجبك هنا': 'Save the products you like here',
  '{0} منتج محفوظ': '{0} saved products',
  'لا توجد منتجات مفضلة': 'Your wishlist is empty',
  'اضغط على القلب في أي منتج لحفظه والرجوع إليه لاحقاً.': 'Tap the heart on any product to save it for later.',
  // Product
  'وفّر {0}%': 'Save {0}%',
  'متوفر': 'In stock',
  'غير متوفر': 'Out of stock',
  'المواصفات الفنية': 'Specifications',
  'عن المنتج': 'About this product',
  'مرحباً، لدي استفسار عن المنتج: ': 'Hello, I have a question about the product: ',
  'عندك سؤال؟ اسأل خبير كوفيكس على واتساب': 'Have a question? Ask a COOFIX expert on WhatsApp',
  'منتجات مشابهة': 'Similar products',
  'تمت إضافة {0} إلى السلة': '{0} added to cart',
  'أضف إلى السلة': 'Add to Cart',
  'اطلب عبر واتساب': 'Order via WhatsApp',
  'أضيف إلى السلة': 'Added to cart',
  'اطلب السعر': 'Request a Quote',
  'تم النسخ': 'Copied',
  'كود المنتج': 'Product code',
  'الكمية': 'Quantity',
  'إلغاء': 'Cancel',
  'تم': 'Done',
  'عرض السلة': 'View cart',
  // Cart & order
  'سلة الطلب': 'Your Cart',
  'سلتك فارغة': 'Your cart is empty',
  '{0} قطعة جاهزة للطلب': '{0} items ready to order',
  'إفراغ': 'Clear',
  'لم تضف أي منتج بعد': 'You haven\'t added any products yet',
  'تصفّح عدد كوفيكس وأضف ما تحتاجه، ثم أرسل طلبك عبر واتساب بضغطة واحدة.': 'Browse COOFIX tools, add what you need, then send your order on WhatsApp with one tap.',
  'الكود غير صحيح': 'Invalid code',
  'تعذّر التحقق من الكود، تحقق من الإنترنت': 'Couldn\'t verify the code. Please check your connection.',
  'المحافظة': 'Governorate',
  'المنطقة': 'Area',
  'الاسم الثلاثي': 'Full name',
  'رقم الهاتف': 'Phone number',
  'الرجاء تعبئة {0}': 'Please fill in: {0}',
  'إتمام الطلب': 'Checkout',
  'سيتم إرسال طلبك إلى فريق كوفيكس على واتساب لتأكيده.': 'Your order will be sent to the COOFIX team on WhatsApp for confirmation.',
  'معلومات الشحن': 'Shipping details',
  'المحافظة *': 'Governorate *',
  'المنطقة *': 'Area *',
  'الاسم الثلاثي *': 'Full name *',
  'رقم الهاتف *': 'Phone number *',
  'كود الحسم (إن وجد)': 'Discount code (optional)',
  'تطبيق': 'Apply',
  '{0} • حسم {1} = {2}': '{0} • {1} off = {2}',
  'المجموع': 'Subtotal',
  'الحسم': 'Discount',
  'الإجمالي': 'Total',
  'أرسل الطلب عبر واتساب': 'Send order via WhatsApp',
  'الإجمالي التقريبي': 'Estimated total',
  'ابدأ التسوّق': 'Start shopping',
  'دمشق': 'Damascus',
  'ريف دمشق': 'Rif Dimashq',
  'حلب': 'Aleppo',
  'حمص': 'Homs',
  'حماة': 'Hama',
  'اللاذقية': 'Latakia',
  'طرطوس': 'Tartus',
  'إدلب': 'Idlib',
  'درعا': 'Daraa',
  'السويداء': 'As-Suwayda',
  'القنيطرة': 'Quneitra',
  'دير الزور': 'Deir ez-Zor',
  'الرقة': 'Raqqa',
  'الحسكة': 'Al-Hasakah',
  // WhatsApp order message
  'مرحباً كوفيكس سوريا 👋\nأرغب بطلب المنتجات التالية من التطبيق:': 'Hello COOFIX Syria 👋\nI would like to order the following products from the app:',
  '   الرمز: {0}': '   Code: {0}',
  '   الكمية: {0}': '   Qty: {0}',
  '   الكمية: {0} × {1}': '   Qty: {0} × {1}',
  'الاسم: {0}': 'Name: {0}',
  'العنوان: {0}': 'Address: {0}',
  'الهاتف: {0}': 'Phone: {0}',
  'ملاحظات: {0}': 'Notes: {0}',
  'شكراً لكم.': 'Thank you.',
  '\n\nكود الحسم: {0} ({1})\nالحسم: {2}\nالإجمالي بعد الحسم: {3}': '\n\nDiscount code: {0} ({1})\nDiscount: {2}\nTotal after discount: {3}',
  'رقم الطلب: {0}\n{1}': 'Order number: {0}\n{1}',
  // More
  'تتبّع الصيانة': 'Repair Tracking',
  'الكفالة': 'Warranty',
  'شروط الكفالة': 'Warranty terms',
  'للتجار': 'For Dealers',
  'أسعار الجملة والشراكات': 'Wholesale pricing & partnerships',
  'مرحباً، أنا تاجر وأرغب بالاستفسار عن أسعار الجملة.': 'Hello, I\'m a dealer and would like to enquire about wholesale pricing.',
  'واتساب': 'WhatsApp',
  'اتصال مباشر': 'Call us',
  'البريد الإلكتروني': 'Email',
  'الموقع الإلكتروني': 'Website',
  'العنوان': 'Address',
  'عرض على الخريطة': 'View on map',
  'أوقات الدوام': 'Working hours',
  'منتج': 'Products',
  'أقسام': 'Categories',
  'أشهر كفالة': 'Month Warranty',
  'الخدمات': 'Services',
  'تواصل معنا': 'Contact Us',
  'عن كوفيكس': 'About COOFIX',
  'من نحن': 'About Us',
  'قصة {0}': 'The {0} story',
  'فيسبوك': 'Facebook',
  'إنستغرام': 'Instagram',
  'تيك توك': 'TikTok',
  'تلغرام': 'Telegram',
  'يوتيوب': 'YouTube',
  'تابعنا': 'Follow us',
  'كفالة 6 أشهر': '6-Month Warranty',
  // Repair tracking
  'تم الاستلام': 'Received',
  'قيد الفحص': 'Diagnosing',
  'بانتظار القطع': 'Awaiting Parts',
  'قيد الإصلاح': 'Under Repair',
  'جاهزة للاستلام': 'Ready for Pickup',
  'تم التسليم': 'Delivered',
  'أدخل رقم طلب الصيانة أو رقم الهاتف المسجّل': 'Enter the repair order number or the registered phone number',
  'محاولات كثيرة، حاول بعد قليل.': 'Too many attempts. Please try again shortly.',
  'لا يوجد طلب صيانة بهذا الرقم.': 'No repair order found with this number.',
  'لا توجد طلبات صيانة مسجّلة على هذا الهاتف.': 'No repair orders are registered to this phone number.',
  'خدمة تتبّع الصيانة غير متاحة حالياً.': 'Repair tracking is currently unavailable.',
  'تعذّر الاتصال، تحقق من الإنترنت وحاول مجدداً.': 'Connection failed. Please check your internet and try again.',
  'أدخل رقم طلب الصيانة (CFX-…) أو رقم هاتفك المسجّل عند تسليم العدّة.': 'Enter your repair order number (CFX-…) or the phone number you registered when dropping off your tool.',
  'CFX-0012  أو  09xx xxx xxx': 'CFX-0012  or  09xx xxx xxx',
  'عرض طلباتي': 'Show my orders',
  'تواصل مع مركز الصيانة': 'Contact the service center',
  'مرحباً، لدي استفسار عن الصيانة.': 'Hello, I have a question about a repair.',
  'العدة': 'Tool',
  'الرقم التسلسلي': 'Serial number',
  'تاريخ الاستلام': 'Received on',
  'موعد الصيانة': 'Service date',
  'التسليم ابتداءً من': 'Ready for pickup from',
  'التكلفة': 'Cost',
  'ضمن الكفالة': 'Under warranty',
  'نعم': 'Yes',
  'لا': 'No',
  'استلمها الموظف': 'Received by',
  'طلب رقم': 'Order no.',
  'ما تم في الصيانة': 'Work performed',
  'سجل التحديثات': 'Update history',
  // Notices
  'التطبيق قيد التحديث': 'The app is being updated',
  'تحديث جديد متوفر': 'A new update is available',
  'تحديث الآن': 'Update now',
  'لاحقاً': 'Later',
};
