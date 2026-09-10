import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../gab/gab_branding.dart';
import '../gab/gab_profile.dart';

// ============================================================
// LICENSE DEVICE
// ============================================================

class LicenseDevice {
  final String deviceId;
  final String platform;
  final String deviceName;
  final String status;
  final DateTime? activatedAt;
  final DateTime? lastVerifiedAt;

  const LicenseDevice({
    required this.deviceId,
    required this.platform,
    required this.deviceName,
    required this.status,
    this.activatedAt,
    this.lastVerifiedAt,
  });

  factory LicenseDevice.fromMap(
    Map<String, dynamic> map,
  ) {
    return LicenseDevice(
      deviceId: map['device_id']?.toString() ?? '',
      platform: map['platform']?.toString() ?? '',
      deviceName: map['device_name']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      activatedAt: _parseDateValue(map['activated_at']),
      lastVerifiedAt: _parseDateValue(map['last_verified_at']),
    );
  }
}

DateTime? _parseDateValue(dynamic value) {
  if (value == null) {
    return null;
  }

  return DateTime.tryParse(
    value.toString(),
  );
}

// ============================================================
// LICENSE RESULT
// ============================================================

class LicenseResult {
  final bool success;
  final String code;
  final String message;

  final String? customerCode;
  final String? businessName;
  final String? phone;
  final String? address;

  final DateTime? activatedAt;
  final DateTime? expiresAt;

  final String? duration;

  final int maxDevices;
  final int usedDevices;

  final List<LicenseDevice> devices;

  const LicenseResult({
    required this.success,
    required this.code,
    required this.message,
    this.customerCode,
    this.businessName,
    this.phone,
    this.address,
    this.activatedAt,
    this.expiresAt,
    this.duration,
    this.maxDevices = 1,
    this.usedDevices = 0,
    this.devices = const [],
  });
}

// ============================================================
// LICENSE SERVICE
// ============================================================

class LicenseService {
  LicenseService._();

  static final LicenseService instance =
      LicenseService._();

  // ==========================================================
  // PROFILE
  // ==========================================================

  static bool get licenseEnabled =>
      GABProfile.licenseEnabled;

  // ==========================================================
  // LOCAL STORAGE KEYS
  // ==========================================================

  static const String _activatedKey =
      'nexera_license_activated';

  static const String _customerCodeKey =
      'nexera_license_customer_code';

  static const String _deviceIdKey =
      'nexera_license_device_id';

  static const String _expiresAtKey =
      'nexera_license_expires_at';

  static const String _activatedAtKey =
      'nexera_license_activated_at';

  static const String _lastVerifiedKey =
      'nexera_license_last_verified';

  static const String _businessNameKey =
      'nexera_license_business_name';

  static const String _phoneKey =
      'nexera_license_phone';

  static const String _addressKey =
      'nexera_license_address';

  static const String _durationKey =
      'nexera_license_duration';

  static const String _maxDevicesKey =
      'nexera_license_max_devices';

  // ==========================================================
  // LAST KNOWN ACTIVE DEVICE COUNT
  // ==========================================================

  static const String _usedDevicesKey =
      'nexera_license_used_devices';

  // ==========================================================
  // SERVER VERIFICATION
  // ==========================================================

  static const int verificationIntervalDays = 7;

  final SupabaseClient _supabase =
      Supabase.instance.client;

  // ==========================================================
  // SAVED CUSTOMER CODE
  // ==========================================================

  static Future<String?> getSavedCustomerCode() async {
    final prefs =
        await SharedPreferences.getInstance();

    final code =
        prefs.getString(
      _customerCodeKey,
    );

    if (code == null ||
        code.trim().isEmpty) {
      return null;
    }

    return code.trim();
  }

  // ==========================================================
  // ACTIVATE
  // ==========================================================

  Future<LicenseResult> activate({
    String? customerCode,
  }) async {
    if (!licenseEnabled) {
      return const LicenseResult(
        success: true,
        code: 'LICENSE_DISABLED',
        message:
            'License validation is disabled.',
      );
    }

    try {
      final code =
          (customerCode ?? '').trim();

      if (code.isEmpty) {
        return const LicenseResult(
          success: false,
          code: 'INVALID_CUSTOMER_CODE',
          message:
              'Customer code is required.',
        );
      }

      final deviceId =
          await _getDeviceId();

      if (deviceId.trim().isEmpty) {
        return const LicenseResult(
          success: false,
          code: 'DEVICE_ID_ERROR',
          message:
              'Unable to identify this device.',
        );
      }

      return await _activateWithServer(
        customerCode: code,
        deviceId: deviceId,
      );
    } catch (e) {
      return const LicenseResult(
        success: false,
        code: 'NETWORK_ERROR',
        message:
            'Unable to connect to the license server.',
      );
    }
  }

