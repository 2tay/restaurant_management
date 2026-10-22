// The green top bar on a phone: the store's name, the notifications, and —
// at the right — the user's avatar, which opens the profile menu under it.
// The drawer no longer repeats the profile; a tablet keeps it in the sidebar.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory/app/router.dart';
import 'package:stock_inventory/app/routes.dart';
import 'support/seed/dataset/dataset.dart';
import 'package:stock_inventory/shared/widgets/widgets.dart';

import 'support/app_harness.dart';

const String _store = StoreIds.sablon;
const Size _phone = Size(390, 844);
const Size _tablet = Size(1280, 800);
const _profileButton = ValueKey('phone-profile-button');

Future<void> _open(WidgetTester tester, Size size) async {
  await pumpApp(tester, size: size);
  appRouter.go(Routes.toInventory(_store));
  await tester.pumpAndSettle();
}

void main() {
  testApp('a phone: the avatar sits right of the bell, in the green bar', (
    tester,
  ) async {
    await _open(tester, _phone);

    final bar = find.byType(AppBar).first;
    final button = find.descendant(
      of: bar,
      matching: find.byKey(_profileButton),
    );
    expect(button, findsOneWidget);

    final bell = find.descendant(
      of: bar,
      matching: find.byTooltip('Notifications'),
    );
    expect(bell, findsOneWidget);
    expect(
      tester.getCenter(button).dx,
      greaterThan(tester.getCenter(bell).dx),
    );
  });

  testApp('tapping it drops the profile menu under it', (tester) async {
    await _open(tester, _phone);

    final button = tester.getRect(find.byKey(_profileButton));
    await tester.tap(find.byKey(_profileButton));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final stores = find.text('Mes établissements');
    expect(stores, findsOneWidget);
    expect(find.text('Paramètres'), findsWidgets);
    expect(find.text('Se déconnecter'), findsOneWidget);
    // Under the bar, not over it.
    expect(tester.getRect(stores).top, greaterThan(button.bottom));
  });

  testApp('the drawer no longer carries the profile', (tester) async {
    await _open(tester, _phone);

    tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AppSidebar),
        matching: find.byTooltip('Mon compte'),
      ),
      findsNothing,
    );
  });

  testApp('a tablet keeps the profile in the sidebar, no bar', (tester) async {
    await _open(tester, _tablet);

    expect(find.byKey(_profileButton), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AppSidebar),
        matching: find.byTooltip('Mon compte'),
      ),
      findsOneWidget,
    );
  });
}
