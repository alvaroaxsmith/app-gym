import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
  debugPrint('Info: arquivo .env não encontrado, usando --dart-define');
  }
  
  // Priorizar variáveis injetadas via --dart-define (CI/CD/Production)
  // Caso não existam, fallback para arquivo .env (Desenvolvimento Local)
  final supabaseUrl =
      _normalizeEnv(_supabaseUrlDefine) ?? _normalizeEnv(dotenv.env['SUPABASE_URL']);
  final supabaseAnonKey =
      _normalizeEnv(_supabaseAnonKeyDefine) ?? _normalizeEnv(dotenv.env['SUPABASE_ANON_KEY']);
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
  runApp(const ConstruindoFibraApp());
}

class ConstruindoFibraApp extends StatelessWidget {
  const ConstruindoFibraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(Supabase.instance.client),
        ),
      ],
      child: MaterialApp(
        title: 'Construindo Fibra',
        theme: AppTheme.light,
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          final width = mediaQuery.size.width;

          // Ajuste de escala baseado na largura da tela
          double layoutScale = 1.0;
          if (width < 360) {
            layoutScale = 0.85; // Telas pequenas (ex: iPhone SE 1st gen)
          } else if (width < 400) {
            layoutScale = 0.93; // Telas médias-pequenas (ex: iPhone 8, alguns Androids)
          }

          // Cria um novo TextScaler que limita o tamanho máximo em telas pequenas
          // para evitar overflow, mantendo a responsividade
          return MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: mediaQuery.textScaler.clamp(
                minScaleFactor: 0.8,
                maxScaleFactor: 1.2 * layoutScale, 
              ),
            ),
            child: child!,
          );
        },
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('pt', 'BR'),
        ],
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
