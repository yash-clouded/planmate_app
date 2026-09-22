import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Handles Google Sign-In authentication via Firebase.
class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _google = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  AuthService() {
    _auth.authStateChanges().listen((_) => notifyListeners());
  }

  /// Sign in with Google. Returns the user credential on success.
  Future<void> signInWithGoogle({
    required void Function(UserCredential credential) onSuccess,
    required void Function(String error) onError,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final googleUser = await _google.signIn();
      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        onError('Sign in cancelled');
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      _isLoading = false;
      notifyListeners();
      onSuccess(userCredential);
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      onError(e.message ?? 'Google sign in failed');
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      onError(e.toString());
    }
  }

  /// Sign out from both Firebase and Google.
  Future<void> signOut() async {
    try {
      await _google.signOut();
    } catch (_) {}
    await _auth.signOut();
    notifyListeners();
  }
}
