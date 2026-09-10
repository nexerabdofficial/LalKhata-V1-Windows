import 'package:supabase_flutter/supabase_flutter.dart';

class LicenseAdminService {
  LicenseAdminService._();

  static final LicenseAdminService instance = LicenseAdminService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  // ==========================================================
  // LOGIN
  // ==========================================================

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final user = response.user;

      if (user == null) {
        return 'LOGIN_FAILED';
      }

      // ------------------------------------------------------
      // Verify that this user is actually a NexEra admin.
      // ------------------------------------------------------

      final isAdmin = await _checkAdmin();

      if (!isAdmin) {
        await _supabase.auth.signOut();

        return 'ACCESS_DENIED';
      }

      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Unable to login. Please try again.';
    }
  }

  // ==========================================================
  // ADMIN CHECK
  // ==========================================================

  Future<bool> _checkAdmin() async {
    try {
      final response = await _supabase.rpc('is_license_admin');

      return response == true;
    } catch (_) {
      return false;
    }
  }

  // ==========================================================
  // CURRENT USER
  // ==========================================================

  User? get currentUser => _supabase.auth.currentUser;

  // ==========================================================
  // LOGOUT
  // ==========================================================

  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  // ==========================================================
  // CREATE SOFTWARE CUSTOMER
  // ==========================================================

  Future<Map<String, dynamic>> createCustomer({
    required String customerCode,
    required String businessName,
    String? phone,
    String? address,
    required String duration,
    required int maxDevices,
  }) async {
    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        return {
          'success': false,
          'code': 'NOT_AUTHENTICATED',
          'message': 'Admin login session not found.',
        };
      }

      // ==========================================================
      // DEBUG - CHECK SUPABASE AUTH SESSION
      // ==========================================================

      final session = _supabase.auth.currentSession;

      print('================ LICENSE ADMIN DEBUG ================');
      print('User ID: ${session?.user.id}');
      print('Email: ${session?.user.email}');
      print('Role: ${session?.user.role}');
      print('Access Token Exists: ${session?.accessToken.isNotEmpty}');
      print('======================================================');

      // ==========================================================
      // CREATE CUSTOMER
      // ==========================================================

      final response = await _supabase.rpc(
        'create_customer_with_license',
        params: {
          'p_customer_code': customerCode.trim(),
          'p_business_name': businessName.trim(),
          'p_phone': phone?.trim(),
          'p_address': address?.trim(),
          'p_duration': duration,
          'p_max_devices': maxDevices,
        },
      );

      print('CREATE CUSTOMER RESPONSE: $response');

      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }

      return {
        'success': false,
        'code': 'INVALID_RESPONSE',
        'message': 'Invalid response from server.',
      };
    } catch (e, stackTrace) {
      print('CREATE CUSTOMER ERROR: $e');
      print('STACK TRACE: $stackTrace');

      return {
        'success': false,
        'code': 'NETWORK_ERROR',
        'message': e.toString(),
      };
    }
  }
}
