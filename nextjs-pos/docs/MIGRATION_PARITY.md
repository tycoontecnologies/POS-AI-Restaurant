# Flutter → Next.js POS parity register

Source of truth: `main` Flutter application. Target: `nextjs-pos/` on `nextjs-pos-rebuild`.
Last reconciled: 2026-11-27. This register is intentionally conservative: a feature is not marked complete merely because a page shell exists.

## Safety boundary

- Keep Flutter `main`, live Firebase data, production configuration, and current production POS untouched.
- Work only on the isolated `nextjs-pos-rebuild` branch and its draft PR.
- Do not merge, deploy, or run write tests against production Firebase.
- Use a dedicated test Firebase project/tenant for end-to-end validation.

## Existing Next.js slice (implemented; not yet proven end-to-end)

- Firebase client initialization and email/password authentication.
- Vendor/tenant resolution using the observed Flutter user document conventions.
- Realtime product, table, and table-order reads.
- Product search/category filtering, variant-aware cart and client-side stock checks.
- Table order save/restore.
- KOT queue and basic status transitions.
- Basic checkout document creation, usage ledger, browser receipt/KOT print.
- Live management data views for dashboard/sales, products, categories, customers, discounts, ingredients, purchases/returns, sales/returns, suppliers, staff, attendance, store-out, branches, expenses and orders. Product (including JSON-based variants and attributes), category, customer, supplier, discount, ingredient and staff modules have schema-shaped create/edit forms; expenses support Flutter-shaped create and delete operations with creator and branch metadata; product/category/discount images upload to Firebase Storage; unsupported business side effects remain unimplemented.
- Table creation uses the original table document fields; POS navigation is partially role-filtered using the Flutter role map.
- Hamburger-only Tables/Items and Modern/Legacy controls; product card click adds to cart.

## Route/screen parity register

