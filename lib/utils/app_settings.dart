import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  // ============================================================
  // GAB — GENERAL APK BUILD
  // ============================================================

  // ------------------------------------------------------------
  // DEFAULT BUSINESS CONFIGURATION
  // ------------------------------------------------------------

  static const String defaultBusinessName = 'Rahim Store';
  static const String defaultOwnerName = 'Rahim';
  static const String defaultPhone = '';
  static const String defaultAddress = '';

  // IMPORTANT:
  // This will remain NexEra's developer identity.
  // Customer should not be able to change this from the app.
  static const String developerName = 'NexEra IT BD';

  // License ID will later be connected to the GAB
  // license validation system.
  static const String defaultLicenseId = 'GAB-DEMO';

  // ------------------------------------------------------------
  // BUSINESS NAME
  // ------------------------------------------------------------

  static Future<String> businessName() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString('gab_business_name') ??
        defaultBusinessName;
  }

  static Future<void> setBusinessName(
    String value,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'gab_business_name',
      value.trim(),
    );
  }

  // ------------------------------------------------------------
  // OWNER NAME
  // ------------------------------------------------------------

  static Future<String> ownerName() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString('gab_owner_name') ??
        defaultOwnerName;
  }

  static Future<void> setOwnerName(
    String value,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'gab_owner_name',
      value.trim(),
    );
  }

  // ------------------------------------------------------------
  // PHONE
  // ------------------------------------------------------------

  static Future<String> phone() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString('gab_phone') ??
        defaultPhone;
  }

  static Future<void> setPhone(
    String value,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'gab_phone',
      value.trim(),
    );
  }

  // ------------------------------------------------------------
  // ADDRESS
  // ------------------------------------------------------------

  static Future<String> address() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString('gab_address') ??
        defaultAddress;
  }

  static Future<void> setAddress(
    String value,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'gab_address',
      value.trim(),
    );
  }

  // ------------------------------------------------------------
  // DEVELOPER
  // ------------------------------------------------------------
  //
  // Do NOT provide a setter.
  //
  // Customer can change business identity,
  // but NexEra developer identity stays fixed.
  // ------------------------------------------------------------

  static String developer() {
    return developerName;
  }

  // ------------------------------------------------------------
  // LICENSE ID
  // ------------------------------------------------------------
  //
  // Phase 1:
  // Stored locally.
  //
  // Later:
  // This will be validated against the GAB license server.
  // ------------------------------------------------------------

  static Future<String> licenseId() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString('gab_license_id') ??
        defaultLicenseId;
  }

  static Future<void> setLicenseId(
    String value,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'gab_license_id',
      value.trim(),
    );
  }

  // ------------------------------------------------------------
  // CURRENCY
  // ------------------------------------------------------------

  static Future<String> currencySymbol() async {
    final prefs = await SharedPreferences.getInstance();

    switch (prefs.getString("currency") ?? "BDT") {
      case "USD":
        return "\$";

      case "CNY":
        return "¥";

      case "INR":
        return "₹";

      default:
        return "৳";
    }
  }
}