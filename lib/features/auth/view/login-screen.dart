import 'package:flutter/material.dart';

import '../../../infra/repository-locator.dart';
import '../../../main.dart';
import '../../../shared/design/atoms/app-button.dart';
import '../../../shared/design/atoms/app-divider.dart';
import '../../../shared/design/tokens/app-colors.dart';
import '../../../shared/design/tokens/app-spacing.dart';
import '../../../shared/design/tokens/app-typography.dart';
import '../coordinator/auth-coordinator.dart';
import '../model/auth-models.dart';
import '../view-model/auth-view-model.dart';
import '../view/auth-widgets.dart';
import 'otp-verification-screen.dart';
import 'phone-auth-screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final AuthViewModel _vm;
  late final AuthCoordinator _coordinator;
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _otpPushed = false;

  @override
  void initState() {
    super.initState();
    _vm = AuthViewModel(RepositoryLocator.instance.auth);
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
        Navigator.push(context, MaterialPageRoute(builder: (_) => OtpVerificationScreen(vm: _vm))).then((_) {
          _otpPushed = false;
          _vm.reset();
        });

      case AuthFlowStep.error:
        if (!_otpPushed) {
          final msg = _vm.errorMessage;
          if (msg != null && msg.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _vm,
          builder: (context, _) {
            if (_vm.step == AuthFlowStep.loading) {
              return const Center(child: CircularProgressIndicator(color: AppColors.ink));
            }
            return _buildBody(context);
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 72),

          Text('NASHAAT', style: AppTypography.display.copyWith(letterSpacing: 4)),
          const SizedBox(height: AppSpacing.xs),
          Text('Welcome back.', style: AppTypography.bodyMuted),

          const SizedBox(height: AppSpacing.xxl),

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
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter your email address';
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _handleEmailContinue(),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton.primary(
                  'Continue with Email',
                  onPressed: _vm.step == AuthFlowStep.loading ? null : _handleEmailContinue,
                  width: double.infinity,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
          const _OrDivider(),
          const SizedBox(height: AppSpacing.lg),

          AuthSocialButton(
            icon: const GoogleIcon(),
            label: 'Continue with Google',
            onPressed: _vm.signInWithGoogle,
          ),
          const SizedBox(height: AppSpacing.md),
          AuthSocialButton(
            icon: const Icon(Icons.apple, size: 22, color: AppColors.ink),
            label: 'Continue with Apple',
            onPressed: _vm.signInWithApple,
          ),

          const SizedBox(height: AppSpacing.base),
          TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PhoneAuthScreen(vm: _vm))),
            icon: const Icon(Icons.phone_outlined, size: 16, color: AppColors.inkMuted),
            label: Text('Use phone number instead', style: AppTypography.labelMuted),
          ),

          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Don't have an account?", style: AppTypography.body),
              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/register'),
                child: Text('Register', style: AppTypography.label),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: AppDivider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text('or', style: AppTypography.labelMuted),
        ),
        const Expanded(child: AppDivider()),
      ],
    );
  }
}