| Flutter source screen | Next.js parity |
|---|---|
| auth/login_screen.dart; auth/login_screen_v2.dart; auth/signup_screen.dart | Partial: Firebase sign-in, signup and password reset exist; visual/validation parity pending |
| auth/signup_screen.dart | Partial: basic signup and plan selection exist; full onboarding parity pending |
| dashboard_screen.dart | Partial: admin/super-admin live operations dashboard implemented; role-specific employee dashboard pending |
| restaurant_dashboard_screen.dart; restaurant_dashboard_screen_v2.dart; restaurant_dashboard_screen_v3.dart | Partial: live today sales/receipts/average bill, active tables, PRA finalized, 7-day sales chart, KOT queue counts, top-selling items, low-stock alerts, recent receipts and branch cards; dashboard section customization and full analytics parity pending |
| restaurant_command_center_screen.dart | Missing |
| employee_dashboard_screen.dart; role_home_screen.dart | Partial: role-limited personal profile, today attendance/worked hours, tips, service charges, points, rating/reviews and permission-gated commission visibility and permission-gated profile photo upload to the Flutter Storage path; personal widget hide/restore and role-specific action widgets pending |
| categories_screen.dart; category_products_screen.dart | Partial: category create/edit/delete, active state and image upload lifecycle; category-specific product browsing and full pagination parity pending |
| products_screen.dart | Improved partial parity: create/edit/delete, active status, active-category selection, structured variant and ProductAttribute editors, image preview/upload/replacement/removal, best-effort primary-image cleanup, image column and structured details, and 20-record cursor pagination; exact Flutter layout and dedicated-tenant tests pending. Flutter Product model has no variant-image or extra flag fields beyond active/hasVariants. |
| pos_order_screen_v2.dart through pos_order_screen_v7.dart | Partial: core order/cart slice only; exact workflow parity pending |
| table_management_screen.dart; table_management_screen_v2.dart | Partial: table list/create and order save-restore; edit/delete and full layout parity pending |
| table_order_screen.dart | Partial |
| orders_screen.dart; kitchen_kot_screen.dart | Orders partial parity: status/date filters, 20-record cursor pagination, structured order/item details, mark-completed action and delete confirmation. Kitchen KOT remains implemented with queue status transitions; delivery/customer lifecycle and visual parity pending |
| payment_screen.dart; payment_success_screen.dart; pricing_screen.dart | Missing: Stripe/subscription lifecycle not ported |
| sale_screen.dart | Improved partial parity: sale history search, date filters, 20-record cursor pagination, structured sale/item details and receipt reprint; export and full parity pending |
| sale_return_screen.dart; select_return_items_screen.dart | Improved partial parity: original-sale picker, selected item workflow with all items selected by default, individual product selection, source-sale and quantity validation, refund calculation, structured details, search/date filters and 20-record cursor pagination; dedicated-tenant tests pending. Flutter return flow does not restore inventory. |
| purchases_screen.dart | Improved partial parity: supplier picker, product/variant picker, editable purchase line items, status/date, create/edit/delete, batched stock adjustments, structured item details, search, status/date filters and 20-record cursor pagination; responsive Flutter card/table parity and dedicated-tenant tests pending. |
| purchase_return_screen.dart; select_purchase_return_items_screen.dart | Improved partial parity: original-purchase selector, supplier auto-link, all items selected by default, individual product selection (all matching purchase lines retained), reason capture, refund calculation, source-purchase quantity/supplier validation, structured details, search/date filters and 20-record cursor pagination; responsive Flutter card/table parity and dedicated-tenant tests pending. Flutter return flow does not change stock. |
| suppliers_screen.dart | Partial: schema-aligned create/edit/delete, phone/address validation, active status and supplier balances; supplier ledger/reconciliation workflows pending |
| customers_screen.dart | Partial: schema-aligned create/edit/delete, name/phone/address/email validation, active status and customer lifetime-spend display; review/feedback workflows pending |
| discounts_screen.dart | Partial: discount create/edit/delete, active state, percentage/fixed type and image lifecycle; checkout application and usage tracking pending |
| ingredients_screen.dart; recipe_assignment_screen.dart | Partial: ingredient create/edit/delete with unit and stock-threshold validation; product recipe assignment with ingredient quantities, live producible-unit estimate and recipe deletion; ingredient consumption on sale and stock reconciliation pending |
| store_out_screen.dart; add_edit_store_out_screen.dart | Improved partial parity: structured product/variant picker, reason/handler/date fields, create-time stock deductions with availability validation, edit without stock movement, soft delete without stock restoration, search/date filters, structured details and 20-record cursor pagination; card/list views and visual parity pending |
| expenses_screen.dart | Partial: add/list/delete, expense categories, amount/note and creator/branch metadata, search/date filters, structured details and 20-record cursor pagination; reporting and visual parity pending |
| staff_screen.dart | Partial: staff create/edit/delete with model fields and search keywords; photo, attendance and performance workflows pending |
| attendance_screen.dart; monthly_attendance_screen.dart | Improved partial parity: daily staff/date present/absent marking with duplicate-safe updates, monthly staff grouping, present-day counts, hour totals and wage calculations matching the Attendance model; visual parity and dedicated-tenant tests pending |
| monthly_attendance_screen.dart | Missing |
| branches_screen.dart | Partial: branch create/edit/delete, active status, branch code/address and source premiumFeature/createdAt metadata; main-branch card and branch-scoped data enforcement pending |
| users_roles_screen.dart | Partial: department account creation using a secondary Firebase Auth app, linked vendor/staff documents, standard role permission presets, active/disabled toggle, password reset and profile-photo/commission visibility controls; dedicated-tenant account lifecycle tests and custom permission editing pending |
| settings_hub_screen.dart; settings_screen.dart | Partial: admin-only restaurant profile editing for account name, restaurant name, location, phone and logo upload to the Flutter Storage path; settings hub tiles and password/security workflows pending |
| pra_settings_screen.dart | Partial: load/save registration number, POS ID, masked token and enabled state in the original integrations/pra document; no live PRA API transmission is attempted |
| splash_screen.dart | Missing |

## Provider/domain parity

All of these Flutter providers require schema-accurate ports and tests; only the narrow auth/cart/product/table/order/sale slice has partial counterparts today.

- attendance_provider.dart
- auth_provider.dart
- cart_provider.dart
- category_provider.dart
- customer_provider.dart
- discount_provider.dart
- ingredient_provider.dart
- locale_provider.dart
- order_provider.dart
- product_provider.dart
- purchase_provider.dart
- purchase_return_provider.dart
- recipe_provider.dart
- sale_provider.dart
- sale_return_provider.dart
- staff_provider.dart
- statistics_provider.dart
- store_out_provider.dart
- subscription_provider.dart
- supplier_provider.dart
- table_order_provider.dart
- table_provider.dart
- theme_provider.dart

## Service and integration parity

