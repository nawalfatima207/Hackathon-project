import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Error from a Google redirect sign-in, shown once on the login screen.
  String? _redirectError;
  String? takeRedirectError() {
    final e = _redirectError;
    _redirectError = null;
    return e;
  }

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<String?> signUp(String email, String password, {String? displayName}) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final trimmedName = displayName?.trim();
      if (trimmedName != null && trimmedName.isNotEmpty) {
        await credential.user?.updateDisplayName(trimmedName);
        await credential.user?.reload();
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Sign up failed.';
    }
  }

  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Sign in failed.';
    }
  }

  Future<String?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        try {
          // Popup first: it hands the signed-in user straight back to this
          // page, so it works even when the redirect result gets lost (which
          // happens when the auth domain differs from the page's domain, e.g.
          // on localhost -- the symptom is "Google login finishes but the app
          // stays on the login screen").
          await _auth.signInWithPopup(provider);
          return null;
        } on FirebaseAuthException catch (e) {
          if (e.code == 'popup-closed-by-user' ||
              e.code == 'cancelled-popup-request') {
            return 'Sign in cancelled.';
          }
          if (e.code == 'popup-blocked') {
            // Browser blocked the popup -> fall back to a full-page redirect.
            await _auth.signInWithRedirect(provider);
            return null;
          }
          rethrow;
        }
      }

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return 'Sign in cancelled.';

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('[Zylo] Google sign-in FAILED: ${e.code} -- ${e.message}');
      return e.message ?? 'Google sign in failed.';
    } catch (e) {
      debugPrint('[Zylo] Google sign-in threw a non-Firebase error: $e');
      return 'Google sign in failed: $e';
    }
  }

  /// Call once at startup (web only). Completes the sign-in started by
  /// signInWithRedirect() and surfaces any error that happened along the way
  /// (e.g. an account already existing under a different provider).
  Future<String?> consumePendingRedirectResult() async {
    if (!kIsWeb) return null;
    try {
      final result = await _auth.getRedirectResult();
      if (result.user != null) {
        debugPrint('[Zylo] Google redirect sign-in succeeded: ${result.user!.email}');
      } else {
        debugPrint('[Zylo] getRedirectResult() returned no user (no pending redirect, or already consumed).');
      }
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('[Zylo] Google redirect sign-in FAILED: ${e.code} -- ${e.message}');
      _redirectError = e.message ?? 'Google sign in failed.';
      return _redirectError;
    } catch (e) {
      debugPrint('[Zylo] Google redirect sign-in threw a non-Firebase error: $e');
      return null;
    }
  }

  Future<void> updateDisplayName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    try {
      await _auth.currentUser?.updateDisplayName(trimmed);
      await _auth.currentUser?.reload();
    } catch (_) {
      // best-effort -- profile screen keeps the local value regardless
    }
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      try {
        if (await _googleSignIn.isSignedIn()) {
          await _googleSignIn.signOut();
        }
      } catch (_) {
        // ignore Google sign-out errors if user never signed in with Google
      }
    }
    await _auth.signOut();
  }
}