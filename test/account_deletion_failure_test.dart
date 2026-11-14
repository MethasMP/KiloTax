import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart' as sqlite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:kilotax/services/receipts/receipt_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import 'package:kilotax/data/models/vehicle.dart';
import 'package:kilotax/services/auth/supabase_auth_service.dart';
import 'package:kilotax/services/evidence/evidence_vault_service.dart';
import 'package:kilotax/services/storage/local_storage_service.dart';
import 'package:kilotax/state/app_state.dart';
import 'package:kilotax/services/sync/sync_engine_service.dart';
import 'package:kilotax/ui/screens/dashboard/widgets/account_settings_sheet.dart';

class DeletionAuth extends SupabaseAuthService {
  bool succeeds = false;
  @override
  AuthUser? getCurrentUser() => const AuthUser(
      id: 'owner', email: 'owner@example.test', provider: 'google');
  @override
  Stream<AuthState>? get onAuthStateChange => null;
  @override
  Future<bool> deleteAccount() async => succeeds;
}

class TrackedRestoreState extends AppState {
  TrackedRestoreState({
    super.storageService,
    super.authService,
    super.syncEngine,
    super.evidenceVaultService,
  });

  final restores = <Future<CloudRestoreResult>>[];

  @override
  Future<CloudRestoreResult> restoreFromCloud() {
    final restore = super.restoreFromCloud();
    restores.add(restore);
    return restore;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ffi.sqfliteFfiInit();
  sqlite.databaseFactory = ffi.databaseFactoryFfi;
  late Directory inboxRoot;
  setUp(() async {
    inboxRoot =
        await Directory.systemTemp.createTemp('receipt_deletion_boundary');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => inboxRoot.path);
  });
  tearDown(() async {
    final db =
        await ReceiptDatabase.open('${inboxRoot.path}/receipt_inbox.sqlite');
    await db.database.close();
    await inboxRoot.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'), null);
  });

  group('Remote deletion acknowledgement', () {
    var rpcFails = true;
    var logoutFails = false;
    final requests = <http.Request>[];
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      requests.clear();
      rpcFails = true;
      logoutFails = false;
      await Supabase.initialize(
        url: 'https://example.test',
        publishableKey: 'test-key',
        authOptions: FlutterAuthClientOptions(
            autoRefreshToken: false,
            detectSessionInUri: false,
            localStorage: EmptyLocalStorage()),
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/token')) {
            return http.Response(
                jsonEncode({
                  'access_token': 'test-access-token',
                  'refresh_token': 'test-refresh-token',
                  'token_type': 'bearer',
                  'expires_in': 3600,
                  'user': {
                    'id': 'owner',
                    'aud': 'authenticated',
                    'email': 'owner@example.test',
                    'created_at': '2026-01-01T00:00:00Z',
                    'app_metadata': {'provider': 'email'},
                    'user_metadata': {},
                  },
                }),
                200,
                request: request,
                headers: {'content-type': 'application/json'});
          }
          if (request.url.path.endsWith('/rpc/delete_user_account')) {
            return rpcFails
                ? http.Response(
                    '{"message":"Deletion unavailable","code":"P0001","details":"test failure","hint":"retry"}',
                    500,
                    request: request)
                : http.Response('', 204,
                    request: request,
                    headers: {'content-type': 'application/json'});
          }
          if (request.url.path.endsWith('/logout')) {
            return http.Response(logoutFails ? '{"message":"Offline"}' : '',
                logoutFails ? 500 : 204,
                request: request);
          }
          return http.Response('', 204,
              request: request, headers: {'content-type': 'application/json'});
        }),
      );
      await Supabase.instance.client.auth.signInWithPassword(
          email: 'owner@example.test', password: 'test-password');
      requests.clear();
    });
    tearDown(() => Supabase.instance.dispose());

    test('RPC failure returns failure and keeps session for retry', () async {
      expect(await SupabaseAuthService().deleteAccount(), isFalse);
      expect(Supabase.instance.client.auth.currentUser, isNotNull);
      expect(requests.where((r) => r.method == 'DELETE'), isEmpty,
          reason: 'Partial row deletion cannot delete the auth account.');
    });

    test('acknowledged RPC deletes account and clears local session', () async {
      rpcFails = false;
      expect(await SupabaseAuthService().deleteAccount(), isTrue);
      expect(Supabase.instance.client.auth.currentUser, isNull);
    });

    test(
        'acknowledged deletion succeeds even when remote logout is unavailable',
        () async {
      rpcFails = false;
      logoutFails = true;
      expect(await SupabaseAuthService().deleteAccount(), isTrue);
      expect(Supabase.instance.client.auth.currentUser, isNull);
    });
  });

  group('Deletion preserves recoverable records on failure', () {
    late TrackedRestoreState state;
    late LocalStorageService storage;
    late DeletionAuth auth;
    late Directory vault;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await LocalStorageService.init();
      auth = DeletionAuth();
      vault = await Directory.systemTemp.createTemp('deletion-vault-');
      await File('${vault.path}/receipt.jpg').writeAsString('receipt evidence');
      state = TrackedRestoreState(
          storageService: storage,
          authService: auth,
          syncEngine: SyncEngineService(
              httpClient: MockClient((request) async => http.Response('[]', 200,
                  request: request,
                  headers: {'content-type': 'application/json'}))),
          evidenceVaultService: EvidenceVaultService(vaultDirectory: vault));
      await state.init();
      await Future.wait(state.restores);
      await state.completeOnboarding();
      await state
          .addVehicle(Vehicle(id: 'car', make: 'Toyota', model: 'Hilux'));
    });
    tearDown(() async {
      await Future.wait(state.restores);
      state.dispose();
      await vault.delete(recursive: true);
    });

    test('remote failure retains records, account and onboarding for retry',
        () async {
      await state.deleteAccount();
      expect(state.isAuthenticated, isTrue);
      expect(state.vehicles.single.id, 'car');
      expect(storage.loadVehicles().single.id, 'car');
      expect(state.hasSeenOnboarding, isTrue);
      expect(await File('${vault.path}/receipt.jpg').exists(), isTrue);
    });

    test('confirmed remote success clears local records and onboarding',
        () async {
      auth.succeeds = true;
      await state.deleteAccount();
      expect(state.isAuthenticated, isFalse);
      expect(state.vehicles, isEmpty);
      expect(storage.loadVehicles(), isEmpty);
      expect(state.hasSeenOnboarding, isFalse);
      expect(await File('${vault.path}/receipt.jpg').exists(), isFalse);
    });

    testWidgets('failed deletion explains retry and keeps account controls',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Builder(
        builder: (context) => TextButton(
            onPressed: () => AccountSettingsSheet.show(context, state),
            child: const Text('Settings')),
      ))));
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsNothing);
      expect(find.text('Account & sync'), findsOneWidget);
      await tester.tap(find.text('Account & sync'));
      await tester.pumpAndSettle();
      expect(find.text('Sync now'), findsOneWidget);
      expect(find.text('Continue with Apple'), findsNothing);
      expect(find.text('Export backup file'), findsNothing);
      await tester.tap(find.byTooltip('Back to Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage data'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Delete Account & All Data'));
      await tester.tap(find.text('Delete Account & All Data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();
      expect(
          find.text(
              'Could not delete your account. Your local records are kept. Please try again.'),
          findsOneWidget);
      expect(state.isAuthenticated, isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}
