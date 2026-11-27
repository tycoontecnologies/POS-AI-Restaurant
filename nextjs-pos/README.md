# Tycoon POS — Next.js rebuild

This application is developed alongside the existing Flutter POS. It is isolated under nextjs-pos/; the Flutter app, Firebase configuration, Cloud Functions, and production hosting files are not changed.

## Run locally
1. Copy .env.example to .env.local.
2. Run npm install.
3. Run npm run dev (port 3020).
4. Sign in with an existing Tycoon POS Firebase Authentication account.

## Implemented migration slice
- Firebase Authentication sign-in and vendor profile lookup.
- Realtime product, table, and table-order subscriptions.
- Category filtering, product search, variant selection, stock-aware cart.
- Persist and restore open table orders using vendors/{vendorId}/tableOrders/{tableId}.
- Save KOT state as making and mark the table occupied.
- Tables / Items and Modern / Legacy controls remain inside the hamburger menu.

## Management workspace added\nThe hamburger menu now exposes live vendor-scoped record views for dashboard/sales, categories, customers, discounts, ingredients, purchases and returns, suppliers, staff, attendance, store-out, branches, expenses and orders. Categories, customers, suppliers, discounts and ingredients have schema-shaped create forms. Other management views remain read-only; this is not yet full Flutter CRUD or workflow parity.\n\n## Not yet production-ready
The Flutter application also contains sale finalization and receipt metering, thermal/PDF printing, kitchen workflow, order history, discounts, checkout/subscriptions, inventory, purchases, staff, attendance, expenses, returns, PRA, permissions, branch behavior, and settings. Those still require migration and verification against their existing Firestore schemas.

This first slice does not create completed sales or decrement stock. Sale finalization must preserve TransactionBillingService.recordSuccessfulReceipt idempotency and must not bypass the current billing ledger. No sample data is written to Firestore.