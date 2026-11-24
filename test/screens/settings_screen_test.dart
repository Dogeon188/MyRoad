import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myroad/database/dao/region_dao.dart';
import 'package:myroad/database/dao/trip_dao.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/screens/home_screen.dart';
import 'package:myroad/services/locale_provider.dart';
import 'package:myroad/services/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRegionDao extends Fake implements RegionDao {
  @override
  Stream<List<Region>> watchAll() => Stream.value([]);
}

class _FakeTripDao extends Fake implements TripDao {
  @override
  Stream<List<Trip>> watchAll() => Stream.value([]);
}

class _App extends ConsumerWidget {
  const _App();

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    locale: ref.watch(localeProvider),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: const HomeScreen(),
  );
}

void main() {
  Future<ProviderContainer> containerWith(Map<String, Object> stored) async {
    SharedPreferences.setMockInitialValues(stored);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('localeProvider', () {
    test('defaults to the system language', () async {
      final container = await containerWith({});
      expect(container.read(localeProvider), isNull);
    });

    test('saves a choice and loads it in a new container', () async {
      final container = await containerWith({});
      await container
          .read(localeProvider.notifier)
          .set(const Locale('ja'));
      expect(container.read(localeProvider), const Locale('ja'));

      final prefs = container.read(sharedPreferencesProvider);
      final restarted = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(restarted.dispose);
      expect(restarted.read(localeProvider), const Locale('ja'));
    });

    test('System default clears the saved choice', () async {
      final container = await containerWith({localePrefKey: 'zh'});
      expect(container.read(localeProvider), const Locale('zh'));
      await container.read(localeProvider.notifier).set(null);
      expect(container.read(localeProvider), isNull);
      expect(
        container.read(sharedPreferencesProvider).getString(localePrefKey),
        isNull,
      );
    });
  });

  testWidgets('choosing 日本語 switches the UI language at once', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          regionDaoProvider.overrideWithValue(_FakeRegionDao()),
          tripDaoProvider.overrideWithValue(_FakeTripDao()),
        ],
        child: const _App(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No trips yet. Tap + to create one.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('日本語'));
    await tester.pumpAndSettle();

    expect(find.text('言語'), findsOneWidget);
    expect(prefs.getString(localePrefKey), 'ja');
  });
}