  // ==========================================================
  // VALIDATE
  //
  // Local cache is used only when the cached license
  // is still valid.
  //
  // If local license is expired, we MUST contact
  // Supabase again.
  // ==========================================================

  Future<LicenseResult> validate() async {
    if (!licenseEnabled) {
      return const LicenseResult(
        success: true,
        code: 'LICENSE_DISABLED',
        message:
            'License validation is disabled.',
      );
    }

    try {
      final prefs =
          await SharedPreferences.getInstance();

      final deviceId =
          await _getDeviceId();

      if (deviceId.trim().isEmpty) {
        return const LicenseResult(
          success: false,
          code: 'DEVICE_ID_ERROR',
          message:
              'Unable to identify this device.',
        );
      }

      final savedCustomerCode =
          prefs.getString(
        _customerCodeKey,
      );

      // --------------------------------------------------------
      // NO LOCAL LICENSE
      // --------------------------------------------------------

      if (savedCustomerCode == null ||
          savedCustomerCode.trim().isEmpty) {
        return const LicenseResult(
          success: false,
          code: 'LICENSE_NOT_ACTIVATED',
          message:
              'Please enter the customer code provided by NexEra IT BD.',
        );
      }

      final customerCode =
          savedCustomerCode.trim();

      // --------------------------------------------------------
      // FIRST CHECK LOCAL LICENSE
      // --------------------------------------------------------

      final localResult =
          await _validateLocal(
        prefs: prefs,
        deviceId: deviceId,
      );

      // --------------------------------------------------------
      // IMPORTANT:
      //
      // If localResult is ACTIVE,
      // return it normally.
      //
      // But if localResult is EXPIRED,
      // DO NOT return it immediately.
      //
      // We must check Supabase because admin may have
      // extended the expiry date.
      // --------------------------------------------------------

      if (localResult != null) {
        if (localResult.code !=
            'LICENSE_EXPIRED') {
          return localResult;
        }
      }

      // --------------------------------------------------------
      // SERVER VERIFICATION
      // --------------------------------------------------------

      return await _verifyWithServer(
        prefs: prefs,
        customerCode: customerCode,
        deviceId: deviceId,
      );
    } catch (e) {
      return const LicenseResult(
        success: false,
        code: 'NETWORK_ERROR',
        message:
            'Unable to verify the license.',
      );
    }
  }

  // ==========================================================
  // SERVER ACTIVATION
  // ==========================================================

  Future<LicenseResult> _activateWithServer({
    required String customerCode,
    required String deviceId,
  }) async {
    try {
      final response =
          await _supabase.rpc(
        'activate_license',
        params: {
          'p_customer_id': customerCode,
          'p_device_id': deviceId,
        },
      );

      final result =
          _parseResponse(
        response,
        customerCode: customerCode,
      );

      if (!result.success) {
        return result;
      }

      if (result.duration == null ||
          result.duration!.trim().isEmpty) {
        return const LicenseResult(
          success: false,
          code: 'INVALID_DURATION',
          message:
              'License server did not return a valid duration.',
        );
      }

      if (result.duration != 'lifetime' &&
          result.expiresAt == null) {
        return const LicenseResult(
          success: false,
          code: 'INVALID_EXPIRY',
          message:
              'License server did not return a valid expiry date.',
        );
      }

      final prefs =
          await SharedPreferences.getInstance();

      await _saveLicenseLocally(
        prefs: prefs,
        customerCode: customerCode,
        deviceId: deviceId,
        businessName: result.businessName,
        phone: result.phone,
        address: result.address,
        activatedAt: result.activatedAt,
        expiresAt: result.expiresAt,
        duration: result.duration!,
        maxDevices: result.maxDevices,
        usedDevices: result.usedDevices,
      );

      return result;
    } catch (e) {
      return const LicenseResult(
        success: false,
        code: 'NETWORK_ERROR',
        message:
            'Unable to connect to the license server.',
      );
    }
  }

