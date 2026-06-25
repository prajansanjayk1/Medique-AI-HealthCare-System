import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme.dart';
import 'core/services/auth_service.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/splash_screen.dart';
import 'features/patient/patient_dashboard.dart';
import 'features/doctor/doctor_dashboard.dart';
import 'features/admin/admin_dashboard.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'core/services/db_service.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // If already initialized (e.g., hot restart), ignore the error.
    if (!e.toString().contains('already exists')) {
      debugPrint("Firebase initialization error: $e");
    }
  }

  // Initialize notifications
  try {
    await NotificationService.instance.init();
  } catch (e) {
    debugPrint("NotificationService initialization error: $e");
  }
  
  final prefs = await SharedPreferences.getInstance();
  final String clinicId = prefs.getString('clinic_id') ?? 'medique-b29ee';
  
  runApp(MyApp(initialClinicId: clinicId));
}

class MyApp extends StatelessWidget {
  final String initialClinicId;
  const MyApp({Key? key, required this.initialClinicId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(create: (_) => AuthService(initialClinicId)),
        ChangeNotifierProvider<DbService>(create: (_) => DbService(initialClinicId)),
      ],
      child: MaterialApp(
        title: 'MediQue Queue Care',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
      ),
    );
  }
}

class RootAuthWrapper extends StatelessWidget {
  const RootAuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);

    if (auth.isLoading) {
      return Scaffold(
        body: Container(
          decoration: AppTheme.gradientDecoration,
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                SizedBox(height: 16),
                Text(
                  "Initializing MediQue...",
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (auth.currentUser == null) {
      return const LoginScreen();
    }

    // Role-based routing
    switch (auth.currentUser!.role) {
      case UserRole.admin:
      case UserRole.receptionist:
        return const AdminDashboard();
      case UserRole.doctor:
        return const DoctorDashboard();
      case UserRole.patient:
        return const PatientDashboard();
    }
  }
}
