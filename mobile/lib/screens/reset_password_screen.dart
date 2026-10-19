import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rescue_app/domain/services/api/rest_api_service.dart';
import 'package:rescue_app/presentation/router/app_router.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen(
      {super.key, required this.uid, required this.token});

  final String uid;
  final String token;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await RestApiService().confirmPasswordReset(
          uid: widget.uid,
          token: widget.token,
          password: _passwordController.text);
      if (mounted) {
        context.go(AppRoutePaths.signIn);
      }
    } catch (_) {
      if (mounted)
        setState(() => _error = 'קישור האיפוס אינו תקין או שפג תוקפו.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('איפוס סיסמה')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                                labelText: 'סיסמה חדשה',
                                border: OutlineInputBorder()),
                            validator: (value) => (value ?? '').length < 8
                                ? 'לפחות 8 תווים'
                                : null),
                        const SizedBox(height: 12),
                        TextFormField(
                            controller: _confirmController,
                            obscureText: true,
                            decoration: const InputDecoration(
                                labelText: 'אימות סיסמה',
                                border: OutlineInputBorder()),
                            validator: (value) =>
                                value != _passwordController.text
                                    ? 'הסיסמאות אינן תואמות'
                                    : null),
                        if (_error != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(_error!,
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error))),
                        const SizedBox(height: 16),
                        FilledButton(
                            onPressed: _loading ? null : _submit,
                            child: _loading
                                ? const CircularProgressIndicator()
                                : const Text('עדכון סיסמה')),
                      ]),
                ),
              ),
            ),
          ),
        ),
      );
}
