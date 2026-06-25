import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme.dart';
import '../../core/services/auth_service.dart';
import '../patient/patient_dashboard.dart';
import '../doctor/doctor_dashboard.dart';
import '../admin/admin_dashboard.dart';
import 'login_screen.dart';
import 'otp_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startInitSequence();
  }

  Future<void> _startInitSequence() async {
    // Wait for splash animations to complete
    await Future.delayed(const Duration(milliseconds: 1800));
    _checkAuthState();
  }

  void _checkAuthState() async {
    final auth = Provider.of<AuthService>(context, listen: false);

    // If still loading profile from Firebase, wait a bit
    if (auth.isLoading) {
      await Future.delayed(const Duration(milliseconds: 300));
      _checkAuthState();
      return;
    }

    if (auth.currentUser == null) {
      // Direct route to Login Screen
      _navigateTo(const LoginScreen());
    } else {
      if (auth.is2faVerified) {
        _routeToDashboard();
      } else {
        _navigateTo(const OtpScreen());
      }
    }
  }

  void _routeToDashboard() {
    final auth = Provider.of<AuthService>(context, listen: false);
    switch (auth.currentUser!.role) {
      case UserRole.admin:
      case UserRole.receptionist:
        _navigateTo(const AdminDashboard());
        break;
      case UserRole.doctor:
        _navigateTo(const DoctorDashboard());
        break;
      case UserRole.patient:
        _navigateTo(const PatientDashboard());
        break;
    }
  }

  void _navigateTo(Widget screen) {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: 600.ms,
          pageBuilder: (context, animation, secondaryAnimation) => screen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.gradientDecoration,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Glowing Double Ring with Clinical Cross Logo
              Stack(
                alignment: Alignment.center,
                children: [
                  // Outer pulse ring
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.12),
                        width: 1.5,
                      ),
                    ),
                  ).animate(onPlay: (controller) => controller.repeat())
                   .scale(begin: const Offset(0.75, 0.75), end: const Offset(1.3, 1.3), duration: 2200.ms, curve: Curves.easeOut)
                   .fadeOut(duration: 2200.ms),
                   
                  // Inner pulse ring
                  Container(
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.secondaryColor.withOpacity(0.2),
                        width: 2,
                      ),
                    ),
                  ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                   .scale(begin: const Offset(0.94, 0.94), end: const Offset(1.06, 1.06), duration: 1600.ms, curve: Curves.easeInOut),

                  // Core logo card
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                          blurRadius: 28,
                          spreadRadius: 1,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.health_and_safety_rounded,
                        size: 46,
                        color: Colors.white,
                      ),
                    ),
                  ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                   .scale(begin: const Offset(0.96, 0.96), end: const Offset(1.04, 1.04), duration: 1600.ms, curve: Curves.easeInOut),
                ],
              ),

              const SizedBox(height: 24),
              
              const Text(
                "MediQue",
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primaryColor,
                  letterSpacing: 1.5,
                ),
              ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0, duration: 600.ms),

              const SizedBox(height: 8),

              const Text(
                "Smart Queue Care & SaaS Clinics",
                style: TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 48),

              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
