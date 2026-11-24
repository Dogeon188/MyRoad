import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/screens/region_library/spot_search_screen.dart';
import 'package:myroad/services/locale_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('a Places search after choosing 中文 sends languageCode zh', (
    tester,
  ) async {
    dotenv.testLoad(fileInput: 'GOOGLE_PLACES_API_KEY=test');
    SharedPreferences.setMockInitialValues({localePrefKey: 'zh'});
    final prefs = await SharedPreferences.getInstance();
    final bodies = <Map<String, dynamic>>[];
    final mock = MockClient((request) async {
      bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response('{"places": []}', 200);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: Consumer(
            builder: (context, ref, _) => MaterialApp(
              locale: ref.watch(localeProvider),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: const SpotSearchScreen(areaId: 'area'),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Tokyo Tower');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
    }, () => mock);

    expect(bodies, hasLength(1));
    expect(bodies.single['languageCode'], 'zh');
  });
}
