import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../main.dart';
import '../coordinator/auth-coordinator.dart';
import '../model/auth-models.dart';
import '../view_model/auth-view-model.dart';

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

      // OTP resent — restart timer and clear field
      case AuthFlowStep.otpSent:
        _otpController.clear();
        _restartResendTimer();

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

  void _startResendTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft == 0) {
        t.cancel();
        return;
      }
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final vm = widget.vm;
    final contact = vm.pendingContact ?? '';
    final isEmail = vm.otpMethod == OtpMethod.email;

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: vm,
          builder: (context, _) {
            if (vm.step == AuthFlowStep.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            return _buildBody(context, theme, colorScheme, contact, isEmail);
          },
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    String contact,
    bool isEmail,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),

          // Icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              isEmail ? Icons.mark_email_read_outlined : Icons.sms_outlined,
              size: 36,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Check your ${isEmail ? 'email' : 'phone'}',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              text: 'We sent a 6-digit code to\n',
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
              children: [
                TextSpan(
                  text: contact,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // OTP input
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
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(letterSpacing: 12, fontWeight: FontWeight.bold),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    hintText: '──────',
                    counterText: '',
                    border: const OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: colorScheme.outline.withAlpha(128), width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: colorScheme.primary, width: 2),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.length != 6) {
                      return 'Enter the 6-digit code';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _handleVerify(),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _handleVerify,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Verify'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Resend
          Center(
            child: _secondsLeft > 0
                ? Text(
                    'Resend code in ${_secondsLeft}s',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  )
                : TextButton(
                    onPressed: () => widget.vm.resendOtp(),
                    child: const Text('Resend code'),
                  ),
          ),

          const SizedBox(height: 16),

          // Lockout warning
          if (widget.vm.isLockedOut)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Too many failed attempts. Please wait 15 minutes before trying again.',
                style: TextStyle(color: colorScheme.onErrorContainer),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