  // ==========================================================
  // SERVER VERIFICATION
  //
  // This ALWAYS calls Supabase.
  // ==========================================================

  Future<LicenseResult> _verifyWithServer({
    required SharedPreferences prefs,
    required String customerCode,
    required String deviceId,
  }) async {
    try {
      final response =
          await _supabase.rpc(
        'activate_license',
        params: {
          'p_customer_id': customerCode,
          'p_device_id': deviceId,
        },
      );

      final result =
          _parseResponse(
        response,
        customerCode: customerCode,
      );

      // --------------------------------------------------------
      // SUCCESS
      // --------------------------------------------------------

      if (result.success) {
        if (result.duration == null ||
            result.duration!.trim().isEmpty) {
          return const LicenseResult(
            success: false,
            code: 'INVALID_DURATION',
            message:
                'License server returned an invalid duration.',
          );
        }

        if (result.duration != 'lifetime' &&
            result.expiresAt == null) {
          return const LicenseResult(
            success: false,
            code: 'INVALID_EXPIRY',
            message:
                'License server returned an invalid expiry.',
          );
        }

        // ------------------------------------------------------
        // SAVE FRESH SERVER DATA
        // ------------------------------------------------------

        await _saveLicenseLocally(
          prefs: prefs,
          customerCode: customerCode,
          deviceId: deviceId,
          businessName: result.businessName,
          phone: result.phone,
          address: result.address,
          activatedAt: result.activatedAt,
          expiresAt: result.expiresAt,
          duration: result.duration!,
          maxDevices: result.maxDevices,
          usedDevices: result.usedDevices,
        );

        return result;
      }

      // --------------------------------------------------------
      // SERVER SAYS LICENSE EXPIRED
      // --------------------------------------------------------
      //
      // IMPORTANT:
      //
      // Server expiry MUST be saved locally.
      //
      // Otherwise an old future local expiry can remain active
      // and the next validate() call will return LOCAL_ACTIVE.
      //
      // Example:
      //
      // OLD LOCAL EXPIRY:
      // 2026-09-10
      //
      // SERVER:
      // LICENSE_EXPIRED
      // expires_at = 2026-09-03
      //
      // We save the server expiry locally.
      // --------------------------------------------------------

      if (result.code == 'LICENSE_EXPIRED') {
        final serverDuration =
            result.duration;

        // ------------------------------------------------------
        // Save server data even though license is expired.
        //
        // This is intentional.
        // We want local cache to know the real server expiry.
        // ------------------------------------------------------

        if (serverDuration != null &&
            serverDuration.trim().isNotEmpty) {
          await _saveLicenseLocally(
            prefs: prefs,
            customerCode: customerCode,
            deviceId: deviceId,
            businessName: result.businessName,
            phone: result.phone,
            address: result.address,
            activatedAt: result.activatedAt,
            expiresAt: result.expiresAt,
            duration: serverDuration,
            maxDevices: result.maxDevices,
            usedDevices: result.usedDevices,
          );
        } else {
          // ----------------------------------------------------
          // Defensive fallback:
          //
          // If server somehow does not return duration,
          // at least save expiry and verification time.
          // ----------------------------------------------------

          if (result.expiresAt != null) {
            await prefs.setString(
              _expiresAtKey,
              result.expiresAt!.toIso8601String(),
            );
          }

          await prefs.setString(
            _lastVerifiedKey,
            DateTime.now().toIso8601String(),
          );
        }

        return result;
      }

      // --------------------------------------------------------
      // OTHER SERVER ERRORS
      // --------------------------------------------------------

      return result;
    } catch (e) {
      // --------------------------------------------------------
      // IMPORTANT:
      //
      // If the license is already expired locally,
      // NEVER allow offline fallback to make it active.
      // --------------------------------------------------------

      final localExpiry =
          prefs.getString(
        _expiresAtKey,
      );

      if (_isLocallyExpired(
        localExpiry,
      )) {
        return LicenseResult(
          success: false,
          code: 'LICENSE_EXPIRED',
          message:
              'Your license has expired. Please connect to the internet and try again.',
          customerCode: customerCode,
          businessName:
              prefs.getString(
            _businessNameKey,
          ),
          phone:
              prefs.getString(
            _phoneKey,
          ),
          address:
              prefs.getString(
            _addressKey,
          ),
          activatedAt: _parseDate(
            prefs.getString(
              _activatedAtKey,
            ),
          ),
          expiresAt: _parseDate(
            localExpiry,
          ),
          duration:
              prefs.getString(
            _durationKey,
          ),
          maxDevices:
              prefs.getInt(
                    _maxDevicesKey,
                  ) ??
                  1,
          usedDevices:
              prefs.getInt(
                    _usedDevicesKey,
                  ) ??
                  1,
        );
      }

      // --------------------------------------------------------
      // NON-EXPIRED LICENSE
      //
      // Offline fallback is allowed.
      // --------------------------------------------------------

      final offline =
          await _offlineValidation(
        prefs: prefs,
        deviceId: deviceId,
      );

      if (offline != null) {
        return offline;
      }

      return const LicenseResult(
        success: false,
        code: 'NETWORK_ERROR',
        message:
            'Unable to connect to the license server.',
      );
    }
  }

