import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../main.dart';
import '../../../shared/design/atoms/app-button.dart';
import '../../../shared/design/tokens/app-colors.dart';
import '../../../shared/design/tokens/app-spacing.dart';
import '../../../shared/design/tokens/app-typography.dart';
import '../coordinator/auth-coordinator.dart';
import '../model/auth-models.dart';
import '../view-model/auth-view-model.dart';

class OtpVerificationScreen extends StatefulWidget {
  final AuthViewModel vm;
  const OtpVerificationScreen({super.key, required this.vm});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  late final AuthCoordinator _coordinator;
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  static const _resendCooldown = 60;
  int _secondsLeft = _resendCooldown;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _coordinator = AuthCoordinator(appCoordinator);
    widget.vm.addListener(_onVmChanged);
    _startResendTimer();
  }

  @override
  void dispose() {
    widget.vm.removeListener(_onVmChanged);
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _onVmChanged() {
    if (!mounted) return;
    switch (widget.vm.step) {
      case AuthFlowStep.success:
        _coordinator.handleAuthSuccess(widget.vm);

      case AuthFlowStep.otpSent:
        _otpController.clear();
        _restartResendTimer();

      case AuthFlowStep.error:
        final msg = widget.vm.errorMessage;
        if (msg != null && msg.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }

      default:
        break;
    }
  }

  void _startResendTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft == 0) { t.cancel(); return; }
      setState(() => _secondsLeft--);
    });
  }

  void _restartResendTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendCooldown);
    _startResendTimer();
  }

  void _handleVerify() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.vm.verifyOtp(_otpController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final contact = vm.pendingContact ?? '';
    final isEmail = vm.otpMethod == OtpMethod.email;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(backgroundColor: AppColors.paper, elevation: 0),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: vm,
          builder: (context, _) {
            if (vm.step == AuthFlowStep.loading) {
              return const Center(child: CircularProgressIndicator(color: AppColors.ink));
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.xl),
                  Container(
                    width: 48,
                    height: 48,
                    color: AppColors.paperAlt,
                    child: Icon(
                      isEmail ? Icons.mark_email_read_outlined : Icons.sms_outlined,
                      size: 24,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Check your ${isEmail ? 'email' : 'phone'}',
                    style: AppTypography.title,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text.rich(
                    TextSpan(
                      text: 'We sent a 6-digit code to\n',
                      style: AppTypography.bodyMuted,
                      children: [
                        TextSpan(text: contact, style: AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 6,
                          autofocus: true,
                          style: AppTypography.display.copyWith(letterSpacing: 12, fontSize: 24),
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            hintText: '──────',
                            counterText: '',
                          ),
                          validator: (v) => (v == null || v.length != 6) ? 'Enter the 6-digit code' : null,
                          onFieldSubmitted: (_) => _handleVerify(),
                        ),
                        const SizedBox(height: AppSpacing.base),
                        AppButton.primary('Verify', onPressed: _handleVerify, width: double.infinity),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: _secondsLeft > 0
                        ? Text('Resend code in ${_secondsLeft}s', style: AppTypography.labelMuted)
                        : TextButton(
                            onPressed: () => widget.vm.resendOtp(),
                            child: Text('Resend code', style: AppTypography.label),
                          ),
                  ),

                  if (widget.vm.isLockedOut) ...[
                    const SizedBox(height: AppSpacing.base),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      color: AppColors.errorMuted,
                      child: Text(
                        'Too many failed attempts. Please wait 15 minutes before trying again.',
                        style: AppTypography.body.copyWith(color: AppColors.error),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
