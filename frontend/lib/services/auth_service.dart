import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

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
        // signInWithPopup relies on the popup relaying its result back to
        // this window via storage/postMessage. Modern Chrome's third-party
        // storage partitioning blocks that relay for a lot of users -- the
        // popup finishes fine on Google's side, but the result never makes
        // it back, so sign-in looks like it silently does nothing. Redirecting
        // the whole page avoids that relay entirely.
        final provider = GoogleAuthProvider();
        await _auth.signInWithRedirect(provider);
        // The page navigates away here. When it comes back, authStateChanges()
        // (already wired up in main.dart) picks up the signed-in user on its
        // own -- see consumePendingRedirectResult() for surfacing errors.
        return null;
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
      return e.message ?? 'Google sign in failed.';
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