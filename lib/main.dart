import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ponytail: silently skip if .env missing (dev without API key)
  await dotenv.load(fileName: '.env').catchError((_) {});
  runApp(const ProviderScope(child: MyRoadApp()));
}

class MyRoadApp extends StatelessWidget {
  const MyRoadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyRoad!!!!!',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
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
}
