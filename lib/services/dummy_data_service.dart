import '../models/category.dart';
import '../models/product.dart';
import '../models/staff.dart';

class DummyDataService {
  static List<Category> getCategories() => [
    Category(id: '1', name: 'Beverages', active: true),
    Category(id: '2', name: 'Snacks', active: true),
    Category(id: '3', name: 'Stationery', active: false),
    Category(id: '4', name: 'Electronics', active: true),
    Category(id: '5', name: 'Clothing', active: true),
  ];

  static List<Product> getProducts() => [
    Product(
      id: '1',
      name: 'Cola 330ml',
      category: 'Beverages',
      unit: 'bottle',
      salePrice: 1.20,
      purchasePrice: 0.90,
      quantity: 120,
    ),
    Product(
      id: '2',
      name: 'Chips',
      category: 'Snacks',
      unit: 'pack',
      salePrice: 1.49,
      purchasePrice: 1.00,
      quantity: 50,
    ),
    Product(
      id: '3',
      name: 'Notebook',
      category: 'Stationery',
      unit: 'piece',
      salePrice: 2.99,
      purchasePrice: 2.20,
      quantity: 35,
      active: false,
    ),
    Product(
      id: '4',
      name: 'Smartphone',
      category: 'Electronics',
      unit: 'piece',
      salePrice: 299.99,
      purchasePrice: 250.00,
      quantity: 15,
    ),
    Product(
      id: '5',
      name: 'T-Shirt',
      category: 'Clothing',
      unit: 'piece',
      salePrice: 19.99,
      purchasePrice: 12.00,
      quantity: 80,
    ),
  ];

  static List<Staff> getStaff() => [
    Staff(
      id: '1',
      name: 'یونس',
      role: 'Waiter',
      dailyWage: 400,
      phone: '+92 300 1234567',
      joinDate: DateTime(2024, 1, 15),
    ),
    Staff(
      id: '2',
      name: 'اکو بکر',
      role: 'Waiter',
      dailyWage: 100,
      phone: '+92 301 2345678',
      joinDate: DateTime(2024, 2, 10),
    ),
    Staff(
      id: '3',
      name: 'سلیم (Tiger)',
      role: 'Waiter',
      dailyWage: 300,
      phone: '+92 302 3456789',
      joinDate: DateTime(2024, 1, 20),
    ),
    Staff(
      id: '4',
      name: 'عمران',
      role: 'Supervisor',
      dailyWage: 600,
      phone: '+92 303 4567890',
      joinDate: DateTime(2023, 12, 5),
    ),
    Staff(
      id: '5',
      name: 'زبیر',
      role: 'Shawarma Maker',
      dailyWage: 700,
      phone: '+92 304 5678901',
      joinDate: DateTime(2024, 3, 1),
    ),
  ];

  static List<String> getUnits() => [
    'piece',
    'pack',
    'bottle',
    'kg',
    'ltr',
    'box',
    'dozen',
  ];
}
