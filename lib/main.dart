import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/app_theme.dart';
import 'features/auth/auth_page.dart';
import 'features/auth/auth_provider.dart';
import 'features/home/home_shell.dart';

const _supabaseUrlDefine = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKeyDefine = String.fromEnvironment('SUPABASE_ANON_KEY');

String? _normalizeEnv(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  
  // Tentar carregar .env apenas se existir (desenvolvimento local)
  try {
    await dotenv.load(fileName: '.env', isOptional: true);
  } catch (e) {
    // Ignorar erro em produção onde .env não existe
    print('Info: arquivo .env não encontrado, usando --dart-define');
  }
  
  final supabaseUrl =
      _normalizeEnv(dotenv.env['SUPABASE_URL']) ?? _normalizeEnv(_supabaseUrlDefine);
  final supabaseAnonKey =
      _normalizeEnv(dotenv.env['SUPABASE_ANON_KEY']) ?? _normalizeEnv(_supabaseAnonKeyDefine);
  if (supabaseUrl == null || supabaseAnonKey == null) {
    throw Exception(
      'Defina SUPABASE_URL e SUPABASE_ANON_KEY no arquivo .env ou via --dart-define.',
    );
  }
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(autoRefreshToken: true),
  );
  runApp(const WorkoutLoggerApp());
}

class WorkoutLoggerApp extends StatelessWidget {
  const WorkoutLoggerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(Supabase.instance.client),
        ),
      ],
      child: MaterialApp(
        title: 'Workout Logger',
        theme: AppTheme.light,
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (auth.session == null) {
      return const AuthPage();
    }
    return const HomeShell();
  }
}
