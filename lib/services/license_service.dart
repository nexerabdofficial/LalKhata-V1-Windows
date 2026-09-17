import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../gab/gab_branding.dart';
import '../gab/gab_profile.dart';
import '../database/database_helper.dart';

// ============================================================
// LICENSE DEVICE
// ============================================================

class LicenseDevice {
  final String deviceId;
  final String platform;
  final String deviceName;
  final DateTime registeredAt;
  final bool isCurrentDevice;

  // Backward compatibility
  final String status;
  final DateTime? lastVerifiedAt;

  const LicenseDevice({
    required this.deviceId,
    required this.platform,
    required this.deviceName,
    required this.registeredAt,
    required this.isCurrentDevice,
    this.status = '',
    this.lastVerifiedAt,
  });

  factory LicenseDevice.fromMap(
    Map<String, dynamic> map, {
    String? currentDeviceId,
  }) {
    final deviceId = map['device_id']?.toString() ?? '';

    final registeredAt =
        _parseDateTime(map['registered_at']) ??
        DateTime.fromMillisecondsSinceEpoch(0);

    final lastVerifiedAt = _parseDateTime(map['last_verified_at']);

    return LicenseDevice(
      deviceId: deviceId,
      platform: map['platform']?.toString() ?? '',
      deviceName: map['device_name']?.toString() ?? '',
      registeredAt: registeredAt,
      isCurrentDevice: currentDeviceId != null && deviceId == currentDeviceId,
      status: map['status']?.toString() ?? '',
      lastVerifiedAt: lastVerifiedAt,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }
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

  // Customer business information
  final String? email;
  final String? tagline;

  final DateTime? activatedAt;
  final DateTime? expiresAt;
  final String? duration;

  final int? maxDevices;
  final int? usedDevices;

  final List<LicenseDevice> devices;

  const LicenseResult({
    required this.success,
    required this.code,
    required this.message,
    this.customerCode,
    this.businessName,
    this.phone,
    this.address,
    this.email,
    this.tagline,
    this.activatedAt,
    this.expiresAt,
    this.duration,
    this.maxDevices,
    this.usedDevices,
    this.devices = const [],
  });
}

// ============================================================
// LICENSE SERVICE
// ============================================================

class LicenseService {
  LicenseService._();

  static final LicenseService instance = LicenseService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================
  // LOCAL KEYS
  // ============================================================

  static const String _customerCodeKey = 'nexera_license_customer_code';

  static const String _businessNameKey = 'nexera_license_business_name';

  static const String _phoneKey = 'nexera_license_phone';

  static const String _addressKey = 'nexera_license_address';

  static const String _emailKey = 'nexera_license_email';

  static const String _taglineKey = 'nexera_license_tagline';

  static const String _activatedAtKey = 'nexera_license_activated_at';

  static const String _expiresAtKey = 'nexera_license_expires_at';

  static const String _durationKey = 'nexera_license_duration';

  static const String _maxDevicesKey = 'nexera_license_max_devices';

  static const String _usedDevicesKey = 'nexera_license_used_devices';

  static const String _devicesKey = 'nexera_license_devices';

  static const String _lastVerifiedAtKey = 'nexera_license_last_verified_at';

  // ============================================================
  // CUSTOMER LOGO CACHE
  // ============================================================

  static const String _customerLogoPathKey =
      'nexera_license_customer_logo_path';

  static const String _customerLogoFileName = 'customer_logo';

  // ============================================================
  // DEVICE ID
  // ============================================================

  Future<String> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();

    try {
      if (Platform.isLinux) {
        final info = await deviceInfo.linuxInfo;

        final machineId = info.machineId ?? '';

        if (machineId.trim().isNotEmpty) {
          return 'linux|${machineId.trim()}';
        }
      }

      if (Platform.isWindows) {
        final info = await deviceInfo.windowsInfo;

        final deviceId = info.deviceId.trim();

        if (deviceId.isNotEmpty) {
          return 'windows|$deviceId';
        }
      }

      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;

        final deviceId = info.id.trim();

        if (deviceId.isNotEmpty) {
          return 'android|$deviceId';
        }
      }

      if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;

        final deviceId = (info.identifierForVendor ?? '').trim();

        if (deviceId.isNotEmpty) {
          return 'ios|$deviceId';
        }
      }

