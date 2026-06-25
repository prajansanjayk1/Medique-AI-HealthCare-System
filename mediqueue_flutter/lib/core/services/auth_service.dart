import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'localization_service.dart';

enum UserRole { admin, doctor, receptionist, patient }

class AppUser {
  final String uid;
  final String email;
  final UserRole role;
  final String? name;

  AppUser({
    required this.uid,
    required this.email,
    required this.role,
    this.name,
  });
}

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  String _appId = "medique-b29ee";
  String get appId => _appId;

  String _clinicCode = "CARE5E";
  String get clinicCode => _clinicCode;

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;

  bool _is2faVerified = false;
  bool get is2faVerified => _is2faVerified;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  AuthService(String initialId) {
    _appId = initialId;
    _loadClinicCode();
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _loadClinicCode() async {
    final prefs = await SharedPreferences.getInstance();
    String code = prefs.getString('clinic_code') ?? "CARE5E";
    if (code.contains('-') || code.length > 8) {
      code = code.split('-').last.toUpperCase();
    }
    _clinicCode = code;
    notifyListeners();
  }

  Future<void> updateClinicId(String newId, [String? code]) async {
    _appId = newId;
    String sanitizedCode = code ?? newId.split('-').last.toUpperCase();
    if (sanitizedCode.contains('-') || sanitizedCode.length > 8) {
      sanitizedCode = sanitizedCode.split('-').last.toUpperCase();
    }
    _clinicCode = sanitizedCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('clinic_id', newId);
    await prefs.setString('clinic_code', _clinicCode);
    if (_auth.currentUser != null) {
      await _onAuthStateChanged(_auth.currentUser);
    } else {
      notifyListeners();
    }
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    _isLoading = true;
    notifyListeners();

    if (firebaseUser == null) {
      _currentUser = null;
      _is2faVerified = false;
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final String uid = firebaseUser.uid;
      final String email = firebaseUser.email ?? "";

      final prefs = await SharedPreferences.getInstance();
      final verifiedUntil = prefs.getInt('medique_2fa_$uid') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      const TWENTY_FOUR_HOURS_MS = 24 * 60 * 60 * 1000;
      
      final isBypassedAccount = (email.toLowerCase() == "lovefornature727@gmail.com" || 
                                 email.toLowerCase() == "prajansanjayko@gmail.com");
                                 
      if (isBypassedAccount || (verifiedUntil > now && (verifiedUntil - now) <= TWENTY_FOUR_HOURS_MS + 60000)) {
        _is2faVerified = true;
      } else {
        _is2faVerified = false;
      }

      // 1. Check if email belongs to superadmin
      if (email.toLowerCase() == "prajansanjayko@gmail.com" || 
          email.toLowerCase() == "prajansanjayko@gmsil.com") {
        _currentUser = AppUser(uid: uid, email: email, role: UserRole.admin, name: "Clinic Admin");
        _isLoading = false;
        notifyListeners();
        return;
      }

      // 2. Query the staff collection to see if user has a clinic staff role
      final staffDoc = await _db.doc("artifacts/$appId/public/data/staff/$uid").get();
      if (staffDoc.exists) {
        final data = staffDoc.data()!;
        final String roleStr = data['role'] ?? "receptionist";
        UserRole role = UserRole.receptionist;
        if (roleStr == "doctor") role = UserRole.doctor;
        if (roleStr == "admin") role = UserRole.admin;

        // Force doctor offline on session restoration / login
        if (role == UserRole.doctor) {
          try {
            await _db.doc("artifacts/$appId/public/data/staff/$uid").update({
              'sessionActive': true,
              'isActive': false,
            });
          } catch (e) {
            print("Error updating doctor presence: $e");
          }
        }

        _currentUser = AppUser(
          uid: uid,
          email: email,
          role: role,
          name: data['name'] ?? "Staff member",
        );
        try {
          await LocalizationService.instance.loadUserLanguage(uid, isStaff: true, appId: appId);
        } catch (e) {
          print("Error loading staff language preference: $e");
        }
      } else {
        // 3. Fallback: Query the patient user profile
        final userDoc = await _db.doc("artifacts/$appId/users/$uid").get();
        String name = "Patient";
        if (userDoc.exists) {
          name = userDoc.data()?['name'] ?? "Patient";
        }
        _currentUser = AppUser(uid: uid, email: email, role: UserRole.patient, name: name);
        try {
          await LocalizationService.instance.loadUserLanguage(uid, isStaff: false, appId: appId);
        } catch (e) {
          print("Error loading patient language preference: $e");
        }
      }
    } catch (e) {
      print("Error loading user profile: $e");
      _currentUser = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> registerPatient({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String age,
    required String address,
    String? dob,
    String? gender,
    String? profession,
  }) async {
    final UserCredential creds = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    final String uid = creds.user!.uid;

    final Map<String, dynamic> patientData = {
      'name': name,
      'mobile': phone,
      'email': email,
      'age': age,
      'address': address,
      'dob': dob ?? "",
      'gender': gender ?? "",
      'profession': profession ?? "",
      'createdAt': FieldValue.serverTimestamp(),
    };

    // 1. Create patient document in /users/{uid}
    await _db.doc("artifacts/$appId/users/$uid").set(patientData);

    // 2. Create client-scoped patient profile in public/data/patients/{uid}/profile/details
    await _db.doc("artifacts/$appId/public/data/patients/$uid/profile/details").set(patientData);

    // 3. Sync to main patients directory (public/data/patients/{uid}) for web/doctor portals
    await _db.doc("artifacts/$appId/public/data/patients/$uid").set(patientData, SetOptions(merge: true));

    _currentUser = AppUser(uid: uid, email: email, role: UserRole.patient, name: name);
    notifyListeners();
  }

  Future<void> verify2fa() async {
    if (_auth.currentUser != null) {
      final uid = _auth.currentUser!.uid;
      final prefs = await SharedPreferences.getInstance();
      final verifiedUntil = DateTime.now().millisecondsSinceEpoch + 24 * 60 * 60 * 1000;
      await prefs.setInt('medique_2fa_$uid', verifiedUntil);
      _is2faVerified = true;
      notifyListeners();
    }
  }

  void bypass2fa() {
    _is2faVerified = true;
    notifyListeners();
  }

  Future<void> signOut() async {
    if (_auth.currentUser != null) {
      final uid = _auth.currentUser!.uid;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('medique_2fa_$uid');
    }
    await _auth.signOut();
    _is2faVerified = false;
    _currentUser = null;
    notifyListeners();
  }

  static const String _googleAppsScriptUrl = "https://script.google.com/macros/s/AKfycbx5t9TpAzpHhkvpSxDKDfRIYrcBXLtQ3jAFkAq8Qu6BzxQPU2mVZANKVcKH82LxOQxXZw/exec";

  Future<Map<String, dynamic>> callOtpProvider(String action, Map<String, dynamic> payload) async {
    if (_googleAppsScriptUrl.isEmpty || _googleAppsScriptUrl.contains("YOUR_")) {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        action == 'sendOtp' ? 'sendOtpEmail' : 'verifyOtpAndLogin'
      );
      final HttpsCallableResult result = await callable.call(payload);
      return Map<String, dynamic>.from(result.data as Map);
    }

    var response = await http.post(
      Uri.parse(_googleAppsScriptUrl.trim()),
      headers: <String, String>{
        'Content-Type': 'text/plain',
      },
      body: jsonEncode(<String, dynamic>{
        'action': action,
        ...payload,
      }),
    );

    // Follow manual redirect for POST to Google Apps Script which returns 302/307
    if (response.statusCode == 302 || response.statusCode == 301 || response.statusCode == 307 || response.statusCode == 308) {
      final redirectUrl = response.headers['location'] ?? response.headers['Location'];
      if (redirectUrl != null) {
        response = await http.get(Uri.parse(redirectUrl));
      }
    }

    if (response.statusCode != 200) {
      throw Exception("HTTP Error: ${response.statusCode}");
    }

    final Map<String, dynamic> result = Map<String, dynamic>.from(
      jsonDecode(response.body) as Map
    );
    
    if (result['success'] != true) {
      throw Exception(result['error'] ?? "Operation failed");
    }
    return result;
  }

  Future<void> updateProfileAndChangePassword({
    required String newName,
    String? newPassword,
    String? mobile,
    String? dob,
    String? age,
    String? gender,
    String? address,
    String? profession,
    String? emergencyContact,
  }) async {
    final User? firebaseUser = _auth.currentUser;
    if (firebaseUser == null) throw Exception("User is not signed in.");

    if (newName.trim().isNotEmpty && newName != firebaseUser.displayName) {
      await firebaseUser.updateDisplayName(newName);
    }

    final Map<String, dynamic> updateData = {
      'name': newName,
      if (mobile != null) 'mobile': mobile,
      if (dob != null) 'dob': dob,
      if (age != null) 'age': age,
      if (gender != null) 'gender': gender,
      if (address != null) 'address': address,
      if (profession != null) 'profession': profession,
      if (emergencyContact != null) 'emergencyContact': emergencyContact,
    };
    await _db.doc("artifacts/$appId/users/${firebaseUser.uid}").set(updateData, SetOptions(merge: true));
    await _db.doc("artifacts/$appId/users/${firebaseUser.uid}/profile/details").set(updateData, SetOptions(merge: true));
    await _db.doc("artifacts/$appId/public/data/patients/${firebaseUser.uid}/profile/details").set(updateData, SetOptions(merge: true));
    await _db.doc("artifacts/$appId/public/data/patients/${firebaseUser.uid}").set(updateData, SetOptions(merge: true));

    if (newPassword != null && newPassword.trim().isNotEmpty) {
      await firebaseUser.updatePassword(newPassword);
    }

    if (_currentUser != null) {
      _currentUser = AppUser(
        uid: _currentUser!.uid,
        email: _currentUser!.email,
        role: _currentUser!.role,
        name: newName,
      );
      notifyListeners();
    }
  }

  void updateCurrentUserLocalName(String newName) {
    if (_currentUser != null) {
      _currentUser = AppUser(
        uid: _currentUser!.uid,
        email: _currentUser!.email,
        role: _currentUser!.role,
        name: newName,
      );
      notifyListeners();
    }
  }
}
