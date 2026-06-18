import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/screens/home_screen.dart';

Widget createTestApp() {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const HomeScreen(),
    ),
  );
}

void main() {
  testWidgets('HomeScreen shows ROI Library tab by default', (tester) async {
    await tester.pumpWidget(createTestApp());
    await tester.pumpAndSettle();

    expect(find.text('ROI Library'), findsWidgets);
    expect(find.text('Trips'), findsWidgets);
  });

  testWidgets('HomeScreen switches to Trips tab', (tester) async {
    await tester.pumpWidget(createTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.card_travel));
    await tester.pumpAndSettle();

    expect(find.text('No trips yet. Tap + to create one.'), findsOneWidget);
  });
}
