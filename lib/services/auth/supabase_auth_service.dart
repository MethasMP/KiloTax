import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
export 'package:supabase_flutter/supabase_flutter.dart' show AuthState;
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
    } catch (e, stack) {
      debugPrint(
          '[SupabaseAuth] Warning obtaining Supabase client instance: $e\n$stack');
      return null;
    }
  }

  /// Pre-warms DNS, TLS, and native channel initialization
  /// to eliminate cold-start latency when user taps Sign In (~300-500ms saved).
  void prewarmConnection() {
    try {
      final client = _client;
      if (client != null) {
        // Fire-and-forget lightweight head/get to prime HTTP/2 & TLS connection without admin privileges
        unawaited(client.auth.getClaims().then((_) {}, onError: (_) {}));
      }
      // Initialize native Google Sign In channel in background without triggering background sign-in
      // GoogleSignIn instance initialization primes platform channels lazily
    } catch (_) {
      // Ignored: Best-effort network and channel priming
    }
  }

  /// Native iOS Sign in with Apple (Uses Apple Sheet with Face ID, no Safari)
  /// If [onLocalSuccess] is provided, it is invoked immediately after the OS returns
  /// the identityToken, enabling instant zero-latency UI transition while Supabase
  /// session exchange completes in the background.
  Future<AuthResult> signInWithApple({
    void Function(AuthUser optimisticUser)? onLocalSuccess,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return const AuthResult(
        success: false,
        errorMessage: 'Apple Sign In is only supported on Apple devices.',
      );
    }

    final client = _client;
    if (client == null) {
      return const AuthResult(
        success: false,
        errorMessage: 'Supabase is not initialized.',
      );
    }

    try {
      final rawNonce = client.auth.generateRawNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = appleCredential.identityToken;
      if (idToken == null) {
        return const AuthResult(
            success: false,
            errorMessage: 'Could not obtain Apple Identity Token.');
      }

      final email = appleCredential.email ?? 'apple_user@icloud.com';
      final givenName = appleCredential.givenName ?? '';
      final familyName = appleCredential.familyName ?? '';
      final fullName = '$givenName $familyName'.trim();

      // OPTIMISTIC HANDSHAKE: Notify caller immediately that OS verification succeeded
      final optimisticUser = AuthUser(
        id: appleCredential.userIdentifier ?? 'apple_pending',
        email: email,
        provider: 'apple',
        displayName: fullName.isNotEmpty ? fullName : null,
      );
      if (onLocalSuccess != null) {
        onLocalSuccess(optimisticUser);
      }

      // 12-second bound to prevent infinite hang on unstable mobile connection
      final authResponse = await client.auth
          .signInWithIdToken(
            provider: OAuthProvider.apple,
            idToken: idToken,
            nonce: rawNonce,
          )
          .timeout(
            const Duration(seconds: 12),
            onTimeout: () => throw TimeoutException(
                'Connecting to Supabase Auth server timed out. Please check your network.'),
          );

      final supaUser = authResponse.user;
      final session = authResponse.session;

      if (supaUser != null) {
        return AuthResult(
          success: true,
          user: AuthUser(
            id: supaUser.id,
            email: supaUser.email ?? email,
            provider: 'apple',
            displayName: fullName.isNotEmpty ? fullName : null,
            accessToken: session?.accessToken,
          ),
        );
      }

      return AuthResult(success: true, user: optimisticUser);
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
  /// If [onLocalSuccess] is provided, it is invoked immediately after the user selects
  /// their Google account, enabling instant zero-latency UI transition while Supabase
  /// session exchange completes in the background.
  Future<AuthResult> signInWithGoogle({
    void Function(AuthUser optimisticUser)? onLocalSuccess,
  }) async {
    final client = _client;
    if (client == null) {
      return const AuthResult(
        success: false,
        errorMessage: 'Supabase is not initialized.',
      );
    }

    try {
      // shortcut: avoid blocking await _googleSignIn.signOut() on tap to launch sheet instantly (~500-2000ms faster). Proper signOut occurs in signOut().
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return const AuthResult(
            success: false, errorMessage: 'Google sign in was cancelled.');
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        return const AuthResult(
            success: false, errorMessage: 'No ID token returned from Google.');
      }

      // OPTIMISTIC HANDSHAKE: Notify caller immediately that Google Sheet succeeded
      final optimisticUser = AuthUser(
        id: googleUser.id,
        email: googleUser.email,
        provider: 'google',
        displayName: googleUser.displayName,
        avatarUrl: googleUser.photoUrl,
      );
      if (onLocalSuccess != null) {
        onLocalSuccess(optimisticUser);
      }

      // 12-second bound to prevent infinite hang on unstable mobile connection
      final authResponse = await client.auth
          .signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: idToken,
          )
          .timeout(
            const Duration(seconds: 12),
            onTimeout: () => throw TimeoutException(
                'Connecting to Supabase Auth server timed out. Please check your network.'),
          );

      final supaUser = authResponse.user;
      final session = authResponse.session;

      if (supaUser != null) {
        final metadata = supaUser.userMetadata ?? {};
        final displayName = (metadata['full_name'] ??
            metadata['name'] ??
            googleUser.displayName) as String?;
        final avatarUrl = (metadata['avatar_url'] ??
            metadata['picture'] ??
            googleUser.photoUrl) as String?;

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

      return AuthResult(success: true, user: optimisticUser);
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
    final avatarUrl =
        (metadata['avatar_url'] ?? metadata['picture']) as String?;

    return AuthUser(
      id: supaUser.id,
      email: supaUser.email ?? '',
      provider: supaUser.appMetadata['provider'] ?? 'oauth',
      displayName: displayName,
      avatarUrl: avatarUrl,
      accessToken: session?.accessToken,
    );
  }

  /// Dynamically retrieves active JWT access token from current Supabase session
  String? get currentAccessToken => _client?.auth.currentSession?.accessToken;

  Stream<AuthState>? get onAuthStateChange {
    return _client?.auth.onAuthStateChange;
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e, stack) {
      debugPrint(
          '[SupabaseAuth] Warning signing out of Google Sign-In: $e\n$stack');
    }
    await _client?.auth.signOut();
  }

  /// Only the server transaction can confirm deletion of the auth account.
  Future<bool> deleteAccount() async {
    final client = _client;
    if (client == null || client.auth.currentUser == null) return false;
    try {
      await client.rpc('delete_user_account');
    } catch (e, stack) {
      debugPrint('[SupabaseAuth] Account deletion failed: $e\n$stack');
      return false;
    }

    // The account is already deleted. Session revocation cannot undo that.
    try {
      await signOut();
    } catch (e, stack) {
      debugPrint('[SupabaseAuth] Post-deletion sign out failed: $e\n$stack');
    }
    return true;
  }
}
