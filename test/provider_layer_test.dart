// The bridge between repositories and widgets.
//
// Stage 8's deliverable, tested before a single screen was touched. Three
// things are worth pinning here and nowhere else:
//
// 1. **The shell's three states.** It is the one place in the app where a
//    query gates every store-scoped screen at once, so a skeleton, a resolved
//    establishment and an empty database all have to render something usable.
// 2. **That a write reaches a screen with nothing in between.** Phase 1 needed
//    a global revision counter and 23 screens that remembered to watch it. If
//    this passes, that machinery has a replacement rather than a gap.
// 3. **The `AsyncValue` house rule**, including the part that is easy to get
//    backwards: when one of several queries fails, the screen shows the error
//    rather than a skeleton that will never resolve.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/app.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'package:stock_inventory/core/theme/app_theme.dart';
import 'package:stock_inventory/data/database/app_database.dart';
import 'package:stock_inventory/data/current_employee.dart';
import 'package:stock_inventory/data/providers.dart';
import 'package:stock_inventory/data/repositories/repositories.dart';
import 'package:stock_inventory/l10n/app_localizations.dart';
import 'package:stock_inventory/data/seed/dataset/dataset.dart'
    show ItemIds, StoreIds;
import 'package:stock_inventory/models/models.dart';
import 'package:stock_inventory/shared/widgets/widgets.dart';

import 'support/app_harness.dart';
import 'support/db_fixture.dart';

const Size _tablet = Size(1280, 800);

