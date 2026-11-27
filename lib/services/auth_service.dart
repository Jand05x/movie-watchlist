import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'user_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await UserService.ensureProfile();
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  Future<String?> signUp(
    String email,
    String password,
    String username,
  ) async {
    if (!UserService.isValidUsername(username)) {
      return 'Usernames must be 3-20 characters: letters, numbers, or _.';
    }

    UserCredential? credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await UserService.createProfile(username: username);
      await UserService.ensureProfile();
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } on StateError catch (e) {
      if (e.message == 'That username is already taken.') {
        await credential?.user?.delete();
      }
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
