import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
        // google_sign_in's programmatic signIn() is no longer supported on
        // Flutter Web (Google deprecated that flow for GIS). On web, Firebase
        // Auth's own popup handles the whole OAuth round trip instead.
        final provider = GoogleAuthProvider();
        await _auth.signInWithPopup(provider);
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
      return e.message ?? 'Google sign in failed.';
    } catch (e) {
      return 'Google sign in failed: $e';
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