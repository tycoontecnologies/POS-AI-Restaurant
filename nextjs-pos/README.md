# Tycoon POS — Next.js rebuild

This application is developed alongside the existing Flutter POS. It is isolated under nextjs-pos/; the Flutter app, Firebase configuration, Cloud Functions, and production hosting files are not changed.

## Run locally
Requires Node.js 24.12 or newer.
1. Copy .env.example to .env.local.
2. Run npm install.
3. Run npm run dev (port 3020).
4. Sign in with an existing Tycoon POS Firebase Authentication account.

## Implemented migration slice
- Firebase Authentication sign-in, signup, password reset and vendor profile lookup.
- Realtime product, table, and table-order subscriptions.
- Category filtering, product search, variant selection, stock-aware cart.
- Persist and restore open table orders using vendors/{vendorId}/tableOrders/{tableId}; cart changes sync in realtime and table creation is supported.\n- Quick-sale checkout and receipt printing without a table assignment.
- Save KOT state as making and mark the table occupied.
- Tables / Items and Modern / Legacy controls remain inside the hamburger menu.

## Management workspace added
The hamburger menu now exposes live vendor-scoped record views for dashboard/sales, categories, customers, discounts, ingredients, purchases and returns, suppliers, staff, attendance, store-out, branches, expenses and orders. Products, categories, customers, suppliers, discounts and ingredients have schema-shaped create/edit forms. Other management views remain read-only. Table creation is available in the Tables workspace. Role filtering is partial and does not replace the full Flutter route, subscription or permission guards.

## Not yet production-ready
The Flutter application also contains sale finalization and receipt metering, thermal/PDF printing, kitchen workflow, order history, discounts, checkout/subscriptions, inventory, purchases, staff, attendance, expenses, returns, PRA, permissions, branch behavior, and settings. Those still require migration and verification against their existing Firestore schemas.

The current checkout creates completed sales and records the idempotent per-receipt billing ledger, but it does not yet reproduce all Flutter checkout, inventory, discount, customer, PRA or receipt/PDF behaviors. No sample data is written to Firestore.