| Flutter service | Required Next.js equivalent | Status |
|---|---|---|
| firebase_service.dart; auth_service.dart | Firebase initialization, auth, tenant resolution and access rules | Partial |
| product_service.dart; category_service.dart | Product/category CRUD, active state, variants, attributes, images and stock | Partial; category active-state CRUD and product source-model parity implemented, dedicated tenant tests pending |
| order_service.dart | Full order lifecycle, KOT, per-item status and kitchen queue | Partial |
| sale_service.dart | Sales, billing counters, idempotency, history and exports | Partial |
| transaction_billing_service.dart; usage_billing_reconciliation_service.dart | Exact billing/usage semantics and reconciliation | Partial; transaction behavior requires dedicated tests |
| document_print_service.dart; pdf_service.dart | Exact receipt/KOT PDF layouts, browser print and supported printer workflows | Partial |
| image_upload_service.dart | Firebase Storage upload/delete and image URL lifecycle | Partial: product/category/discount upload and replaced-image cleanup; product primary-image cleanup on delete |
| stripe_service.dart; subscription_service.dart | Stripe checkout, webhook/server verification, plan/access lifecycle | Missing |
| purchase_service.dart | Purchase create/edit/delete with purchase item schema and stock adjustments | Partial: supplier/product/variant picker, item editor, status/date and list filters added; stock effects mirror source service; transactional edge cases and dedicated-tenant tests pending |
| purchase_return_service.dart | Purchase return records and detail workflow | Partial: create schema and source-linked item selection ported; full-item selection mirrors Flutter, source purchase and supplier validation, list details, filters and pagination added; dedicated-tenant tests pending. Original screen exposes view/create, not edit/delete. |
| sale_return_service.dart | Sale return records and detail workflow | Partial: original-sale selection, selected-item snapshots, refund totals, reason, source-sale quantity validation, structured details, search/date filters and cursor pagination ported; dedicated-tenant tests pending. Original Flutter service does not restore inventory. |
| supplier_service.dart; customer_service.dart | Supplier/customer CRUD and relations | Partial: customer and supplier create/edit/delete, source model fields, active status and supplier balance fields; customer review metrics and supplier financial reconciliation remain pending |
| discount_service.dart | Discount rules and application | Partial: discount CRUD and active/type/value model fields; checkout calculation/application and usage tracking pending |
| ingredient_service.dart; recipe_service.dart | Ingredients, recipes and stock consumption | Partial: ingredient CRUD and per-product recipe document save/load/delete are implemented; recipe-driven ingredient deductions during checkout and inventory reconciliation pending |
| store_out_service.dart | Store-out CRUD and stock movement | Partial: source snapshot schema, create-time stock deduction, edit-without-stock-movement and soft-delete semantics ported; bulk/date/reason search and transaction-level E2E coverage pending |
| staff_service.dart; attendance_service.dart; staff_performance_service.dart | Staff, roles, attendance and performance | Missing |
| session_audit_service.dart | Session/audit trail | Missing |
| notification_service.dart | Notification behavior | Missing |
| dummy_data_service.dart | Test/demo data only; never production-seeded | Not assessed |

## Platform/dependency requirements identified in Flutter source

- Firebase Core, Authentication, Cloud Firestore and Firebase Storage.
- Stripe (Flutter Stripe, web Stripe, Stripe SDK); server-side payment verification must be preserved.
- PDF generation and printing (pdf, printing); browser print is not assumed equivalent to the original printer integrations.
- HTTP integrations and URL launching.
- Image picking, uploads, cached network images.
- Locale/number/date formatting, persistent preferences and UUID generation.
- PRA settings/integration is represented in the app; exact API/configuration and fiscal payload behavior still need targeted source review.

## Required acceptance gates before calling this a ditto copy

1. Every source screen and navigation path has a corresponding Next.js screen/flow.
2. Every provider/service has an equivalent implementation with matching Firestore collections, fields, queries, writes, transactions and error behavior.
3. Roles, branch scoping, subscription gates and route guards match Flutter behavior.
4. Full order, table, KOT, checkout, payment, inventory, returns, purchase, customer, supplier, staff, attendance, expense, discount, recipe and reporting workflows pass tests.
5. Stripe and PRA integrations are validated in their respective sandbox/test environments.
6. Receipt/KOT output and supported printer workflows are compared against Flutter output.
7. Desktop, tablet and mobile responsive behavior is verified.
8. Typecheck, production build, automated tests and dedicated-tenant end-to-end tests pass.
9. Production cutover plan, backup and rollback are prepared; production deployment remains a separate approval step.

**Current overall status: INCOMPLETE.** Most management collections remain read-only; staff and expense operations are still partial, and several other limited create/edit forms are not full CRUD. Inventory side effects, reports, subscription gates, complete role/branch enforcement and model-specific validation are still incomplete. This register records scope and prevents the partial POS slice from being mistaken for feature parity.