  // ==========================================================
  // FORCE SERVER VERIFICATION
  //
  // Used by License & Devices screen / Try Again.
  //
  // NEVER uses local cache.
  // ==========================================================

  Future<LicenseResult> verifyNow() async {
    if (!licenseEnabled) {
      return const LicenseResult(
        success: true,
        code: 'LICENSE_DISABLED',
        message:
            'License validation is disabled.',
      );
    }

    try {
      final prefs =
          await SharedPreferences.getInstance();

      final customerCode =
          prefs.getString(
        _customerCodeKey,
      );

      if (customerCode == null ||
          customerCode.trim().isEmpty) {
        return const LicenseResult(
          success: false,
          code: 'LICENSE_NOT_ACTIVATED',
          message:
              'This installation has not been activated.',
        );
      }

      final deviceId =
          await _getDeviceId();

      if (deviceId.trim().isEmpty) {
        return const LicenseResult(
          success: false,
          code: 'DEVICE_ID_ERROR',
          message:
              'Unable to identify this device.',
        );
      }

      final result =
          await _verifyWithServer(
        prefs: prefs,
        customerCode:
            customerCode.trim(),
        deviceId: deviceId,
      );

      return result;
    } catch (e) {
      return const LicenseResult(
        success: false,
        code: 'NETWORK_ERROR',
        message:
            'Unable to connect to the license server.',
      );
    }
  }

  // ==========================================================
  // RENEW
  // ==========================================================

  Future<LicenseResult> renew(
    String duration,
  ) async {
    return const LicenseResult(
      success: false,
      code: 'RENEWAL_NOT_AVAILABLE',
      message:
          'License renewal must be authorized by NexEra IT BD.',
    );
  }

  // ==========================================================
  // LOCAL VALIDATION
  //
  // Returns local result when possible.
  //
  // IMPORTANT:
  // Expired is returned specifically so validate()
  // can force a server check.
  // ==========================================================

