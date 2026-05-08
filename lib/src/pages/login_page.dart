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
  final _confirmPasswordController = TextEditingController();
  bool _loginMode = true;
  bool _loading = false;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final id = _idController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (id.isEmpty || password.isEmpty) {
      _showMessage('아이디와 비밀번호를 모두 입력해 주세요.');
      return;
    }
    if (!_loginMode && password != confirmPassword) {
      _showMessage('비밀번호 확인이 일치하지 않습니다.');
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
        if (!mounted) return;
        _showMessage('회원가입이 완료되었습니다. 로그인해 주세요.');
        setState(() {
          _loginMode = true;
          _passwordController.clear();
          _confirmPasswordController.clear();
        });
      }
    } catch (e) {
      if (!mounted) return;
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
    final modeColor = _loginMode ? AppTheme.crimson : AppTheme.teal;
    final modeTitle = _loginMode ? '로그인' : '회원가입';
    final modeIcon = _loginMode
        ? Icons.lock_open_rounded
        : Icons.person_add_alt_1_rounded;

    return Scaffold(
      backgroundColor: AppTheme.crimson,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.festival_rounded,
                    size: 64,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '중앙 축제',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.panel,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: true,
                              label: Text('로그인'),
                              icon: Icon(Icons.login_rounded),
                            ),
                            ButtonSegment(
                              value: false,
                              label: Text('회원가입'),
                              icon: Icon(Icons.person_add_rounded),
                            ),
                          ],
                          selected: {_loginMode},
                          onSelectionChanged: _loading
                              ? null
                              : (value) => setState(() {
                                  _loginMode = value.first;
                                  _confirmPasswordController.clear();
                                }),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: modeColor,
                              foregroundColor: Colors.white,
                              child: Icon(modeIcon),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    modeTitle,
                                    style: TextStyle(
                                      color: modeColor,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    _loginMode
                                        ? '기존 계정으로 축제 정보를 확인하세요.'
                                        : '새 계정을 만든 뒤 로그인할 수 있습니다.',
                                    style: const TextStyle(
                                      color: AppTheme.muted,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        TextField(
                          controller: _idController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: '아이디',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          textInputAction: _loginMode
                              ? TextInputAction.done
                              : TextInputAction.next,
                          onSubmitted: (_) {
                            if (_loginMode) _submit();
                          },
                          decoration: const InputDecoration(
                            labelText: '비밀번호',
                            prefixIcon: Icon(Icons.lock_outline_rounded),
                          ),
                        ),
                        if (!_loginMode) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _confirmPasswordController,
                            obscureText: true,
                            onSubmitted: (_) => _submit(),
                            decoration: const InputDecoration(
                              labelText: '비밀번호 확인',
                              prefixIcon: Icon(Icons.verified_user_outlined),
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        ElevatedButton.icon(
                          onPressed: _loading ? null : _submit,
                          icon: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(modeIcon),
                          label: Text(modeTitle),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: modeColor,
                          ),
                        ),
                      ],
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