/// A single widget, localized and themed, over a database.
Widget _host(AppDatabase db, Widget child) {
  return ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: MaterialApp(
      locale: const Locale('fr', 'BE'),
      supportedLocales: const [Locale('fr', 'BE')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('the shell', () {
    testApp('draws its chrome as a skeleton while the query is out', (
      tester,
    ) async {
      tester.view.physicalSize = _tablet;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // A query that never answers, which is what a cold start on a real file
      // looks like for the first frames. An in-memory database answers inside
      // the same batch of microtasks, so the loading frame is unobservable
      // through the router unless it is held open deliberately.
      final AppDatabase db = await openSeededDatabase();
      seedCurrentEmployeeSnapshot(fakeOwner());
      addTearDown(() => seedCurrentEmployeeSnapshot(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            currentStoreProvider.overrideWith(
              (ref, id) => Completer<Store?>().future.asStream(),
            ),
          ],
          child: const StockInventoryApp(),
        ),
      );
      await tester.pump();

      appRouter.go(Routes.toDashboard(StoreIds.sablon));
      await tester.pump();
      // Long enough for the page transition, short of settling: the skeleton
      // pulses on a repeating controller, so `pumpAndSettle` would never
      // return while one is on screen.
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AppScaffoldSkeleton), findsOneWidget);
      expect(find.byType(AppScaffold), findsNothing);

      // Chrome, not a blank page: the rail and the top bar hold their place so
      // the content area is the only thing that moves when the store lands.
      expect(find.byType(SkeletonBlock), findsWidgets);
    });

    testApp('says so rather than showing empty chrome when there are no '
        'establishments', (tester) async {
      tester.view.physicalSize = _tablet;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // The schema without the seed — reachable in the app only if the first
      // launch failed to seed, which is exactly when a blank rail would be
      // least helpful.
      await pumpAppWith(
        tester,
        openEmptyDatabase(),
        asEmployee: fakeOwner(),
      );
      appRouter.go(Routes.toDashboard(StoreIds.sablon));
      await tester.pumpAndSettle();

      expect(find.byType(AppScaffoldNoStore), findsOneWidget);
      expect(find.text('Aucun établissement'), findsOneWidget);
    });

    testApp('falls back to the first establishment for an id that does not '
        'resolve', (tester) async {
      tester.view.physicalSize = _tablet;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final AppDatabase db = await openSeededDatabase();
      await pumpAppWith(tester, db);

      appRouter.go(Routes.toDashboard('store-that-was-deleted'));
      await tester.pumpAndSettle();

      expect(find.byType(AppScaffold), findsOneWidget);
      expect(find.byType(AppScaffoldNoStore), findsNothing);
    });
  });

  group('a write reaches the screen', () {
    testApp('without a revision counter in between', (tester) async {
      final AppDatabase db = await openSeededDatabase();

      await tester.pumpWidget(
        _host(
          db,
          Consumer(
            builder: (context, ref, _) => AsyncContent<List<Category>>(
              value: ref.watch(categoriesProvider(StoreIds.sablon)),
              builder: (context, categories) =>
                  Text('${categories.length} catégories'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('7 catégories'), findsOneWidget);

      // Nothing tells the widget about this. drift notices the table changed,
      // re-runs the query behind `categoriesProvider`, and the stream pushes.
      await CatalogRepository(
        db,
      ).createCategory(storeId: StoreIds.sablon, name: 'Conserves');
      await tester.pumpAndSettle();

      expect(find.text('8 catégories'), findsOneWidget);
    });

    testApp('and the skeleton does not flash while it does', (tester) async {
      final AppDatabase db = await openSeededDatabase();

      await tester.pumpWidget(
        _host(
          db,
          Consumer(
            builder: (context, ref, _) => AsyncContent<List<Category>>(
              value: ref.watch(categoriesProvider(StoreIds.sablon)),
              skeleton: const Text('chargement'),
              builder: (context, categories) =>
                  Text('${categories.length} catégories'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await CatalogRepository(
        db,
      ).createCategory(storeId: StoreIds.sablon, name: 'Conserves');

      // The frame between the write and the new rows arriving still shows the
      // old rows. A screen that blinks its skeleton every time somebody adds a
      // line is unusable during service.
      await tester.pump();
      expect(find.text('chargement'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('8 catégories'), findsOneWidget);
    });
  });

  group('AsyncContent', () {
    testApp('shows the skeleton, then the content', (tester) async {
      final AppDatabase db = await openSeededDatabase();

      await tester.pumpWidget(
        _host(
          db,
          Consumer(
            builder: (context, ref, _) => AsyncContent<Item?>(
              value: ref.watch(itemProvider(ItemIds.poulet)),
              builder: (context, item) => Text(item?.name ?? 'absent'),
            ),
          ),
        ),
      );

      // No pump: `pumpWidget` has already drawn one frame, and that is the
      // frame where the query is out. One more and the in-memory database has
      // answered.
      expect(find.byType(SkeletonList), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(SkeletonList), findsNothing);
      expect(find.text('Blanc de poulet'), findsOneWidget);
    });

    testApp('renders ErrorState with a working retry when the query fails', (
      tester,
    ) async {
      final AppDatabase db = openEmptyDatabase();
      var retried = 0;

      await tester.pumpWidget(
        _host(
          db,
          AsyncContent<int>(
            value: AsyncValue<int>.error(
              StateError('database is gone'),
              StackTrace.current,
            ),
            onRetry: () => retried++,
            builder: (context, value) => Text('$value'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.text('Une erreur est survenue'), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(retried, 1);
    });

    testApp('an empty result is a state of its own, not a blank list', (
      tester,
    ) async {
      final AppDatabase db = await openSeededDatabase();

      await tester.pumpWidget(
        _host(
          db,
          Consumer(
            builder: (context, ref, _) => AsyncListContent<Item>(
              // The third establishment is genuinely empty — that is what it is
              // in the dataset for.
              value: ref.watch(itemsByNameProvider(StoreIds.saintGilles)),
              empty: const Text('aucun article'),
              builder: (context, items) => Text('${items.length} articles'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('aucun article'), findsOneWidget);
    });
  });

  group('combining several queries', () {
    test('waits for all of them', () {
      expect(
        asyncAll2(
          const AsyncValue<int>.data(1),
          const AsyncValue<int>.loading(),
          (a, b) => a + b,
        ).isLoading,
        isTrue,
      );

      expect(
        asyncAll2(
          const AsyncValue<int>.data(1),
          const AsyncValue<int>.data(2),
          (a, b) => a + b,
        ).value,
        3,
      );
    });

    test('lets an error win over a still-loading query', () {
      // The one that is easy to get backwards. If loading won, a screen whose
      // first query failed and whose second never answers would show a skeleton
      // for ever — the worst of the three states, because it asks the user to
      // wait for something that is not coming.
      final combined = asyncAll3(
        const AsyncValue<int>.loading(),
        AsyncValue<int>.error(StateError('no'), StackTrace.current),
        const AsyncValue<int>.data(3),
        (a, b, c) => a + b + c,
      );

      expect(combined.hasError, isTrue);
      expect(combined.isLoading, isFalse);
    });

    test('folds four the same way', () {
      expect(
        asyncAll4(
          const AsyncValue<int>.data(1),
          const AsyncValue<int>.data(2),
          const AsyncValue<int>.data(3),
          const AsyncValue<int>.data(4),
          (a, b, c, d) => a + b + c + d,
        ).value,
        10,
      );
    });
  });

  group('family keys', () {
    test('an equal filter is the same query', () {
      // Riverpod keys a family on `==`. Without value equality on [ItemFilter],
      // a screen rebuilding on every keystroke would hand the family a new key
      // each time, tearing down a live query only to open the same one again.
      const a = ItemFilter(categoryId: 'cat-viandes', lowStockOnly: true);
      const b = ItemFilter(categoryId: 'cat-viandes', lowStockOnly: true);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        (storeId: StoreIds.sablon, filter: a),
        (storeId: StoreIds.sablon, filter: b),
      );
    });

    test('a different filter is a different query', () {
      expect(
        const ItemFilter(categoryId: 'cat-viandes'),
        isNot(const ItemFilter(categoryId: 'cat-boissons')),
      );
    });
  });
}