  Future<LicenseResult?> _validateLocal({
    required SharedPreferences prefs,
    required String deviceId,
  }) async {
    final activated =
        prefs.getBool(
              _activatedKey,
            ) ??
            false;

    final savedCustomerCode =
        prefs.getString(
      _customerCodeKey,
    );

    final savedDeviceId =
        prefs.getString(
      _deviceIdKey,
    );

    final expiresAtString =
        prefs.getString(
      _expiresAtKey,
    );

    final activatedAtString =
        prefs.getString(
      _activatedAtKey,
    );

    final businessName =
        prefs.getString(
      _businessNameKey,
    );

    final phone =
        prefs.getString(
      _phoneKey,
    );

    final address =
        prefs.getString(
      _addressKey,
    );

    final duration =
        prefs.getString(
      _durationKey,
    );

    final maxDevices =
        prefs.getInt(
              _maxDevicesKey,
            ) ??
            1;

    final usedDevices =
        prefs.getInt(
              _usedDevicesKey,
            ) ??
            1;

    // --------------------------------------------------------
    // NOT ACTIVATED
    // --------------------------------------------------------

    if (!activated ||
        savedCustomerCode == null ||
        savedCustomerCode.trim().isEmpty ||
        savedDeviceId == null ||
        savedDeviceId.trim().isEmpty) {
      return const LicenseResult(
        success: false,
        code: 'LICENSE_NOT_ACTIVATED',
        message:
            'This installation has not been activated.',
      );
    }

    // --------------------------------------------------------
    // DEVICE MISMATCH
    // --------------------------------------------------------

    if (savedDeviceId != deviceId) {
      return LicenseResult(
        success: false,
        code: 'DEVICE_MISMATCH',
        message:
            'This license is activated on another device.',
        customerCode:
            savedCustomerCode,
        businessName:
            businessName,
        phone: phone,
        address: address,
        activatedAt:
            _parseDate(
          activatedAtString,
        ),
        expiresAt:
            _parseDate(
          expiresAtString,
        ),
        duration: duration,
        maxDevices:
            maxDevices,
        usedDevices:
            usedDevices,
      );
    }

    // --------------------------------------------------------
    // LIFETIME
    // --------------------------------------------------------

    if (duration == 'lifetime' &&
        (expiresAtString == null ||
            expiresAtString.trim().isEmpty)) {
      return LicenseResult(
        success: true,
        code: 'LOCAL_ACTIVE',
        message:
            'Lifetime license is active.',
        customerCode:
            savedCustomerCode,
        businessName:
            businessName,
        phone: phone,
        address: address,
        activatedAt:
            _parseDate(
          activatedAtString,
        ),
        expiresAt: null,
        duration: 'lifetime',
        maxDevices:
            maxDevices,
        usedDevices:
            usedDevices,
      );
    }

    // --------------------------------------------------------
    // NO EXPIRY DATE
    //
    // Keep compatibility with older lifetime records.
    // --------------------------------------------------------

    if (expiresAtString == null ||
        expiresAtString.trim().isEmpty) {
      return LicenseResult(
        success: true,
        code: 'LOCAL_ACTIVE',
        message:
            'Lifetime license is active.',
        customerCode:
            savedCustomerCode,
        businessName:
            businessName,
        phone: phone,
        address: address,
        activatedAt:
            _parseDate(
          activatedAtString,
        ),
        expiresAt: null,
        duration:
            duration ?? 'lifetime',
        maxDevices:
            maxDevices,
        usedDevices:
            usedDevices,
      );
    }

    final expiresAt =
        DateTime.tryParse(
      expiresAtString,
    );

    // Invalid expiry means local cache cannot be trusted.
    if (expiresAt == null) {
      return null;
    }

    // --------------------------------------------------------
    // EXPIRED
    //
    // DO NOT treat this as final.
    //
    // validate() will force server verification.
    // --------------------------------------------------------

    if (!DateTime.now().isBefore(
      expiresAt,
    )) {
      return LicenseResult(
        success: false,
        code: 'LICENSE_EXPIRED',
        message:
            'Your license has expired. Checking server for updated license...',
        customerCode:
            savedCustomerCode,
        businessName:
            businessName,
        phone: phone,
        address: address,
        activatedAt:
            _parseDate(
          activatedAtString,
        ),
        expiresAt:
            expiresAt,
        duration:
            duration,
        maxDevices:
            maxDevices,
        usedDevices:
            usedDevices,
      );
    }

    // --------------------------------------------------------
    // SERVER VERIFICATION INTERVAL
    // --------------------------------------------------------

    final lastVerifiedString =
        prefs.getString(
      _lastVerifiedKey,
    );

    if (lastVerifiedString == null ||
        lastVerifiedString.trim().isEmpty) {
      return LicenseResult(
        success: true,
        code: 'LOCAL_ACTIVE',
        message:
            'License is active.',
        customerCode:
            savedCustomerCode,
        businessName:
            businessName,
        phone: phone,
        address: address,
        activatedAt:
            _parseDate(
          activatedAtString,
        ),
        expiresAt:
            expiresAt,
        duration:
            duration,
        maxDevices:
            maxDevices,
        usedDevices:
            usedDevices,
      );
    }

    final lastVerified =
        DateTime.tryParse(
      lastVerifiedString,
    );

    if (lastVerified == null) {
      return LicenseResult(
        success: true,
        code: 'LOCAL_ACTIVE',
        message:
            'License is active.',
        customerCode:
            savedCustomerCode,
        businessName:
            businessName,
        phone: phone,
        address: address,
        activatedAt:
            _parseDate(
          activatedAtString,
        ),
        expiresAt:
            expiresAt,
        duration:
            duration,
        maxDevices:
            maxDevices,
        usedDevices:
            usedDevices,
      );
    }

    final verificationDue =
        DateTime.now().isAfter(
      lastVerified.add(
        const Duration(
          days:
              verificationIntervalDays,
        ),
      ),
    );

    if (!verificationDue) {
      return LicenseResult(
        success: true,
        code: 'LOCAL_ACTIVE',
        message:
            'License is active.',
        customerCode:
            savedCustomerCode,
        businessName:
            businessName,
        phone: phone,
        address: address,
        activatedAt:
            _parseDate(
          activatedAtString,
        ),
        expiresAt:
            expiresAt,
        duration:
            duration,
        maxDevices:
            maxDevices,
        usedDevices:
            usedDevices,
      );
    }

    // Server verification required.
    return null;
  }

