// tour_targets.dart
import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class TourTargets {
  // Dashboard screen targets
  static List<TargetFocus> getDashboardTargets(GlobalKey categoriesKey, GlobalKey quickActionsKey) {
    return [
      TargetFocus(
        identify: "categories",
        keyTarget: categoriesKey,
        color: Colors.transparent,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Product Categories",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "These are your product categories. Tap on any category to view its products.",
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              );
            },
          )
        ],
      ),
      TargetFocus(
        identify: "quick_actions",
        keyTarget: quickActionsKey,
        color: Colors.transparent,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Quick Actions",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Quickly access different sections of the app from here.",
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              );
            },
          )
        ],
      ),
    ];
  }

  // Categories screen targets
  static List<TargetFocus> getCategoriesTargets(GlobalKey addButtonKey, GlobalKey searchKey) {
    return [
      TargetFocus(
        identify: "add_category",
        keyTarget: addButtonKey,
        color: Colors.transparent,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Add Category",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Tap here to create your first product category.",
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              );
            },
          )
        ],
      ),
      TargetFocus(
        identify: "search_categories",
        keyTarget: searchKey,
        color: Colors.transparent,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Search Categories",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Use this to quickly find your categories.",
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              );
            },
          )
        ],
      ),
    ];
  }

  // Products screen targets
  static List<TargetFocus> getProductsTargets(GlobalKey addButtonKey, GlobalKey searchKey) {
    return [
      TargetFocus(
        identify: "add_product",
        keyTarget: addButtonKey,
        color: Colors.transparent,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Add Product",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Tap here to add products to your inventory.",
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              );
            },
          )
        ],
      ),
      TargetFocus(
        identify: "search_products",
        keyTarget: searchKey,
        color: Colors.transparent,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Search Products",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Use this to find products quickly.",
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              );
            },
          )
        ],
      ),
    ];
  }

  // Staff screen targets
  static List<TargetFocus> getStaffTargets(GlobalKey addButtonKey) {
    return [
      TargetFocus(
        identify: "add_staff",
        keyTarget: addButtonKey,
        color: Colors.transparent,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Add Staff Member",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Tap here to add your team members.",
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              );
            },
          )
        ],
      ),
    ];
  }

  // Suppliers screen targets
  static List<TargetFocus> getSuppliersTargets(GlobalKey addButtonKey) {
    return [
      TargetFocus(
        identify: "add_supplier",
        keyTarget: addButtonKey,
        color: Colors.transparent,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Add Supplier",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Tap here to add your suppliers.",
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              );
            },
          )
        ],
      ),
    ];
  }
}