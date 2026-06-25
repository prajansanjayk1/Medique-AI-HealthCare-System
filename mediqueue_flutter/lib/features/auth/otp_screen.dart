import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme.dart';
import '../../core/services/auth_service.dart';
import 'splash_screen.dart';
import 'login_screen.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({Key? key}) : super(key: key);

  @override
  _OtpScreenState createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSendingOtp = false;
  String? _errorMessage;
  String? _successMessage;

  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    // Trigger sending of OTP on loading the screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerOtpSend();
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startCooldownTimer() {
    setState(() {
      _resendCooldown = 45;
    });
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown == 0) {
        timer.cancel();
      } else {
        if (mounted) {
          setState(() {
            _resendCooldown--;
          });
        }
      }
    });
  }

  Future<void> _triggerOtpSend() async {
    if (_isSendingOtp) return;
    setState(() {
      _isSendingOtp = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      if (auth.currentUser == null) {
        throw Exception("You must be logged in to request an OTP.");
      }

      await auth.callOtpProvider('sendOtp', <String, dynamic>{
        'email': auth.currentUser!.email,
      });

      if (mounted) {
        setState(() {
          _successMessage = "A 6-digit OTP code has been sent to your email. Check your Inbox and Spam folders.";
          _isSendingOtp = false;
        });
        _startCooldownTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll(RegExp(r'\[.*\]'), '').replaceAll('Exception: ', '');
          _isSendingOtp = false;
        });
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      if (auth.currentUser == null) {
        throw Exception("Session expired. Please log in again.");
      }

      await auth.callOtpProvider('verifyOtp', <String, dynamic>{
        'email': auth.currentUser!.email,
        'otp': _codeController.text.trim(),
      });

      await auth.verify2fa();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SplashScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll(RegExp(r'\[.*\]'), '').replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _cancelAndLogout() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    await auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _bypass() {
    final auth = Provider.of<AuthService>(context, listen: false);
    auth.bypass2fa();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final email = auth.currentUser?.email ?? "your email";

    return Scaffold(
      body: Container(
        decoration: AppTheme.gradientDecoration,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo / Lock Icon
                  Image.asset(
                    'assets/logo.png',
                    width: 76,
                    height: 76,
                  ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 16),
                  const Text(
                    "Security Verification",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ).animate().fadeIn(delay: 150.ms),
                  const Text(
                    "Two-Factor Authentication",
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w500,
                    ),
                  ).animate().fadeIn(delay: 250.ms),
                  const SizedBox(height: 36),

                  // Glass Card
                  Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: AppTheme.glassCardDecoration,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          "Enter 2FA Code",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
                            children: [
                              const TextSpan(text: "We sent a 6-digit verification code to:\n"),
                              TextSpan(
                                text: email,
                                style: const TextStyle(
                                  color: Color(0xFF1E293B),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // OTP Code Field
                        TextFormField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            letterSpacing: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                          decoration: InputDecoration(
                            counterText: "",
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.015),
                            hintText: "000000",
                            hintStyle: TextStyle(
                              color: const Color(0xFF64748B).withOpacity(0.3),
                              letterSpacing: 10,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.redAccent.withOpacity(0.8), width: 1.5),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().length != 6) {
                              return "Please enter the 6-digit OTP code.";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Error or Success message
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        if (_successMessage != null && _errorMessage == null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Text(
                              _successMessage!,
                              style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        // Verify Button
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withOpacity(0.2),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading || _isSendingOtp ? null : _verifyOtp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    "Verify Code",
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Resend Button
                        OutlinedButton.icon(
                          onPressed: _resendCooldown > 0 || _isSendingOtp || _isLoading
                              ? null
                              : _triggerOtpSend,
                          icon: _isSendingOtp
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded, size: 18),
                          label: Text(
                            _resendCooldown > 0
                                ? "Resend code in ${_resendCooldown}s"
                                : "Resend Code",
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            disabledForegroundColor: Colors.grey.withOpacity(0.5),
                            side: BorderSide(
                              color: _resendCooldown > 0 || _isSendingOtp || _isLoading
                                  ? Colors.grey.withOpacity(0.1)
                                  : AppTheme.primaryColor.withOpacity(0.4),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Cancel Button
                        TextButton(
                          onPressed: _isLoading ? null : _cancelAndLogout,
                          child: const Text(
                            "Cancel & Change Account",
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),

                        // Bypass Button for debugging / testing
                        const SizedBox(height: 8),
                        Divider(color: Colors.black.withOpacity(0.08)),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _isLoading ? null : () {
                            final email = Provider.of<AuthService>(context, listen: false).currentUser?.email?.toLowerCase() ?? "";
                            if (email == "lovefornature727@gmail.com" || email == "prajansanjayko@gmail.com") {
                                _bypass();
                            } else {
                                setState(() {
                                    _errorMessage = "This account is not authorized to bypass OTP.";
                                });
                            }
                          },
                          icon: const Icon(Icons.bug_report_outlined, size: 16, color: Colors.amber),
                          label: const Text(
                            "Bypass 2FA (Testing)",
                            style: TextStyle(color: Colors.amber, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ).animate().slideY(begin: 0.15, end: 0, duration: 400.ms, curve: Curves.easeOutQuad),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
