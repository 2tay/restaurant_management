# Restaurant Multi-Store Inventory App — Flutter — Phase 1 (UI Only)

## 1. Project Summary

A **Flutter tablet application** for restaurant owners who operate **multiple locations under a single account**. The owner logs in once, sees all stores linked to that account, taps into one store, and from that point sees only that store's data (items, stock, suppliers, reports, team).

**Phase 1 is UI ONLY.**
- No database, no repositories, no state management logic, no API calls, no local persistence.
- Every screen renders from **static mock data** kept in a dedicated folder.
- Deliverable is a fully navigable, polished, demo-ready tablet prototype — not a functioning app.
- Phase 2 (later, separate brief) adds local-first storage and online sync. Do **not** implement it now, but structure the project so it slots in without a rewrite (see Architecture).

## 2. Target Platform

- **Flutter**, targeting **Android and iOS tablets** (landscape-first, must not break in portrait).
- Design breakpoint baseline: ~10-inch tablet, landscape (roughly 1280×800 logical px). Support down to ~7-inch tablet gracefully.
- Phone layout is **not** a Phase 1 requirement — do not spend effort on phone-specific layouts, but avoid hardcoding pixel widths that would make it impossible later.

## 3. Who Uses This

Restaurant staff and managers, on a tablet, frequently **during busy service hours** — loud kitchen, wet or greasy hands, standing up, moving fast, interrupted constantly. This is not a calm desk-based admin dashboard. Build for that reality:

- Large tap targets — minimum 48×48 dp, prefer larger for primary actions
- Minimal typing — favor pickers, number steppers, dropdowns, chips, and toggles over free-text fields
- High contrast, readable at arm's length, no small low-contrast gray text
- One obvious primary action per screen — never ambiguous what to do next
- Destructive actions (delete item, remove supplier link) always require a confirmation dialog
- Forgiving — easy to edit or undo, nothing feels permanent or scary
- Plain language, no jargon: "Add Delivery," not "Create Stock Ingress Record"
- Loading, empty, and error states are designed deliberately — a rushed user must never wonder "did that save?"
- Immediate visual feedback on every action (SnackBar / toast confirmation like "Delivery logged")

**Tone:** calm, professional, dependable — like a well-run kitchen. Not playful, not corporate-cold. Clarity over decoration, but still considered and modern rather than bare-bones. Avoid generic template-dashboard aesthetics.

## 4. Tech Stack (Phase 1)

- **Flutter** (latest stable) + **Dart**
- **Material 3** as the base design system, with a custom theme (do not ship default Material colors)
- **go_router** for declarative navigation and nested/shell routes (sidebar shell + content area)
- **flutter_riverpod** — permitted **only** for trivial local UI state (selected tab, expanded panel, filter chip). No data layer, no repositories, no providers wrapping business logic in this phase.
- **intl** for date/number/currency formatting
- Icons: Material Icons (or `lucide_icons` if a more distinctive set is wanted)
- Charts (reports screens only): `fl_chart` with static hardcoded values
- **No** database packages, **no** http/dio, **no** auth SDKs in Phase 1. Login and Sync screens are visual only — buttons navigate but authenticate/sync nothing.

## 5. Architecture — Feature-First, Phase 2 Ready

Use a **feature-first** structure so Phase 2 can add `data/` and `domain/` layers inside each feature without touching the UI.

