import 'package:flutter/material.dart';

import '../../../infra/repository-locator.dart';
import '../../../main.dart';
import '../../../shared/design/atoms/app-button.dart';
import '../../../shared/design/tokens/app-colors.dart';
import '../../../shared/design/tokens/app-spacing.dart';
import '../../../shared/design/tokens/app-typography.dart';
import '../coordinator/auth-coordinator.dart';
import '../model/auth-models.dart';
import '../view-model/auth-view-model.dart';

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

      case AuthFlowStep.error:
        final msg = _vm.errorMessage;
        if (msg != null && msg.isNotEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }

      default:
        break;
    }
  }

  void _handleEmailContinue() {
    if (_formKey.currentState?.validate() ?? false) {
      _vm.signInWithEmail(_emailController.text.trim());
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
              return const Center(
                child: CircularProgressIndicator(color: AppColors.ink),
              );
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

          Text(
            'NASHAAT',
            style: AppTypography.display.copyWith(letterSpacing: 4),
          ),
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
                    if (v == null || v.trim().isEmpty)
                      return 'Please enter your email address';
                    if (!RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                    ).hasMatch(v.trim())) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _handleEmailContinue(),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton.primary(
                  'Continue with Email',
                  onPressed: _vm.step == AuthFlowStep.loading
                      ? null
                      : _handleEmailContinue,
                  width: double.infinity,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Don't have an account?", style: AppTypography.body),
              TextButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/register'),
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
