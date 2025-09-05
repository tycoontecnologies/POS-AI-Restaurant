// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Urdu (`ur`).
class AppLocalizationsUr extends AppLocalizations {
  AppLocalizationsUr([String locale = 'ur']) : super(locale);

  @override
  String get appTitle => 'پی او ایس سسٹم';

  @override
  String get categories => 'اقسام';

  @override
  String get products => 'مصنوعات';

  @override
  String get staff => 'عملہ';

  String get addSupplier => 'سپلائر شامل کریں';
String get editSupplier => 'سپلائر میں تبدیلی';
String get contactNumber => 'رابطہ نمبر';
String get address => 'پتہ';
String get amountToReceive => 'وصول ہونے والی رقم';
String get amountToPay => 'ادا کرنے والی رقم';
String get supplier => 'سپلائر';
String get addedSuccessfully => 'کامیابی سے شامل ہو گیا';
String get updatedSuccessfully => 'کامیابی سے اپ ڈیٹ ہو گیا';
String get error => 'خرابی';
String get deletedSuccessfully => 'کامیابی سے حذف ہو گیا';
String get errorDeleting => 'حذف کرنے میں خرابی';
String get search => 'تلاش کریں';
String get contact => 'رابطہ';
String get receivable => 'وصول ہونے والا';
String get payable => 'ادا کرنے والا';

  @override
  String get attendance => 'حاضری';

  @override
  String get suppliers => 'سپلائرز';

  @override
  String get purchases => 'خریداری';

  @override
  String get sales => 'فروخت';

  @override
  String get drafts => 'ڈرافٹس';

  @override
  String get storeOut => 'اسٹور آؤٹ';

  @override
  String get settings => 'ترتیبات';

  @override
  String get addCategory => 'قسم شامل کریں';

  @override
  String get addProduct => 'مصنوعات شامل کریں';

  @override
  String get editCategory => 'قسم میں تبدیلی';

  @override
  String get editProduct => 'مصنوعات میں تبدیلی';

  @override
  String get name => 'نام';

  @override
  String get category => 'قسم';

  @override
  String get unit => 'یونٹ';

  @override
  String get salePrice => 'فروخت کی قیمت';

  @override
  String get purchasePrice => 'خریداری کی قیمت';

  @override
  String get quantity => 'مقدار';

  @override
  String get active => 'فعال';

  @override
  String get inactive => 'غیر فعال';

  @override
  String get status => 'حالت';

  @override
  String get createdOn => 'بنایا گیا';

  @override
  String get actions => 'اعمال';

  @override
  String get edit => 'تبدیل کریں';

  @override
  String get delete => 'حذف کریں';

  @override
  String get save => 'محفوظ کریں';

  @override
  String get cancel => 'منسوخ کریں';

  @override
  String deleteConfirmTitle(String item) {
    return '$item حذف کریں';
  }

  @override
  String deleteConfirmMessage(String name) {
    return 'کیا آپ واقعی \"$name\" کو حذف کرنا چاہتے ہیں؟';
  }

  @override
  String get language => 'زبان';

  @override
  String get theme => 'تھیم';

  @override
  String get light => 'روشن';

  @override
  String get dark => 'تاریک';

  @override
  String get system => 'سسٹم';
}
