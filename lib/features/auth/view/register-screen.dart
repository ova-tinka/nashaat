import 'package:flutter/material.dart';

import '../../../infra/supabase/auth-repository-impl.dart';
import '../../../main.dart';
import '../coordinator/auth-coordinator.dart';
import '../model/auth-models.dart';
import '../view_model/auth-view-model.dart';
import 'auth-widgets.dart';
import 'otp-verification-screen.dart';
import 'phone-auth-screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  late final AuthViewModel _vm;
  late final AuthCoordinator _coordinator;
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _otpPushed = false;

  @override
  void initState() {
    super.initState();
    _vm = AuthViewModel(SupabaseAuthRepository());
    _coordinator = AuthCoordinator(appCoordinator);
    _vm.addListener(_onVmChanged);
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    _vm.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _onVmChanged() {
    if (!mounted) return;

    switch (_vm.step) {
      case AuthFlowStep.success:
        _coordinator.handleAuthSuccess(_vm);

      case AuthFlowStep.otpSent when !_otpPushed:
        _otpPushed = true;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OtpVerificationScreen(vm: _vm)),
        ).then((_) {
          _otpPushed = false;
          _vm.reset();
        });

      case AuthFlowStep.error:
        if (!_otpPushed) {
          final msg = _vm.errorMessage;
          if (msg != null && msg.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(msg),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        }

      default:
        break;
    }
  }

  void _handleEmailContinue() {
    if (_formKey.currentState?.validate() ?? false) {
      _vm.sendEmailOtp(_emailController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _vm,
          builder: (context, _) {
            if (_vm.step == AuthFlowStep.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            return _buildBody(context);
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 72),

          Icon(Icons.fitness_center_rounded,
              size: 56, color: colorScheme.primary),
          const SizedBox(height: 20),
          Text(
            'Create account',
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Sign up to get started',
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 48),

          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    hintText: 'you@example.com',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter your email address';
                    }
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch(v.trim())) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _handleEmailContinue(),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _vm.step == AuthFlowStep.loading ? null : _handleEmailContinue,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Continue with email'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          const AuthOrDivider(),
          const SizedBox(height: 24),

          AuthSocialButton(
            icon: const GoogleIcon(),
            label: 'Sign up with Google',
            onPressed: _vm.signInWithGoogle,
          ),
          const SizedBox(height: 12),
          AuthSocialButton(
            icon: const Icon(Icons.apple, size: 22),
            label: 'Sign up with Apple',
            onPressed: _vm.signInWithApple,
          ),

          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PhoneAuthScreen(vm: _vm)),
            ),
            icon: const Icon(Icons.phone_outlined, size: 18),
            label: const Text('Use phone number instead'),
          ),

          const SizedBox(height: 36),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Already have an account?',
                  style: theme.textTheme.bodyMedium),
              TextButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/login'),
                child: const Text('Sign in'),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
