import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();
  static const String _recoveryCodeKey = 'biometric_recovery_code';
  static const String _defaultRecoveryCode = '123456';

  /// Get the saved recovery code (defaults to '123456')
  static Future<String> getRecoveryCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_recoveryCodeKey) ?? _defaultRecoveryCode;
    } catch (e) {
      debugPrint("Error getting recovery code: $e");
      return _defaultRecoveryCode;
    }
  }

  /// Save a new recovery code
  static Future<bool> setRecoveryCode(String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_recoveryCodeKey, code);
    } catch (e) {
      debugPrint("Error setting recovery code: $e");
      return false;
    }
  }

  /// Verify if the input code matches the saved recovery code
  static Future<bool> verifyRecoveryCode(String inputCode) async {
    final savedCode = await getRecoveryCode();
    return savedCode == inputCode;
  }

  /// Check if the device is capable of biometric authentication
  static Future<bool> isBiometricSupported() async {
    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      final bool isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } on PlatformException catch (e) {
      debugPrint("Biometric support check error: $e");
      return false;
    }
  }

  /// Authenticate the user using biometrics
  static Future<bool> authenticate({String reason = 'Authenticate to access your MediQue account'}) async {
    try {
      final bool isSupported = await isBiometricSupported();
      if (!isSupported) return false;

      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint("Biometric authentication error: $e");
      return false;
    }
  }
}