  // ==========================================================
  // OFFLINE VALIDATION
  // ==========================================================

  Future<LicenseResult?> _offlineValidation({
    required SharedPreferences prefs,
    required String deviceId,
  }) async {
    final activated =
        prefs.getBool(
              _activatedKey,
            ) ??
            false;

    final customerCode =
        prefs.getString(
      _customerCodeKey,
    );

    final savedDeviceId =
        prefs.getString(
      _deviceIdKey,
    );

    final expiresAtString =
        prefs.getString(
      _expiresAtKey,
    );

    final activatedAtString =
        prefs.getString(
      _activatedAtKey,
    );

    final businessName =
        prefs.getString(
      _businessNameKey,
    );

    final phone =
        prefs.getString(
      _phoneKey,
    );

    final address =
        prefs.getString(
      _addressKey,
    );

    final duration =
        prefs.getString(
      _durationKey,
    );

    final maxDevices =
        prefs.getInt(
              _maxDevicesKey,
            ) ??
            1;

    final usedDevices =
        prefs.getInt(
              _usedDevicesKey,
            ) ??
            1;

    if (!activated ||
        customerCode == null ||
        customerCode.trim().isEmpty ||
        savedDeviceId == null ||
        savedDeviceId.trim().isEmpty) {
      return null;
    }

    // --------------------------------------------------------
    // DEVICE
    // --------------------------------------------------------

    if (savedDeviceId != deviceId) {
      return LicenseResult(
        success: false,
        code: 'DEVICE_MISMATCH',
        message:
            'This license is activated on another device.',
        customerCode:
            customerCode,
        businessName:
            businessName,
        phone: phone,
        address: address,
        activatedAt:
            _parseDate(
          activatedAtString,
        ),
        expiresAt:
            _parseDate(
          expiresAtString,
        ),
        duration:
            duration,
        maxDevices:
            maxDevices,
        usedDevices:
            usedDevices,
      );
    }

    // --------------------------------------------------------
    // LIFETIME
    // --------------------------------------------------------

    if (expiresAtString == null ||
        expiresAtString.trim().isEmpty) {
      return LicenseResult(
        success: true,
        code: 'OFFLINE_ACTIVE',
        message:
            'Lifetime license verified locally.',
        customerCode:
            customerCode,
        businessName:
            businessName,
        phone: phone,
        address: address,
        activatedAt:
            _parseDate(
          activatedAtString,
        ),
        expiresAt: null,
        duration:
            duration ?? 'lifetime',
        maxDevices:
            maxDevices,
        usedDevices:
            usedDevices,
      );
    }

    final expiresAt =
        DateTime.tryParse(
      expiresAtString,
    );

    if (expiresAt == null) {
      return null;
    }

    // --------------------------------------------------------
    // EXPIRED
    //
    // Never allow expired license offline.
    // --------------------------------------------------------

    if (!DateTime.now().isBefore(
      expiresAt,
    )) {
      return LicenseResult(
        success: false,
        code: 'LICENSE_EXPIRED',
        message:
            'Your license has expired. Please connect to the internet and try again.',
        customerCode:
            customerCode,
        businessName:
            businessName,
        phone: phone,
        address:
            address,
        activatedAt:
            _parseDate(
          activatedAtString,
        ),
        expiresAt:
            expiresAt,
        duration:
            duration,
        maxDevices:
            maxDevices,
        usedDevices:
            usedDevices,
      );
    }

    // --------------------------------------------------------
    // ACTIVE OFFLINE
    // --------------------------------------------------------

    return LicenseResult(
      success: true,
      code: 'OFFLINE_ACTIVE',
      message:
          'License verified locally.',
      customerCode:
          customerCode,
      businessName:
          businessName,
      phone: phone,
      address:
          address,
      activatedAt:
          _parseDate(
        activatedAtString,
      ),
      expiresAt:
          expiresAt,
      duration:
          duration,
      maxDevices:
          maxDevices,
      usedDevices:
          usedDevices,
    );
  }

