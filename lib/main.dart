// lib/main.dart (VERSÃO COM SPLASH SCREEN)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

// Importações do Projeto
import 'package:geoforestcoletor/pages/menu/home_page.dart';
import 'package:geoforestcoletor/pages/menu/login_page.dart';
import 'package:geoforestcoletor/pages/menu/equipe_page.dart';
import 'package:geoforestcoletor/providers/map_provider.dart';
import 'package:geoforestcoletor/providers/team_provider.dart';
import 'package:geoforestcoletor/controller/login_controller.dart';
import 'package:geoforestcoletor/pages/projetos/lista_projetos_page.dart';
// <<< MUDANÇA 1 >>> Importar a nova splash page
import 'package:geoforestcoletor/pages/menu/splash_page.dart';
import 'package:geoforestcoletor/providers/license_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
    [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
  );

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const MyApp());
  } catch (e) {
    runApp(
      MaterialApp(
        home: ErrorScreen(
          message: 'Failed to initialize Firebase:\n${e.toString()}',
          onRetry: () => main(),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LoginController()),
        ChangeNotifierProvider(create: (_) => MapProvider()),
        ChangeNotifierProvider(create: (_) => TeamProvider()),
        ChangeNotifierProvider(create: (_) => LicenseProvider())
      ],
      child: MaterialApp(
        title: 'Geo Forest Analytics',
        debugShowCheckedModeBanner: false,
        theme: _buildThemeData(Brightness.light),
        darkTheme: _buildThemeData(Brightness.dark),
        
        // <<< MUDANÇA 2 >>> A rota inicial agora é a splash page
        initialRoute: '/', 
        
        routes: {
          // A rota '/' agora aponta para a SplashPage
          '/': (context) => const SplashPage(),
          
          // A lógica de verificação de login foi movida para uma nova rota '/auth_check'
          '/auth_check': (context) {
            return Consumer<LoginController>(
              builder: (context, loginController, child) {
                if (!loginController.isInitialized) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                
                if (loginController.isLoggedIn) {
                  return const EquipePage();
                } else {
                  return const LoginPage();
                }
              },
            );
          },
          
          // O resto das rotas permanece igual
          '/equipe': (context) => const EquipePage(),
          '/home': (context) => const HomePage(title: 'Geo Forest Analytics'),
          '/lista_projetos': (context) => const ListaProjetosPage(title: 'Meus Projetos'),
        },
        
        navigatorObservers: [MapProvider.routeObserver],
        
        builder: (context, child) {
          ErrorWidget.builder = (FlutterErrorDetails details) {
            debugPrint('Caught a Flutter error: ${details.exception}');
            return ErrorScreen(
              message: 'An unexpected error occurred.\nPlease restart the app.',
              onRetry: null,
            );
          };
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
            child: child!,
          );
        },
      ),
    );
  }

  ThemeData _buildThemeData(Brightness brightness) {
    final baseColor = const Color(0xFF617359);
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: baseColor,
        brightness: brightness,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: brightness == Brightness.light ? baseColor : Colors.grey[900],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: baseColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(color: Color(0xFF1D4433), fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(color: Color(0xFF1D4433)),
        bodyMedium: TextStyle(color: Color(0xFF1D4433)),
      ),
    );
  }
}

class ErrorScreen extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorScreen({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F4),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red[700], size: 60),
              const SizedBox(height: 20),
              Text(
                'Application Error',
                style: TextStyle(
                  color: Colors.red[700],
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 30),
              if (onRetry != null)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF617359),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onRetry,
                  child: const Text('Try Again'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}