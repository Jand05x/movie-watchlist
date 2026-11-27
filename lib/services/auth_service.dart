import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'user_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
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
    try {
      if (UserService.normalize(username).isEmpty) {
        return 'Choose a username.';
      }
      if (await UserService.isUsernameTaken(username)) {
        return 'That username is already taken.';
      }

      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await UserService.createProfile(username: username);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
