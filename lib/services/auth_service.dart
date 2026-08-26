import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Handles phone number authentication via Firebase.
class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _verificationId;
  int? _resendToken;

  AuthService() {
    _auth.authStateChanges().listen((_) => notifyListeners());
  }

  /// Send OTP to the given phone number.
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onError,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-sign-in on Android (instant verification)
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          _isLoading = false;
          notifyListeners();
          onError(e.message ?? 'Verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _isLoading = false;
          notifyListeners();
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      onError(e.toString());
    }
  }

  /// Verify the OTP code entered by the user.
  Future<void> verifyOtp({
    required String smsCode,
    required void Function(UserCredential credential) onSuccess,
    required void Function(String error) onError,
  }) async {
    if (_verificationId == null) {
      onError('No verification ID. Please request a new OTP.');
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      _isLoading = false;
      notifyListeners();
      onSuccess(userCredential);
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      onError(e.message ?? 'Invalid OTP');
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      onError(e.toString());
    }
  }

  /// Sign out.
  Future<void> signOut() async {
    await _auth.signOut();
    notifyListeners();
  }
}
