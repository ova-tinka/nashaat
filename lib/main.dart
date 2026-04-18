import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app-coordinator.dart';
import 'app/app-router.dart';
import 'app/locale-provider.dart';
import 'shared/logger.dart';
import 'shared/design/theme.dart';
import 'shared/design/tokens/app-typography.dart';

final appCoordinator = AppCoordinator();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Log.boot('Nashaat starting…');

  await dotenv.load(fileName: '.env');
  Log.boot('.env loaded');

  final url = dotenv.env['SUPABASE_URL'] ?? '';
  await Supabase.initialize(
    url: url,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  Log.boot('Supabase ready → ${Uri.parse(url).host}');

  runApp(
    ChangeNotifierProvider(
      create: (_) => LocaleProvider(),
      child: const NashaatApp(),
    ),
  );
}

class NashaatApp extends StatelessWidget {
  const NashaatApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    final locale = localeProvider.currentLocale;

    final theme = AppTheme.light.copyWith(
      textTheme: AppTypography.getTextTheme(locale: locale),
    );

    return MaterialApp(
      title: 'Nashaat',
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.light,
      locale: locale,
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      navigatorKey: appCoordinator.navigatorKey,
      onGenerateRoute: AppRouter.generateRoute,
      initialRoute: AppRouter.splash,
    );
  }
}
