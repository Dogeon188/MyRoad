import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/database/dao/roi_dao.dart';
import 'package:myroad/database/dao/trip_dao.dart';
import 'package:myroad/screens/home_screen.dart';
import 'package:myroad/services/providers.dart';

class _FakeRoiDao extends Fake implements RoiDao {
  @override
  Stream<List<Roi>> watchAll() => Stream.value([]);
}

class _FakeTripDao extends Fake implements TripDao {
  @override
  Stream<List<Trip>> watchAll() => Stream.value([]);
}

void main() {
  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          roiDaoProvider.overrideWithValue(_FakeRoiDao()),
          tripDaoProvider.overrideWithValue(_FakeTripDao()),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows both navigation tabs', (tester) async {
    await pumpHome(tester);

    expect(find.text('ROI Library'), findsWidgets);
    expect(find.text('Trips'), findsWidgets);
  });

  testWidgets('defaults to ROI Library tab with empty state', (tester) async {
    await pumpHome(tester);

    expect(find.text('No ROIs yet. Tap + to create one.'), findsOneWidget);
  });

  testWidgets('switches to Trips tab', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byIcon(Icons.card_travel));
    await tester.pumpAndSettle();

    expect(find.text('No trips yet. Tap + to create one.'), findsOneWidget);
  });
}
