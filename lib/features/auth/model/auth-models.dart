enum OtpMethod { email, phone }

enum AuthFlowStep {
  idle,
  loading,
  otpSent,
  success,
  error,
}
