import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => OtpVerificationScreen(vm: widget.vm)),
        ).then((_) => _otpPushed = false);

      case AuthFlowStep.error:
        final msg = widget.vm.errorMessage;
        if (msg != null && msg.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }

      default:
        break;
    }
  }

  void _handleContinue() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final raw = _phoneController.text.trim().replaceAll(RegExp(r'\s+'), '');
    // Ensure E.164 format; prepend + if missing.
    final phone = raw.startsWith('+') ? raw : '+$raw';
    widget.vm.sendPhoneOtp(phone);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.vm,
          builder: (context, _) {
            if (widget.vm.step == AuthFlowStep.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            return _buildBody(theme, colorScheme);
          },
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),

          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.phone_android_outlined,
              size: 36,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Enter your phone number',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll send a verification code via SMS.',
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),

          const SizedBox(height: 40),

          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d\s\+\-\(\)]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    hintText: '+966 50 123 4567',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                    helperText: 'Include country code (e.g. +966)',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter your phone number';
                    }
                    final digits =
                        v.replaceAll(RegExp(r'[^\d]'), '');
                    if (digits.length < 7 || digits.length > 15) {
                      return 'Enter a valid phone number with country code';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _handleContinue(),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _handleContinue,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Send verification code'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
