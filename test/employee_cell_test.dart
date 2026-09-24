// EmployeeCell and Formatters.dateShortWeekday: the "Employé" column and the
// date column shared by the Personnel, Pointage and Paiement tables.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stock_inventory/core/utils/formatters.dart';
import 'package:stock_inventory/models/models.dart';
import 'package:stock_inventory/shared/widgets/widgets.dart';

final _amelie = Employee(
  id: 'e',
  storeId: 's',
  firstName: 'amélie',
  lastName: 'vandenberghe',
  pin: '85.03.12-123.45',
  phone: '',
  email: 'e@x.test',
  hireDate: DateTime(2026),
  role: EmployeeRole.staff,
  pay: 10,
  createdAt: DateTime(2026),
);

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(home: Scaffold(body: Center(child: child))),
);

void main() {
  setUpAll(() => initializeDateFormatting(Formatters.locale));

  test('dateShortWeekday: capitalised short weekday, no dot, then the date',
      () {
    expect(Formatters.dateShortWeekday(DateTime(2026, 10, 19)), 'Lun 19/10/2026');
    expect(Formatters.dateShortWeekday(DateTime(2026, 10, 22)), 'Jeu 22/10/2026');
    expect(Formatters.dateShortWeekday(DateTime(2026, 10, 25)), 'Dim 25/10/2026');
  });

  testWidgets('the PIN sits under the name, with no "PIN" label', (
    tester,
  ) async {
    await _pump(tester, EmployeeCell(employee: _amelie));

    expect(find.byType(EmployeeAvatar), findsOneWidget);
    final name = find.text('Amélie Vandenberghe');
    final pin = find.text('85.03.12-123.45');
    expect(name, findsOneWidget);
    expect(pin, findsOneWidget);
    expect(find.textContaining('PIN'), findsNothing);
    expect(tester.getTopLeft(pin).dy, greaterThan(tester.getTopLeft(name).dy));
    expect(tester.getTopLeft(pin).dx, tester.getTopLeft(name).dx);
  });

  testWidgets('a trailing widget follows the name', (tester) async {
    await _pump(
      tester,
      EmployeeCell(
        employee: _amelie,
        dimmed: true,
        trailing: const Text('Retiré'),
      ),
    );

    expect(tester.widget<EmployeeAvatar>(find.byType(EmployeeAvatar)).dimmed,
        isTrue);
    expect(
      tester.getTopLeft(find.text('Retiré')).dx,
      greaterThan(tester.getTopRight(find.text('Amélie Vandenberghe')).dx),
    );
  });

  testWidgets('no employee renders an em dash', (tester) async {
    await _pump(tester, const EmployeeCell(employee: null));
    expect(find.text('—'), findsOneWidget);
    expect(find.byType(EmployeeAvatar), findsNothing);
  });
}
