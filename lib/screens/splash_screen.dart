import 'package:flutter/material.dart';
import '../app/app_state.dart';
import '../app/app_state_scope.dart';
import '../services/auth_service.dart';
import '../services/session_manager.dart';
import '../widgets/app_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _initialize();
    }
  }

  Future<void> _initialize() async {
    final appState = AppStateScope.read(context);
    final session = SessionManager();
    final auth = const AuthService();

    final saved = await session.load();
    if (saved != null) {
      try {
        final me = await auth.me(saved['token'] as String);
        final staff = StaffInfo.fromJson(me['staff'] as Map<String, dynamic>);
        final warehouses = (me['warehouses'] as List)
            .map((w) => Warehouse.fromJson(w as Map<String, dynamic>))
            .toList();
        appState.setAuth(
          token: saved['token'] as String,
          staff: staff,
          role: me['role'] as String,
          warehouses: warehouses,
        );
      } catch (_) {
        await session.clear();
      }
    }

    appState.setInitialized();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppLogo(size: 96),
            const SizedBox(height: 32),
            CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}
