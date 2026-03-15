import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app-coordinator.dart';
import 'app/app-router.dart';
import 'shared/logger.dart';
import 'shared/theme/app-theme.dart';

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

  runApp(const NashaatApp());
}

class NashaatApp extends StatelessWidget {
  const NashaatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nashaat',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      navigatorKey: appCoordinator.navigatorKey,
      onGenerateRoute: AppRouter.generateRoute,
      initialRoute: AppRouter.splash,
    );
  }
}
