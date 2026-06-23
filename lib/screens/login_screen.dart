import 'package:flutter/material.dart';
import '../app/app_state.dart';
import '../app/app_state_scope.dart';
import '../services/auth_service.dart';
import '../services/session_manager.dart';
import '../widgets/app_logo.dart';
import '../widgets/form_error_banner.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  String? _generalError;
  String? _usernameError;
  String? _passwordError;

  static const _domain = '@kokonuts.my';

  String get _resolvedEmail {
    final v = _usernameCtrl.text.trim();
    return v.contains('@') ? v : '$v$_domain';
  }

  Future<void> _submit() async {
    setState(() {
      _generalError = null;
      _usernameError = null;
      _passwordError = null;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final auth = const AuthService();
      final session = SessionManager();
      final appState = AppStateScope.read(context);

      final data = await auth.login(_resolvedEmail, _passwordCtrl.text);

      final staff = StaffInfo.fromJson(data['staff'] as Map<String, dynamic>);
      final role = data['role'] as String;
      final warehouses = (data['warehouses'] as List)
          .map((w) => Warehouse.fromJson(w as Map<String, dynamic>))
          .toList();

      await session.save(
        token: data['token'] as String,
        staffId: staff.id,
        staffName: staff.fullName,
        staffEmail: staff.email,
        role: role,
      );

      appState.setAuth(
        token: data['token'] as String,
        staff: staff,
        role: role,
        warehouses: warehouses,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.statusCode == 422) {
          _usernameError = 'Email is required';
          _passwordError = 'Password is required';
        } else {
          _generalError = e.message;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _generalError = 'Connection error. Check your network.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: AppLogo(size: 96)),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome back',
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to continue to Kokonuts Manager.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(178),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  if (_generalError != null) ...[
                    FormErrorBanner(error: _generalError),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _usernameCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      hintText: 'yourname',
                      suffixText: _domain,
                      border: const OutlineInputBorder(),
                      errorText: _usernameError,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Username is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _loading ? null : _submit(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      errorText: _passwordError,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Password is required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text('Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
