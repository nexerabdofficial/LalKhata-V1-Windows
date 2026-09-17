import 'package:shared_preferences/shared_preferences.dart';

import 'gab_profile.dart';

class GABBranding {
  GABBranding._();

  // ============================================================
  // DEFAULT / DEVELOPER PROFILE
  // ============================================================

  static String get defaultBusinessName => GABProfile.businessName;

  static String get defaultStoreName => GABProfile.storeName;

  static String get defaultPhone => GABProfile.phone;

  static String get defaultAddress => GABProfile.address;

  static String get defaultEmail => GABProfile.email;

  // ============================================================
  // LOCAL KEYS
  // ============================================================

  static const String _businessNameKey = 'nexera_license_business_name';

  static const String _phoneKey = 'nexera_license_phone';

  static const String _addressKey = 'nexera_license_address';

  static const String _emailKey = 'nexera_license_email';

  static const String _taglineKey = 'nexera_license_tagline';

  // ============================================================
  // MEMORY CACHE
  // ============================================================

  static String _businessName = GABProfile.businessName;

  static String _phone = GABProfile.phone;

  static String _address = GABProfile.address;

  static String _email = GABProfile.email;

  static String _tagline = '';

  // ============================================================
  // GET BUSINESS NAME
  // ============================================================

  static Future<String> getBusinessName() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_businessNameKey) ?? GABProfile.businessName;
  }

  // ============================================================
  // GET PHONE
  // ============================================================

  static Future<String> getPhone() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_phoneKey) ?? GABProfile.phone;
  }

  // ============================================================
  // GET ADDRESS
  // ============================================================

  static Future<String> getAddress() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_addressKey) ?? GABProfile.address;
  }

  // ============================================================
  // GET EMAIL
  // ============================================================

  static Future<String> getEmail() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_emailKey) ?? GABProfile.email;
  }

  // ============================================================
  // GET TAGLINE
  // ============================================================

  static Future<String> getTagline() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_taglineKey) ?? '';
  }

  // ============================================================
  // LOAD
  // ============================================================

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    _businessName =
        prefs.getString(_businessNameKey) ?? GABProfile.businessName;

    _phone = prefs.getString(_phoneKey) ?? GABProfile.phone;

    _address = prefs.getString(_addressKey) ?? GABProfile.address;

    _email = prefs.getString(_emailKey) ?? GABProfile.email;

    _tagline = prefs.getString(_taglineKey) ?? '';
  }

  // ============================================================
  // REFRESH
  // ============================================================

  static Future<void> refresh() async {
    await load();
  }

  // ============================================================
  // UPDATE CACHE
  // ============================================================

  static void updateCache({
    String? businessName,
    String? phone,
    String? address,
    String? email,
    String? tagline,
  }) {
    if (businessName != null && businessName.trim().isNotEmpty) {
      _businessName = businessName.trim();
    }

    if (phone != null) {
      _phone = phone.trim();
    }

    if (address != null) {
      _address = address.trim();
    }

    if (email != null) {
      _email = email.trim();
    }

    if (tagline != null) {
      _tagline = tagline.trim();
    }
  }

  // ============================================================
  // CLEAR CACHE
  // ============================================================

  static void clearCache() {
    // ==========================================================
    // CLEAR CUSTOMER BRANDING COMPLETELY
    //
    // Do NOT restore GABProfile customer/business information.
    // The next active license will load its own branding.
    //
    // This prevents Company A branding from appearing while
    // switching to Company B on the same device.
    // ==========================================================

    _businessName = '';
    _phone = '';
    _address = '';
    _email = '';
    _tagline = '';
  }

  // ============================================================
  // CURRENT CUSTOMER DATA
  // ============================================================

  static String get businessName => _businessName;

  static String get phone => _phone;

  static String get address => _address;

  static String get email => _email;

  static String get tagline => _tagline;

  // ============================================================
  // OTHER BRANDING
  // ============================================================

  static String get storeName => _businessName;

  static String get developedBy => GABProfile.developedBy;

  static String get appVersion => GABProfile.appVersion;

  static String get logoAsset => GABProfile.logoAsset;

  static String get currency => GABProfile.currency;

  static String get currencySymbol => GABProfile.currencySymbol;

  static String get licenseCustomerId => GABProfile.licenseCustomerId;

  static bool get licenseEnabled => GABProfile.licenseEnabled;
}
