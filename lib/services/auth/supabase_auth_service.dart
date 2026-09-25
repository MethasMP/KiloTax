import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';

class AuthUser {
  final String id;
  final String email;
  final String provider; // 'apple' | 'google'
  final String? displayName;
  final String? avatarUrl;
  final String? accessToken;

  const AuthUser({
    required this.id,
    required this.email,
    required this.provider,
    this.displayName,
    this.avatarUrl,
    this.accessToken,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'provider': provider,
    'display_name': displayName,
    'avatar_url': avatarUrl,
    'access_token': accessToken,
  };

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String,
    email: json['email'] as String? ?? '',
    provider: json['provider'] as String? ?? 'apple',
    displayName: json['display_name'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    accessToken: json['access_token'] as String?,
  );
}

class AuthResult {
  final bool success;
  final AuthUser? user;
  final String? errorMessage;

  const AuthResult({
    required this.success,
    this.user,
    this.errorMessage,
  });
}

/// Official Supabase Auth Service handling Native OAuth flows
/// (Native iOS Apple Sheet + Google Native Sheet) without opening Safari
class SupabaseAuthService {
  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Native iOS Sign in with Apple (Uses Apple Sheet with Face ID, no Safari)
  Future<AuthResult> signInWithApple() async {
    final client = _client;
    if (client == null) {
      return const AuthResult(
        success: false,
        errorMessage: 'Supabase is not initialized.',
      );
    }

    try {
      // 1. Generate nonce for cryptographic security
      final rawNonce = client.auth.generateRawNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      // 2. Open Native Apple ID Sheet
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = appleCredential.identityToken;
      if (idToken == null) {
        return const AuthResult(success: false, errorMessage: 'Could not obtain Apple Identity Token.');
      }

      // 3. Exchange Token directly with Supabase
      final authResponse = await client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      final supaUser = authResponse.user;
      final session = authResponse.session;

      if (supaUser != null) {
        return AuthResult(
          success: true,
          user: AuthUser(
            id: supaUser.id,
            email: supaUser.email ?? 'apple_user@icloud.com',
            provider: 'apple',
            accessToken: session?.accessToken,
          ),
        );
      }

      return const AuthResult(success: true);
    } catch (e) {
      debugPrint('Native Apple Sign In error: $e');
      return AuthResult(success: false, errorMessage: e.toString());
    }
  }

  // Singleton instance to prevent re-initialization overhead on every click
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: defaultTargetPlatform == TargetPlatform.iOS
        ? AppConstants.googleIosClientId
        : null,
    serverClientId: AppConstants.googleWebClientId,
    scopes: const [
      'email',
      'profile',
    ],
  );

  /// Native Sign in with Google (Uses Google In-App Sheet, no Safari)
  Future<AuthResult> signInWithGoogle() async {
    final client = _client;
    if (client == null) {
      return const AuthResult(
        success: false,
        errorMessage: 'Supabase is not initialized.',
      );
    }

    try {
      // 1. Trigger Google Native Authentication Sheet
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return const AuthResult(success: false, errorMessage: 'Google sign in was cancelled.');
      }

      // 2. Fetch ID Token directly (Skip unnecessary accessToken round-trip)
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        return const AuthResult(success: false, errorMessage: 'No ID token returned from Google.');
      }

      // 3. Fast-exchange Google ID Token with Supabase
      final authResponse = await client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      final supaUser = authResponse.user;
      final session = authResponse.session;

      if (supaUser != null) {
        final metadata = supaUser.userMetadata ?? {};
        final displayName = (metadata['full_name'] ?? metadata['name'] ?? googleUser.displayName) as String?;
        final avatarUrl = (metadata['avatar_url'] ?? metadata['picture'] ?? googleUser.photoUrl) as String?;

        return AuthResult(
          success: true,
          user: AuthUser(
            id: supaUser.id,
            email: supaUser.email ?? googleUser.email,
            provider: 'google',
            displayName: displayName,
            avatarUrl: avatarUrl,
            accessToken: session?.accessToken,
          ),
        );
      }

      return const AuthResult(success: true);
    } catch (e) {
      debugPrint('Native Google Sign In error: $e');
      return AuthResult(success: false, errorMessage: e.toString());
    }
  }

  AuthUser? getCurrentUser() {
    final client = _client;
    if (client == null) return null;
    final supaUser = client.auth.currentUser;
    final session = client.auth.currentSession;
    if (supaUser == null) return null;
    final metadata = supaUser.userMetadata ?? {};
    final displayName = (metadata['full_name'] ?? metadata['name']) as String?;
    final avatarUrl = (metadata['avatar_url'] ?? metadata['picture']) as String?;

    return AuthUser(
      id: supaUser.id,
      email: supaUser.email ?? '',
      provider: supaUser.appMetadata['provider'] ?? 'oauth',
      displayName: displayName,
      avatarUrl: avatarUrl,
      accessToken: session?.accessToken,
    );
  }

  Stream<AuthState>? get onAuthStateChange {
    return _client?.auth.onAuthStateChange;
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _client?.auth.signOut();
  }
}
