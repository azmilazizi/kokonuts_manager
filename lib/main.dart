import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app/app_state.dart';
import 'app/app_state_scope.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_expiration_handler.dart';
import 'services/push_notification_service.dart';
import 'services/session_manager.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  PushNotificationService.registerBackgroundHandler();
  runApp(const KokonutsManagerApp());
}

class KokonutsManagerApp extends StatefulWidget {
  const KokonutsManagerApp({super.key});

  @override
  State<KokonutsManagerApp> createState() => _KokonutsManagerAppState();
}

class _KokonutsManagerAppState extends State<KokonutsManagerApp> {
  final _appState = AppState();
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    AuthExpirationHandler().initialize(
      navigatorKey: _navigatorKey,
      appState: _appState,
      sessionManager: SessionManager(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      state: _appState,
      child: MaterialApp(
        title: 'Kokonuts Manager',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey,
        theme: ThemeData(
          colorScheme: const ColorScheme.dark(
            primary: Colors.orange,
            onPrimary: Colors.black,
            primaryContainer: Color(0xFFBF5B00),
            onPrimaryContainer: Colors.white,
            secondary: Colors.orangeAccent,
            onSecondary: Colors.black,
            surface: Color(0xFF1C1C1E),
            onSurface: Color(0xFFE5E5EA),
            surfaceContainerHighest: Color(0xFF2C2C2E),
            outline: Color(0xFF636366),
          ),
          useMaterial3: true,
          snackBarTheme: const SnackBarThemeData(
            behavior: SnackBarBehavior.fixed,
          ),
        ),
        themeMode: ThemeMode.dark,
        home: ListenableBuilder(
          listenable: _appState,
          builder: (_, __) => _resolveHome(),
        ),
      ),
    );
  }

  Widget _resolveHome() {
    if (!_appState.isInitialized) return const SplashScreen();
    if (!_appState.isAuthenticated) return const LoginScreen();
    return const HomeScreen();
  }
}