```
lib/
  main.dart
  app/
    app.dart                    # MaterialApp.router, theme wiring
    router.dart                 # go_router config, shell route for sidebar layout
  core/
    theme/
      app_theme.dart            # ThemeData, Material 3 color scheme
      app_colors.dart           # named palette + status colors
      app_typography.dart       # type scale
      app_spacing.dart          # spacing/radius constants
    constants/
      app_strings.dart
    utils/
      formatters.dart           # currency, date, quantity formatting
      responsive.dart           # breakpoint helpers for tablet layouts
  features/
    auth/
      presentation/
        pages/
          login_page.dart
          forgot_password_page.dart
          onboarding_page.dart
        widgets/
    stores/
      presentation/
        pages/
          store_selector_page.dart
          add_store_page.dart
        widgets/
          store_card.dart
    dashboard/
      presentation/
        pages/store_dashboard_page.dart
        widgets/
          summary_tile.dart
          quick_action_button.dart
          recent_activity_list.dart
    inventory/
      presentation/
        pages/
          inventory_list_page.dart
          item_detail_page.dart
          add_edit_item_page.dart
          link_supplier_to_item_page.dart
          item_price_history_page.dart
        widgets/
          item_row.dart
          item_card.dart
          stock_status_badge.dart
          supplier_price_row.dart
    catalog/                    # dynamic categories + units
      presentation/
        pages/
          categories_page.dart
          units_page.dart
        widgets/
          category_tile.dart
          unit_tile.dart
    stock_movement/
      presentation/
        pages/
          stock_in_page.dart
          stock_out_page.dart
          stock_adjustment_page.dart
          stock_history_page.dart
        widgets/
          quantity_stepper.dart
          movement_row.dart
    alerts/
      presentation/
        pages/
          low_stock_alerts_page.dart
          notifications_page.dart
    suppliers/
      presentation/
        pages/
          suppliers_list_page.dart
          supplier_detail_page.dart
          add_edit_supplier_page.dart
          supplier_pricing_page.dart
        widgets/
          supplier_card.dart
          supplier_price_table.dart
    reports/
      presentation/
        pages/
          reports_dashboard_page.dart
          stock_valuation_report_page.dart
          price_comparison_report_page.dart
          usage_report_page.dart
        widgets/
          export_dialog.dart
    team/
      presentation/
        pages/
          team_list_page.dart
          add_edit_member_page.dart
          roles_permissions_page.dart
    settings/
      presentation/
        pages/
          store_settings_page.dart
          account_settings_page.dart
          notification_preferences_page.dart
          sync_status_page.dart
  shared/
    widgets/
      app_scaffold.dart         # shell: NavigationRail sidebar + top bar + content
      app_sidebar.dart
      app_top_bar.dart
      store_switcher.dart
      offline_banner.dart
      primary_button.dart
      secondary_button.dart
      destructive_button.dart
      app_card.dart
      app_text_field.dart
      app_dropdown.dart          # includes "+ Create new" affordance
      confirm_dialog.dart
      empty_state.dart
      loading_state.dart
      error_state.dart
      search_field.dart
      section_header.dart
      data_table_wrapper.dart
  models/                        # plain Dart classes describing SHAPE only
    store.dart
    item.dart
    supplier.dart
    supplier_price.dart          # item + supplier + price + effectiveDate
    price_history_entry.dart
    category.dart
    unit_of_measure.dart
    stock_movement.dart
    team_member.dart
    notification_item.dart
  mock_data/                     # ALL static data lives here — nowhere else
    mock_stores.dart
    mock_items.dart
    mock_suppliers.dart
    mock_supplier_prices.dart
    mock_price_history.dart
    mock_categories.dart
    mock_units.dart
    mock_stock_movements.dart
    mock_team.dart
    mock_reports.dart
    mock_notifications.dart
  services/                      # Phase 2 STUBS — create files, write NO logic
    local_database_service.dart  // TODO: Phase 2 — local-first storage (drift/isar)
    sync_service.dart            // TODO: Phase 2 — offline queue + conflict resolution
    api_service.dart             // TODO: Phase 2 — remote API client
    auth_service.dart            // TODO: Phase 2 — real authentication
```

**Rules for Phase 1:**
- `mock_data/` is the only place static data lives. Pages import from it — never inline large fake lists inside a widget.
- `models/` holds **immutable plain Dart classes with a constructor and fields only**. No `fromJson`/`toJson`, no persistence annotations, no methods with logic. These exist purely to give the UI a typed shape and make Phase 2 trivial.
- `services/` files exist as empty classes with a single `// TODO: Phase 2` comment. Do not implement them.
- Each feature folder has only `presentation/` in Phase 1. Phase 2 will add sibling `data/` and `domain/` folders — leave room for that, don't flatten the structure.

## 6. Key Domain Rules the UI Must Reflect

These are the non-obvious business realities the screens must express, even with fake data:

1. **One product can be supplied by multiple suppliers**, each with **their own price** for that product. Price is an attribute of the *item–supplier link*, not of the item itself.
   → An item has **no single "cost" field**. Item Detail shows a list of suppliers with a price each.
2. **A supplier's price for a product changes over time.** Every price change is recorded as a history entry (date, old price, new price, changed by).
   → There is a dedicated Price History screen scoped to an *item + supplier* pair.
3. **Categories and Units of Measure are created dynamically inside the app**, not hardcoded.
   → Every category/unit dropdown includes an inline "+ Create new" option, and both have their own full management screens.
4. **Store scoping:** after a store is selected, all inventory/supplier/report/team screens show data for that store only. The store switcher stays visible in the top bar at all times.

## 7. Screens to Build

Use a persistent **NavigationRail sidebar + top bar shell** (go_router ShellRoute), with content in the main area. Not bottom navigation — this is a tablet.

### Auth & Onboarding
- Login (email, password, remember me, forgot password)
- Forgot / Reset Password (email input → confirmation state)
- Onboarding (optional, keep simple)

### Store Selection
- Store Selector — grid of store cards: name, logo/image, low-stock alert badge
- Add / Switch Store

