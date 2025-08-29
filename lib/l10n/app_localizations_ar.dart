// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'نظام نقاط البيع';

  @override
  String get categories => 'الفئات';

  @override
  String get products => 'المنتجات';

  @override
  String get staff => 'الموظفون';

  @override
  String get attendance => 'الحضور';

  @override
  String get suppliers => 'الموردون';

  @override
  String get purchases => 'المشتريات';

  @override
  String get sales => 'المبيعات';

  @override
  String get drafts => 'المسودات';

  @override
  String get storeOut => 'إخراج المتجر';

  @override
  String get settings => 'الإعدادات';

  @override
  String get addCategory => 'إضافة فئة';

  @override
  String get addProduct => 'إضافة منتج';

  @override
  String get editCategory => 'تعديل الفئة';

  @override
  String get editProduct => 'تعديل المنتج';

  @override
  String get name => 'الاسم';

  @override
  String get category => 'الفئة';

  @override
  String get unit => 'الوحدة';

  @override
  String get salePrice => 'سعر البيع';

  @override
  String get purchasePrice => 'سعر الشراء';

  @override
  String get quantity => 'الكمية';

  @override
  String get active => 'نشط';

  @override
  String get inactive => 'غير نشط';

  @override
  String get status => 'الحالة';

  @override
  String get createdOn => 'تاريخ الإنشاء';

  @override
  String get actions => 'الإجراءات';

  @override
  String get edit => 'تعديل';

  @override
  String get delete => 'حذف';

  @override
  String get save => 'حفظ';

  @override
  String get cancel => 'إلغاء';

  @override
  String deleteConfirmTitle(String item) {
    return 'حذف $item';
  }

  @override
  String deleteConfirmMessage(String name) {
    return 'هل أنت متأكد من أنك تريد حذف \"$name\"؟';
  }

  @override
  String get language => 'اللغة';

  @override
  String get theme => 'المظهر';

  @override
  String get light => 'فاتح';

  @override
  String get dark => 'داكن';

  @override
  String get system => 'النظام';
}