  // ==========================================================
  // SAVE LOCAL LICENSE
  // ==========================================================

  Future<void> _saveLicenseLocally({
    required SharedPreferences prefs,
    required String customerCode,
    required String deviceId,
    required String? businessName,
    required String? phone,
    required String? address,
    required DateTime? activatedAt,
    required DateTime? expiresAt,
    required String duration,
    required int maxDevices,
    required int usedDevices,
  }) async {
    await prefs.setBool(
      _activatedKey,
      true,
    );

    await prefs.setString(
      _customerCodeKey,
      customerCode,
    );

    await prefs.setString(
      _deviceIdKey,
      deviceId,
    );

    await prefs.setString(
      _lastVerifiedKey,
      DateTime.now().toIso8601String(),
    );

    await prefs.setString(
      _durationKey,
      duration,
    );

    await prefs.setInt(
      _maxDevicesKey,
      maxDevices,
    );

    await prefs.setInt(
      _usedDevicesKey,
      usedDevices,
    );

    // --------------------------------------------------------
    // ACTIVATED AT
    // --------------------------------------------------------

    if (activatedAt != null) {
      await prefs.setString(
        _activatedAtKey,
        activatedAt.toIso8601String(),
      );
    } else {
      await prefs.remove(
        _activatedAtKey,
      );
    }

    // --------------------------------------------------------
    // EXPIRES AT
    // --------------------------------------------------------

    if (expiresAt != null) {
      await prefs.setString(
        _expiresAtKey,
        expiresAt.toIso8601String(),
      );
    } else {
      await prefs.remove(
        _expiresAtKey,
      );
    }

    // --------------------------------------------------------
    // BUSINESS NAME
    // --------------------------------------------------------

    if (businessName != null &&
        businessName.trim().isNotEmpty) {
      await prefs.setString(
        _businessNameKey,
        businessName.trim(),
      );
    } else {
      await prefs.remove(
        _businessNameKey,
      );
    }

    // --------------------------------------------------------
    // PHONE
    // --------------------------------------------------------

    if (phone != null &&
        phone.trim().isNotEmpty) {
      await prefs.setString(
        _phoneKey,
        phone.trim(),
      );
    } else {
      await prefs.remove(
        _phoneKey,
      );
    }

    // --------------------------------------------------------
    // ADDRESS
    // --------------------------------------------------------

    if (address != null &&
        address.trim().isNotEmpty) {
      await prefs.setString(
        _addressKey,
        address.trim(),
      );
    } else {
      await prefs.remove(
        _addressKey,
      );
    }

    // --------------------------------------------------------
    // UPDATE GAB BRANDING CACHE
    // --------------------------------------------------------

    GABBranding.updateCache(
      businessName: businessName,
      phone: phone,
      address: address,
    );
  }

  // ==========================================================
  // DEACTIVATE LOCAL LICENSE
  // ==========================================================

  Future<void> deactivate() async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.remove(
      _activatedKey,
    );

    await prefs.remove(
      _customerCodeKey,
    );

    await prefs.remove(
      _deviceIdKey,
    );

    await prefs.remove(
      _expiresAtKey,
    );

    await prefs.remove(
      _activatedAtKey,
    );

    await prefs.remove(
      _lastVerifiedKey,
    );

    await prefs.remove(
      _businessNameKey,
    );

    await prefs.remove(
      _phoneKey,
    );

    await prefs.remove(
      _addressKey,
    );

    await prefs.remove(
      _durationKey,
    );

    await prefs.remove(
      _maxDevicesKey,
    );

    await prefs.remove(
      _usedDevicesKey,
    );

    // --------------------------------------------------------
    // CLEAR BRANDING CACHE
    // --------------------------------------------------------

