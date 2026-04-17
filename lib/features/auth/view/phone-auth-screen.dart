import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/design/atoms/app-button.dart';
import '../../../shared/design/tokens/app-colors.dart';
import '../../../shared/design/tokens/app-spacing.dart';
import '../../../shared/design/tokens/app-typography.dart';
import '../model/auth-models.dart';
import '../view-model/auth-view-model.dart';
import 'otp-verification-screen.dart';

class PhoneAuthScreen extends StatefulWidget {
  final AuthViewModel vm;
  const PhoneAuthScreen({super.key, required this.vm});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _otpPushed = false;

  @override
  void initState() {
    super.initState();
    widget.vm.addListener(_onVmChanged);
  }

  @override
  void dispose() {
    widget.vm.removeListener(_onVmChanged);
    _phoneController.dispose();
    super.dispose();
  }

  void _onVmChanged() {
    if (!mounted) return;
    switch (widget.vm.step) {
      case AuthFlowStep.otpSent when !_otpPushed:
        _otpPushed = true;
        Navigator.push(context, MaterialPageRoute(builder: (_) => OtpVerificationScreen(vm: widget.vm))).then((_) => _otpPushed = false);

      case AuthFlowStep.error:
        final msg = widget.vm.errorMessage;
        if (msg != null && msg.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }

      default:
        break;
    }
  }

  void _handleContinue() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final raw = _phoneController.text.trim().replaceAll(RegExp(r'\s+'), '');
    final phone = raw.startsWith('+') ? raw : '+$raw';
    widget.vm.sendPhoneOtp(phone);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(backgroundColor: AppColors.paper, elevation: 0),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.vm,
          builder: (context, _) {
            if (widget.vm.step == AuthFlowStep.loading) {
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
                    child: const Icon(Icons.phone_android_outlined, size: 24, color: AppColors.ink),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Enter your phone number', style: AppTypography.title),
                  const SizedBox(height: AppSpacing.sm),
                  Text("We'll send a verification code via SMS.", style: AppTypography.bodyMuted),
                  const SizedBox(height: AppSpacing.xl),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\s\+\-\(\)]'))],
                          decoration: const InputDecoration(
                            labelText: 'Phone number',
                            hintText: '+966 50 123 4567',
                            helperText: 'Include country code (e.g. +966)',
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Please enter your phone number';
                            final digits = v.replaceAll(RegExp(r'[^\d]'), '');
                            if (digits.length < 7 || digits.length > 15) return 'Enter a valid phone number with country code';
                            return null;
                          },
                          onFieldSubmitted: (_) => _handleContinue(),
                        ),
                        const SizedBox(height: AppSpacing.base),
                        AppButton.primary('Send verification code', onPressed: _handleContinue, width: double.infinity),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
