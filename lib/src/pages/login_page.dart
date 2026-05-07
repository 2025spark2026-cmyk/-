import 'package:central_festival_app/src/pages/home_page.dart';
import 'package:central_festival_app/src/services/auth_service.dart';
import 'package:central_festival_app/src/services/session_service.dart';
import 'package:central_festival_app/src/theme/app_theme.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _auth = AuthService();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loginMode = true;
  bool _loading = false;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final id = _idController.text.trim();
    final password = _passwordController.text.trim();
    if (id.isEmpty || password.isEmpty) {
      _showMessage('아이디와 비밀번호를 모두 입력해 주세요');
      return;
    }

    setState(() => _loading = true);
    try {
      if (_loginMode) {
        await _auth.signIn(id: id, password: password);
        await SessionService.save(id);
        if (!mounted) return;
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
      } else {
        await _auth.signUp(id: id, password: password);
        _showMessage('계정이 생성되었습니다. 로그인 해주세요.');
        setState(() => _loginMode = true);
      }
    } catch (e) {
      _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 18),
                  const Text(
                    '중앙고',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.crimson,
                    ),
                  ),
                  const SizedBox(height: 44),
                  Text(
                    _loginMode ? '로그인' : '회원가입',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Test.',
                    style: TextStyle(color: AppTheme.muted, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _idController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'User ID',

                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : Text(_loginMode ? '로그인' : '회원가입하기'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() => _loginMode = !_loginMode),
                    child: Text(
                      _loginMode ? '계정이 없나요? 회원가입하기' : '계정이 이미 있나요? 로그인하기',
                    ),
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
