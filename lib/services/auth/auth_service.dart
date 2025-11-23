/*
AUTHENTICATION SERVICE (Supabase Version)

Handles all authentication logic with Supabase:
- Login
- Register
- Logout
- Delete account (requires password confirmation)
*/

import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_service.dart';


class AuthService {
  final _auth = Supabase.instance.client.auth;
  final DatabaseService _db = DatabaseService();

  /* ==================== CURRENT USER ==================== */
  User? getCurrentUser() => _auth.currentUser;

/// Returns the current user's id, or '' if there's no logged-in user.
String getCurrentUserId() {
  final user = _auth.currentUser;
  if (user == null) {
    return '';
  }
  return user.id;
}


  /* ==================== LOGIN / REGISTER ==================== */

  /// Login using email/password
  Future<AuthResponse> loginEmailPassword(String email, String password) async {

    // Attempt login
    try {
      final authResponse = await _auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authResponse.session == null) {
        throw Exception("Login failed.");
      }
      return authResponse;
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Register new user
  Future<AuthResponse> registerEmailPassword(String email, String password) async {
    try {
      // 1️⃣ Sign up user
      final authResponse = await _auth.signUp(
        email: email,
        password: password,
      );

      if (authResponse.user == null) throw Exception("Registration failed.");


      // // 3️⃣ Sign in automatically
      // await _auth.signInWithPassword(
      //   email: email,
      //   password: password,
      // );

      return authResponse;
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }


  /* ==================== LOGOUT ==================== */
  Future<void> logout() async {
    try {
      await _auth.signOut();
      print("User logged out successfully.");
    } catch (e) {
      print("Logout error: $e");
      rethrow;
    }
  }

  /* ==================== DELETE ACCOUNT WITH PASSWORD ==================== */

  /// Delete user from firebase
  Future<void> deleteAccountWithPassword(String password) async {
    final user = getCurrentUser();
    if (user == null || user.email == null) {
      throw Exception("No logged-in user.");
    }

    try {
      // 1️⃣ Re-authenticate the user using Supabase signIn
      final res = await _auth.signInWithPassword(
        email: user.email!,
        password: password,
      );

      if (res.session == null) {
        throw Exception("Invalid password.");
      }

      // 2️⃣ Delete all user data from database
      await _db.deleteUserDataFromDatabase(user.id);

      // delete user's auth record
      await deleteMyAccountAuth();

    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      print("Error deleting account: $e");
      rethrow;
    }
  }

  /// Delete user auth
  Future<void> deleteMyAccountAuth() async {
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;

    if (session == null) {
      print("❌ No user logged in");
      return;
    }

    // Use your Edge Function URL
    final url = Uri.parse(
      'https://njotewktazwhoprvhsvj.supabase.co/functions/v1/delete-user',
    );

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}', // must include this
        },
        // No body needed because the function uses the token to get the user
      );

      if (response.statusCode == 200) {
        print('✅ Account deleted successfully!');

        // Sign out the user locally after deletion
        await logout();
        print('User signed out locally.');
      } else {
        print('❌ Failed to delete account: ${response.body}');
      }
    } catch (e) {
      print('❌ Error calling delete-user function: $e');
    }
  }



}