    GABBranding.clearCache();
  }

  // ==========================================================
  // TESTING ONLY
  // ==========================================================

  Future<void> clearLocalLicenseForTesting() async {
    await deactivate();
  }

  // ==========================================================
  // RESPONSE PARSER
  // ==========================================================

  LicenseResult _parseResponse(
    dynamic response, {
    String? customerCode,
  }) {
    if (response is! Map) {
      return const LicenseResult(
        success: false,
        code: 'INVALID_RESPONSE',
        message:
            'Invalid response from license server.',
      );
    }

    final success =
        response['success'] == true;

    final code =
        response['code']?.toString() ??
            'UNKNOWN';

    final message =
        response['message']?.toString() ??
            'Unknown license response.';

    final businessName =
        response['business_name']
            ?.toString();

    final phone =
        response['phone']
            ?.toString();

    final address =
        response['address']
            ?.toString();

    final duration =
        response['duration']
            ?.toString();

    final activatedAt =
        _parseDate(
      response['activated_at'],
    );

    final expiresAt =
        _parseDate(
      response['expires_at'],
    );

    final maxDevices =
        (response['max_devices']
                    as num?)
                ?.toInt() ??
            1;

    final usedDevices =
        (response['active_devices']
                    as num?)
                ?.toInt() ??
            0;

    final devicesRaw =
        response['devices'];

    final List<LicenseDevice>
        devices = [];

    if (devicesRaw is List) {
      for (final item
          in devicesRaw) {
        if (item is Map) {
          devices.add(
            LicenseDevice.fromMap(
              Map<String, dynamic>.from(
                item,
              ),
            ),
          );
        }
      }
    }

    return LicenseResult(
      success: success,
      code: code,
      message: message,
      customerCode:
          customerCode,
      businessName:
          businessName,
      phone:
          phone,
      address:
          address,
      activatedAt:
          activatedAt,
      expiresAt:
          expiresAt,
      duration:
          duration,
      maxDevices:
          maxDevices,
      usedDevices:
          usedDevices,
      devices:
          devices,
    );
  }

  // ==========================================================
  // DATE
  // ==========================================================

  DateTime? _parseDate(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(
      value.toString(),
    );
  }

  // ==========================================================
  // LOCAL EXPIRY CHECK
  // ==========================================================

  bool _isLocallyExpired(
    String? expiresAtString,
  ) {
    if (expiresAtString == null ||
        expiresAtString.trim().isEmpty) {
      return false;
    }

    final expiresAt =
        DateTime.tryParse(
      expiresAtString,
    );

    if (expiresAt == null) {
      return false;
    }

    return !DateTime.now().isBefore(
      expiresAt,
    );
  }

  // ==========================================================
  // DEVICE ID
  // ==========================================================

  Future<String> _getDeviceId() async {
    final deviceInfo =
        DeviceInfoPlugin();

    // --------------------------------------------------------
    // WEB
    // --------------------------------------------------------

    if (kIsWeb) {
      final info =
          await deviceInfo.webBrowserInfo;

      return _buildStableId([
        'web',
        info.userAgent,
        info.platform,
        info.hardwareConcurrency?.toString(),
      ]);
    }

    // --------------------------------------------------------
    // LINUX
    // --------------------------------------------------------

    if (Platform.isLinux) {
      final info =
          await deviceInfo.linuxInfo;

      return _buildStableId([
        'linux',
        info.machineId,
      ]);
    }

    // --------------------------------------------------------
    // WINDOWS
    // --------------------------------------------------------

    if (Platform.isWindows) {
      final info =
          await deviceInfo.windowsInfo;

      return _buildStableId([
        'windows',
        info.deviceId,
      ]);
    }

    // --------------------------------------------------------
    // MACOS
    // --------------------------------------------------------

    if (Platform.isMacOS) {
      final info =
          await deviceInfo.macOsInfo;

      return _buildStableId([
        'macos',
        info.systemGUID,
      ]);
    }

    // --------------------------------------------------------
    // ANDROID
    // --------------------------------------------------------

    if (Platform.isAndroid) {
      final info =
          await deviceInfo.androidInfo;

      return _buildStableId([
        'android',
        info.id,
        info.model,
      ]);
    }

    // --------------------------------------------------------
    // IOS
    // --------------------------------------------------------

    if (Platform.isIOS) {
      final info =
          await deviceInfo.iosInfo;

      return _buildStableId([
        'ios',
        info.identifierForVendor,
        info.model,
      ]);
    }

    return '';
  }

  // ==========================================================
  // STABLE DEVICE ID
  // ==========================================================

  String _buildStableId(
    List<String?> parts,
  ) {
    final cleaned =
        parts
            .where(
              (value) =>
                  value != null &&
                  value.trim().isNotEmpty,
            )
            .map(
              (value) =>
                  value!.trim(),
            )
            .toList();

    return cleaned.join('|');
  }
}