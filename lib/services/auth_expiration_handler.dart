import 'package:flutter/material.dart';
import '../app/app_state.dart';
import 'session_manager.dart';

class AuthExpirationHandler {
  static final AuthExpirationHandler _instance =
      AuthExpirationHandler._internal();
  factory AuthExpirationHandler() => _instance;
  AuthExpirationHandler._internal();

  GlobalKey<NavigatorState>? _navigatorKey;
  AppState? _appState;
  SessionManager? _sessionManager;

  void initialize({
    required GlobalKey<NavigatorState> navigatorKey,
    required AppState appState,
    required SessionManager sessionManager,
  }) {
    _navigatorKey = navigatorKey;
    _appState = appState;
    _sessionManager = sessionManager;
  }

  Future<void> handleExpired() async {
    await _sessionManager?.clear();
    _appState?.clearAuth();
  }

  GlobalKey<NavigatorState>? get navigatorKey => _navigatorKey;
}