### Dashboard
- Store Dashboard — stock summary tiles, low-stock count, recent activity feed, large quick-action buttons (Add Delivery, Log Usage, Add Item, View Alerts)

### Inventory
- Inventory List — search, filter by category and supplier, sort, status badges
- Item Detail — quantity, unit, threshold, stock history, and a **Suppliers section** listing each supplier with their current price and last-updated date
- Add / Edit Item — name, category (dropdown + create new), unit (dropdown + create new), starting quantity, low-stock threshold. **No cost field here.**
- Link Supplier to Item — pick supplier (or create new), set price per unit, optionally mark as default supplier
- Item Price History — timeline/table of price changes for one item from one supplier

### Categories & Units
- Categories — list, add, edit, delete (with confirm)
- Units of Measure — list, add, edit, delete (name + abbreviation)

### Stock Movement
- Stock In / Receive Delivery — item, **supplier selector that auto-fills that supplier's current price (editable)**, quantity, date
- Stock Out / Usage & Waste — item, quantity, reason (sale / waste / transfer / spoilage)
- Stock Adjustment — physical count vs system count correction
- Stock Movement History — chronological log, filterable by date, item, user, supplier

### Alerts
- Low Stock Alerts — all items below threshold
- Notifications Center — low stock, price changes, large adjustments

### Suppliers
- Suppliers List — name, contact, count of products supplied
- Supplier Detail — contact info + all products they supply with current price each
- Add / Edit Supplier
- Supplier Pricing — editable price table; changing a price writes a (mock) history entry

### Reports
- Reports Dashboard — stock valuation, usage trend, waste % overview tiles
- Stock Valuation Report — breakdown by category/item
- **Price Comparison Report** — one item, all suppliers' prices side by side (this is a key selling feature for a multi-store owner)
- Usage / Movement Report — date-range filterable
- Export dialog — visual only, no real file generation

### Team
- Team Members List — staff, role, store access
- Add / Invite Member
- Edit Member / Role
- Roles & Permissions — simple matrix view

### Settings
- Store Settings — name, address, logo, default unit preference
- Account Settings — profile, password, linked stores
- Notification Preferences — toggles including price-change alerts
- Sync Status — last synced time, "Sync now" button, pending changes count (all static/fake)

### Global
- Global Search — filters the static mock data client-side
- Offline banner — persistent slim bar showing offline mode + pending sync count; include a debug toggle so it can be demoed

## 8. Design Direction

- **Layout:** NavigationRail (left) + top bar (store switcher, search, notifications, account avatar) + content area. On wider tablets, use master–detail split views where it helps — e.g. Inventory List on the left, Item Detail on the right — rather than full-screen navigation for every tap.
- **Color:** define a 4–6 color named palette in `app_colors.dart`. Ground it in the kitchen/restaurant world (stainless steel, chalkboard slate, fresh produce accent) rather than generic SaaS blue/purple gradients, and avoid the overused cream + terracotta combination. Include an unmistakable status triad used everywhere: **in stock / low stock / out of stock** — these must be distinguishable instantly, at a glance, from a distance, and not rely on color alone (pair with icon or label for accessibility).
- **Typography:** one highly legible sans-serif, clear type scale defined in `app_typography.dart`, generous line height on data-dense tables. Legible at arm's length on a mounted or counter-resting tablet.
- **Priority components to nail first:** `PrimaryButton` (large), `StockStatusBadge`, `QuantityStepper` (tap-to-increment, minimal typing), `ConfirmDialog`, `EmptyState`, and SnackBar confirmations.
- **Empty states:** a new store with no items shows "Add your first item" with a button — never a blank table.
- **Confirmations:** deleting an item, removing a supplier link, or a large downward stock adjustment always confirms first.

## 9. Out of Scope for Phase 1

- Real authentication or sessions
- Any database or local persistence (no drift, isar, sqflite, hive, shared_preferences for data)
- Real sync or offline queue logic — stub files only
- Any network calls
- Repositories, data sources, use cases, or business logic layers
- Real PDF/CSV export
- Recipe / BOM costing and POS integration (out of the MVP entirely, not just this phase)

## 10. Deliverable

A running Flutter tablet app where every screen listed above is reachable through the sidebar and navigation flows, populated with realistic mock restaurant data — real-sounding items ("Chicken Breast," "Olive Oil," "Tomatoes," "Heineken 33cl"), realistic suppliers, realistic categories (Produce, Meat, Dairy, Beverages, Dry Goods), multiple suppliers per item with differing prices, and plausible price-change history. Fully clickable, landscape-tablet optimized, and visually polished enough to demo to the restaurant owner as a believable product — even though nothing is wired to real data yet.