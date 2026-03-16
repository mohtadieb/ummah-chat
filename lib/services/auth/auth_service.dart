/*
AUTHENTICATION SERVICE (Supabase Version)

Handles all authentication logic with Supabase:
- Login
- Register
- Logout
- Delete account (requires password confirmation)
- Google OAuth login
*/

import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';                 // 👈 for kIsWeb
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
    try {
      final authResponse = await _auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = authResponse.user;
      if (authResponse.session == null || user == null) {
        throw Exception("Login failed.");
      }

      // ❗ Require verified email
      if (user.emailConfirmedAt == null) {
        // Immediately log them out again
        await _auth.signOut();
        throw Exception(
          "Please verify your email address first. "
              "Click the link we sent you by email.",
        );
      }

      return authResponse;
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }


  /// Register new user
  Future<AuthResponse> registerEmailPassword(String email, String password) async {
    try {
      final response = await _auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: 'https://ummah-chat.com',
      );

      if (response.user == null) {
        throw Exception("Registration failed.".tr());
      }

      // If email already exists and is confirmed,
      // Supabase may still return a user object.
      // So check identities to detect existing account.
      if (response.user!.identities != null &&
          response.user!.identities!.isEmpty) {
        throw Exception("An account with this email already exists.".tr());
      }

      return response;
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  /// 🔐 Login / register with Google (Supabase OAuth)
  Future<void> signInWithGoogle() async {
    // For web: Supabase handles redirect automatically.
    // For mobile: use custom deep link defined in AndroidManifest + Supabase URL config.
    final redirectUrl = kIsWeb ? null : 'ummahchat://login-callback';

    try {
      await _auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
      );
      // On mobile, this opens the browser and then returns via deep link.
      // Session is stored automatically on return.
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      rethrow;
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

  /// Delete user from Supabase (auth + DB)
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

      // 3️⃣ Delete user's auth record via Edge Function
      await deleteMyAccountAuth();
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      print("Error deleting account: $e");
      rethrow;
    }
  }

  /// Call Edge Function to delete user auth
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
