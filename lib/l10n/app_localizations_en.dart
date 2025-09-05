// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'POS System';

  @override
  String get categories => 'Categories';

  @override
  String get products => 'Products';

  @override
  String get staff => 'Staff';

  @override
  String get attendance => 'Attendance';

  @override
  String get suppliers => 'Suppliers';

  @override
  String get purchases => 'Purchases';

  @override
  String get sales => 'Sales';

  @override
  String get drafts => 'Drafts';

  @override
  String get storeOut => 'Store Out';

  @override
  String get settings => 'Settings';

  @override
  String get addCategory => 'Add Category';

  @override
  String get addProduct => 'Add Product';

  @override
  String get editCategory => 'Edit Category';

  @override
  String get editProduct => 'Edit Product';

  @override
  String get name => 'Name';

  @override
  String get category => 'Category';

  @override
  String get unit => 'Unit';

  @override
  String get salePrice => 'Sale Price';

  @override
  String get purchasePrice => 'Purchase Price';

  @override
  String get quantity => 'Quantity';

  @override
  String get active => 'Active';

  @override
  String get inactive => 'Inactive';

  @override
  String get status => 'Status';

  @override
  String get createdOn => 'Created On';

  @override
  String get actions => 'Actions';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  String get addSupplier => 'Add Supplier';
String get editSupplier => 'Edit Supplier';
String get contactNumber => 'Contact Number';
String get address => 'Address';
String get amountToReceive => 'Amount to Receive';
String get amountToPay => 'Amount to Pay';
String get supplier => 'Supplier';
String get addedSuccessfully => 'Added Successfully';
String get updatedSuccessfully => 'Updated Successfully';
String get error => 'Error';
String get deletedSuccessfully => 'Deleted Successfully';
String get errorDeleting => 'Error Deleting';
String get search => 'Search';
String get contact => 'Contact';
String get receivable => 'Receivable';
String get payable => 'Payable';

  @override
  String get cancel => 'Cancel';

  @override
  String deleteConfirmTitle(String item) {
    return 'Delete $item';
  }

  @override
  String deleteConfirmMessage(String name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get system => 'System';
}