      if (Platform.isMacOS) {
        final info = await deviceInfo.macOsInfo;

        final deviceId = (info.systemGUID ?? '').trim();

        if (deviceId.isNotEmpty) {
          return 'macos|$deviceId';
        }
      }
    } catch (e) {
      debugPrint('Device ID error: $e');
    }

    return '';
  }

  // ============================================================
  // VALIDATE
  // ============================================================

  Future<LicenseResult> validate() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final customerCode = prefs.getString(_customerCodeKey);

      if (customerCode == null || customerCode.trim().isEmpty) {
        return const LicenseResult(
          success: false,
          code: 'NOT_ACTIVATED',
          message: 'License is not activated.',
        );
      }

      // ========================================================
      // SERVER-FIRST VALIDATION
      //
      // Always verify the currently saved license with Supabase.
      // This allows admin-side expiry/license changes to take
      // effect immediately instead of waiting 7 days.
      //
      // If the server is temporarily unavailable,
      // _verifyWithServer() safely falls back to local validation.
      // ========================================================

      return await _verifyWithServer();
    } catch (e) {
      return LicenseResult(
        success: false,
        code: 'LICENSE_VERIFICATION_FAILED',
        message: e.toString(),
      );
    }
  }

  // ============================================================
  // VERIFY NOW
  // ============================================================

  Future<LicenseResult> verifyNow() async {
    return await _verifyWithServer();
  }

  // ============================================================
  // ACTIVATE
  // ============================================================

  Future<LicenseResult> activate({required String customerCode}) async {
    final code = customerCode.trim();

    if (code.isEmpty) {
      return const LicenseResult(
        success: false,
        code: 'INVALID_CUSTOMER_CODE',
        message: 'Customer code is required.',
      );
    }

    return _activateWithServer(code);
  }

  // ============================================================
  // SERVER ACTIVATION
  // ============================================================

  Future<LicenseResult> _activateWithServer(String customerCode) async {
    try {
      final deviceId = await _getDeviceId();

      final response = await _supabase.rpc(
        'activate_license',
        params: {'p_customer_id': customerCode, 'p_device_id': deviceId},
      );

      final result = _parseResponse(response, currentDeviceId: deviceId);

      if (!result.success) {
        return result;
      }

      // ========================================================
      // SWITCH TO THE NEW LICENSE DATABASE FIRST
      //
      // Each customer/license has its own database.
      // Never delete/reset the database here because the same
      // device may legitimately be used for multiple companies.
      // ========================================================

      await DatabaseHelper.instance.switchToLicense(customerCode);

      // ========================================================
      // CLEAR PREVIOUS CUSTOMER LICENSE CACHE
      //
      // Database files are kept separately. Only the currently
      // active license information and branding cache are replaced.
      // ========================================================

      await _clearLocalLicenseCache();

      // ========================================================
      // SAVE NEW CUSTOMER LICENSE
      // ========================================================

      await _saveLicenseLocally(result, customerCode);

      // ========================================================
      // CUSTOMER LOGO
      // ========================================================

      await _refreshCustomerLogo(customerCode);

      return result;
    } catch (e) {
      return LicenseResult(
        success: false,
        code: 'ACTIVATION_ERROR',
        message: e.toString(),
      );
    }
  }

  // ============================================================
  // SERVER VERIFICATION
  // ============================================================

  Future<LicenseResult> _verifyWithServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final customerCode = prefs.getString(_customerCodeKey);

      if (customerCode == null || customerCode.trim().isEmpty) {
        return const LicenseResult(
          success: false,
          code: 'NOT_ACTIVATED',
          message: 'License is not activated.',
        );
      }

      final deviceId = await _getDeviceId();

      final response = await _supabase.rpc(
        'activate_license',
        params: {'p_customer_id': customerCode.trim(), 'p_device_id': deviceId},
      );

      final result = _parseResponse(response, currentDeviceId: deviceId);

      if (!result.success) {
        return result;
      }

      // ========================================================
      // SWITCH TO THE VERIFIED LICENSE DATABASE
      // ========================================================

      await DatabaseHelper.instance.switchToLicense(customerCode.trim());

      // ========================================================
      // REPLACE PREVIOUS CUSTOMER LICENSE CACHE
      // ========================================================

      await _clearLocalLicenseCache();

      // ========================================================
      // SAVE VERIFIED LICENSE LOCALLY
      // ========================================================

      await _saveLicenseLocally(result, customerCode.trim());

      // ========================================================
      // CUSTOMER LOGO
      // ========================================================

      await _refreshCustomerLogo(customerCode.trim());

      return result;
    } catch (e) {
      debugPrint('Server license verification failed: $e');

      final prefs = await SharedPreferences.getInstance();

      return _offlineValidation(prefs);
    }
  }

  // ============================================================
  // PARSE SERVER RESPONSE
  // ============================================================

  LicenseResult _parseResponse(dynamic response, {String? currentDeviceId}) {
    try {
      if (response == null) {
        return const LicenseResult(
          success: false,
          code: 'LICENSE_NOT_FOUND',
          message: 'No license response received.',
        );
      }

      Map<String, dynamic> map;

      if (response is Map<String, dynamic>) {
        map = response;
      } else if (response is Map) {
        map = Map<String, dynamic>.from(response);
      } else if (response is String) {
        final decoded = jsonDecode(response);

        map = Map<String, dynamic>.from(decoded as Map);
      } else {
        return const LicenseResult(
          success: false,
          code: 'INVALID_LICENSE_RESPONSE',
          message: 'Invalid license response.',
        );
      }

      final success = map['success'] == true;

      final code =
          map['code']?.toString() ??
          (success ? 'LICENSE_ACTIVE' : 'LICENSE_NOT_FOUND');

      final message =
          map['message']?.toString() ??
          (success ? 'License is active.' : 'License verification failed.');

      final rawDevices = map['devices'];

      final devices = <LicenseDevice>[];

      if (rawDevices is List) {
        for (final item in rawDevices) {
          if (item is Map) {
            devices.add(
              LicenseDevice.fromMap(
                Map<String, dynamic>.from(item),
                currentDeviceId: currentDeviceId,
              ),
            );
          }
        }
      }

      return LicenseResult(
        success: success,
        code: code,
        message: message,
        customerCode: map['customer_code']?.toString(),
        businessName: map['business_name']?.toString(),
        phone: map['phone']?.toString(),
        address: map['address']?.toString(),

        // ======================================================
        // CUSTOMER BUSINESS INFORMATION
        // ======================================================
        email: map['email']?.toString(),
        tagline: map['tagline']?.toString(),

        activatedAt: _parseDateTime(map['activated_at']),
        expiresAt: _parseDateTime(map['expires_at']),
        duration: map['duration']?.toString(),
        maxDevices: _toInt(map['max_devices']),
        usedDevices: _toInt(map['used_devices']),
        devices: devices,
      );
    } catch (e) {
      return LicenseResult(
        success: false,
        code: 'INVALID_LICENSE_RESPONSE',
        message: e.toString(),
      );
    }
  }

  // ============================================================
  // CLEAR LOCAL LICENSE CACHE
  //
  // IMPORTANT:
  // This clears only license/customer metadata.
  // License-specific database files are NEVER deleted.
  //
  // This allows one device to handle multiple companies:
  //
  // Company A -> A database
  // Company B -> B database
  // Company A -> A database again
  // ============================================================

  Future<void> _clearLocalLicenseCache() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_customerCodeKey);
    await prefs.remove(_businessNameKey);
    await prefs.remove(_phoneKey);
    await prefs.remove(_addressKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_taglineKey);
    await prefs.remove(_activatedAtKey);
    await prefs.remove(_expiresAtKey);
    await prefs.remove(_durationKey);
    await prefs.remove(_maxDevicesKey);
    await prefs.remove(_usedDevicesKey);
    await prefs.remove(_devicesKey);
    await prefs.remove(_lastVerifiedAtKey);

    await _clearCustomerLogoCache();

    GABBranding.clearCache();
  }

  // ============================================================
  // SAVE LOCAL LICENSE
  // ============================================================

  Future<void> _saveLicenseLocally(
    LicenseResult result,
    String customerCode,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_customerCodeKey, customerCode.trim());

    if (result.businessName != null) {
      await prefs.setString(_businessNameKey, result.businessName!);
    }

    if (result.phone != null) {
      await prefs.setString(_phoneKey, result.phone!);
    }

    if (result.address != null) {
      await prefs.setString(_addressKey, result.address!);
    }

    // ==========================================================
    // EMAIL
    // ==========================================================

    if (result.email != null) {
      final email = result.email!.trim();

      if (email.isNotEmpty) {
        await prefs.setString(_emailKey, email);
      } else {
        await prefs.remove(_emailKey);
      }
    }

    // ==========================================================
    // TAGLINE
    // ==========================================================

    if (result.tagline != null) {
      final tagline = result.tagline!.trim();

      if (tagline.isNotEmpty) {
        await prefs.setString(_taglineKey, tagline);
      } else {
        await prefs.remove(_taglineKey);
      }
    }

    if (result.activatedAt != null) {
      await prefs.setString(
        _activatedAtKey,
        result.activatedAt!.toIso8601String(),
      );
    }

    if (result.expiresAt != null) {
      await prefs.setString(_expiresAtKey, result.expiresAt!.toIso8601String());
    }

    if (result.duration != null) {
      await prefs.setString(_durationKey, result.duration!);
    }

    if (result.maxDevices != null) {
      await prefs.setInt(_maxDevicesKey, result.maxDevices!);
    }

    if (result.usedDevices != null) {
      await prefs.setInt(_usedDevicesKey, result.usedDevices!);
    }

    final devicesJson = result.devices
        .map(
          (device) => {
            'device_id': device.deviceId,
            'platform': device.platform,
            'device_name': device.deviceName,
            'registered_at': device.registeredAt.toIso8601String(),
            'status': device.status,
            'last_verified_at': device.lastVerifiedAt?.toIso8601String(),
          },
        )
        .toList();

    await prefs.setString(_devicesKey, jsonEncode(devicesJson));

    await prefs.setString(_lastVerifiedAtKey, DateTime.now().toIso8601String());

    // ==========================================================
    // UPDATE GAB BRANDING CACHE
    // ==========================================================

    GABBranding.updateCache(
      businessName: result.businessName,
      phone: result.phone,
      address: result.address,
      email: result.email,
      tagline: result.tagline,
    );
  }

  // ============================================================
  // OFFLINE VALIDATION
  // ============================================================

  LicenseResult _offlineValidation(SharedPreferences prefs) {
    final customerCode = prefs.getString(_customerCodeKey);

    if (customerCode == null || customerCode.trim().isEmpty) {
      return const LicenseResult(
        success: false,
        code: 'NOT_ACTIVATED',
        message: 'License is not activated.',
      );
    }

    final expiresAtString = prefs.getString(_expiresAtKey);

    final expiresAt = _parseDateTime(expiresAtString);

    if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
      return LicenseResult(
        success: false,
        code: 'LICENSE_EXPIRED',
        message: 'License has expired.',
        customerCode: customerCode,
        businessName: prefs.getString(_businessNameKey),
        phone: prefs.getString(_phoneKey),
        address: prefs.getString(_addressKey),
        email: prefs.getString(_emailKey),
        tagline: prefs.getString(_taglineKey),
        activatedAt: _parseDateTime(prefs.getString(_activatedAtKey)),
        expiresAt: expiresAt,
        duration: prefs.getString(_durationKey),
        maxDevices: prefs.getInt(_maxDevicesKey),
        usedDevices: prefs.getInt(_usedDevicesKey),
        devices: _loadLocalDevices(prefs),
      );
    }

    return LicenseResult(
      success: true,
      code: 'LICENSE_ACTIVE',
      message: 'License is active.',
      customerCode: customerCode,
      businessName: prefs.getString(_businessNameKey),
      phone: prefs.getString(_phoneKey),
      address: prefs.getString(_addressKey),
      email: prefs.getString(_emailKey),
      tagline: prefs.getString(_taglineKey),
      activatedAt: _parseDateTime(prefs.getString(_activatedAtKey)),
      expiresAt: expiresAt,
      duration: prefs.getString(_durationKey),
      maxDevices: prefs.getInt(_maxDevicesKey),
      usedDevices: prefs.getInt(_usedDevicesKey),
      devices: _loadLocalDevices(prefs),
    );
  }

  // ============================================================
  // LOAD LOCAL DEVICES
  // ============================================================

  List<LicenseDevice> _loadLocalDevices(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_devicesKey);

      if (raw == null || raw.trim().isEmpty) {
        return [];
      }

      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        return [];
      }

      return decoded
          .whereType<Map>()
          .map((item) => LicenseDevice.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ============================================================
  // CUSTOMER LOGO PATH
  // ============================================================

  static Future<String?> getCustomerLogoPath() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final path = prefs.getString(_customerLogoPathKey);

      if (path == null || path.trim().isEmpty) {
        return null;
      }

      final file = File(path);

      if (!await file.exists()) {
        await prefs.remove(_customerLogoPathKey);

        return null;
      }

      return path;
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // REFRESH CUSTOMER LOGO
  // ============================================================

  Future<void> _refreshCustomerLogo(String customerCode) async {
    try {
      final response = await _supabase.rpc(
        'get_customer_logo',
        params: {'p_customer_code': customerCode.trim()},
      );

      if (response == null) {
        await _clearCustomerLogoCache();

        return;
      }

      if (response is! Map) {
        await _clearCustomerLogoCache();

        return;
      }

      final map = Map<String, dynamic>.from(response);

      final success = map['success'] == true;

      if (!success) {
        await _clearCustomerLogoCache();

        return;
      }

      final logoPath = map['logo_path']?.toString().trim();

      if (logoPath == null || logoPath.isEmpty) {
        await _clearCustomerLogoCache();

        return;
      }

      // ========================================================
      // IMPORTANT
      //
      // Clear previous customer's cached logo before downloading
      // the new customer's logo. This prevents one customer's
      // logo from appearing on another customer's invoice.
      // ========================================================

      await _clearCustomerLogoCache();

      await _downloadCustomerLogo(logoPath);
    } catch (e, stackTrace) {
      // Logo failure must NEVER break license activation.

      debugPrint('$stackTrace');
    }
  }

  // ============================================================
  // DOWNLOAD CUSTOMER LOGO
  // ============================================================

  Future<void> _downloadCustomerLogo(String logoPath) async {
    try {
      final publicUrl = _supabase.storage
          .from('customer-logos')
          .getPublicUrl(logoPath);

      final client = HttpClient();

      try {
        final request = await client.getUrl(Uri.parse(publicUrl));

        final response = await request.close();

        if (response.statusCode != 200) {
          debugPrint(
            'Customer logo download failed: '
            '${response.statusCode}',
          );

          return;
        }

        final bytes = await _readResponseBytes(response);

        if (bytes.isEmpty) {
          return;
        }

        final directory = await getApplicationSupportDirectory();

        final extension = _extensionFromPath(logoPath);

        final logoFile = File(
          '${directory.path}/'
          '$_customerLogoFileName'
          '$extension',
        );

        await logoFile.writeAsBytes(bytes, flush: true);

        final exists = await logoFile.exists();

        if (exists) {}

        final prefs = await SharedPreferences.getInstance();

        await prefs.setString(_customerLogoPathKey, logoFile.path);
      } finally {
        client.close(force: true);
      }
    } catch (e, stackTrace) {
      // Logo download failure must never break license.

      debugPrint('$stackTrace');
    }
  }

  // ============================================================
  // READ HTTP RESPONSE
  // ============================================================

  Future<List<int>> _readResponseBytes(HttpClientResponse response) async {
    final builder = BytesBuilder();

    await for (final chunk in response) {
      builder.add(chunk);
    }

    return builder.takeBytes();
  }

  // ============================================================
  // FILE EXTENSION
  // ============================================================

  String _extensionFromPath(String path) {
    final lower = path.toLowerCase();

    if (lower.endsWith('.jpeg')) {
      return '.jpeg';
    }

    if (lower.endsWith('.jpg')) {
      return '.jpg';
    }

    if (lower.endsWith('.webp')) {
      return '.webp';
    }

    return '.png';
  }

  // ============================================================
  // CLEAR CUSTOMER LOGO CACHE
  // ============================================================

  Future<void> _clearCustomerLogoCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final oldPath = prefs.getString(_customerLogoPathKey);

      if (oldPath != null && oldPath.trim().isNotEmpty) {
        final file = File(oldPath);

        if (await file.exists()) {
          await file.delete();
        }
      }

      final directory = await getApplicationSupportDirectory();

      for (final extension in ['.png', '.jpg', '.jpeg', '.webp']) {
        final file = File(
          '${directory.path}/'
          '$_customerLogoFileName'
          '$extension',
        );

        if (await file.exists()) {
          await file.delete();
        }
      }

      await prefs.remove(_customerLogoPathKey);
    } catch (e) {}
  }

  // ============================================================
  // LOGOUT / CHANGE LICENSE
  // ============================================================

  Future<void> logoutLicense() async {
    // Close the currently active license database first.
    // The database file itself is NOT deleted.
    await DatabaseHelper.instance.closeDatabase();

    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_customerCodeKey);
    await prefs.remove(_businessNameKey);
    await prefs.remove(_phoneKey);
    await prefs.remove(_addressKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_taglineKey);
    await prefs.remove(_activatedAtKey);
    await prefs.remove(_expiresAtKey);
    await prefs.remove(_durationKey);
    await prefs.remove(_maxDevicesKey);
    await prefs.remove(_usedDevicesKey);
    await prefs.remove(_devicesKey);
    await prefs.remove(_lastVerifiedAtKey);

    await _clearCustomerLogoCache();

    GABBranding.clearCache();
  }

  // ============================================================
  // HELPERS
  // ============================================================

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }

  int? _toInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(value.toString());
  }
}
