import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app-coordinator.dart';
import 'app/app-router.dart';
import 'shared/theme/app-theme.dart';

final appCoordinator = AppCoordinator();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

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
