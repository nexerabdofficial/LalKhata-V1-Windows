import 'package:shared_preferences/shared_preferences.dart';

import 'gab_profile.dart';

class GABBranding {
  GABBranding._();

  // ==========================================================
  // DEFAULT BRANDING
  // ==========================================================

  static String get defaultBusinessName =>
      GABProfile.businessName;

  static String get defaultStoreName =>
      GABProfile.storeName;

  static String get defaultPhone =>
      GABProfile.phone;

  static String get defaultAddress =>
      GABProfile.address;

  static String get defaultEmail =>
      GABProfile.email;

  // ==========================================================
  // LICENSE BRANDING KEYS
  // ==========================================================

  static const String _businessNameKey =
      'nexera_license_business_name';

  static const String _phoneKey =
      'nexera_license_phone';

  static const String _addressKey =
      'nexera_license_address';

  // ==========================================================
  // MEMORY CACHE
  //
  // IMPORTANT:
  // PDF / Balance Sheet / Profit Report synchronous getter
  // ব্যবহার করে। তাই SharedPreferences update হওয়ার পর
  // এই cache-ও অবশ্যই update করতে হবে।
  // ==========================================================

  static String _businessName =
      GABProfile.businessName;

  static String _phone =
      GABProfile.phone;

  static String _address =
      GABProfile.address;

  // ==========================================================
  // ASYNC GETTERS
  //
  // Settings / About screen থেকে সরাসরি latest saved value
  // পাওয়া যাবে।
  // ==========================================================

  static Future<String> getBusinessName() async {
    final prefs =
        await SharedPreferences.getInstance();

    return prefs.getString(_businessNameKey) ??
        GABProfile.businessName;
  }

  static Future<String> getPhone() async {
    final prefs =
        await SharedPreferences.getInstance();

    return prefs.getString(_phoneKey) ??
        GABProfile.phone;
  }

  static Future<String> getAddress() async {
    final prefs =
        await SharedPreferences.getInstance();

    return prefs.getString(_addressKey) ??
        GABProfile.address;
  }

  // ==========================================================
  // LOAD / RELOAD
  //
  // App startup এবং license change-এর পরে এই method call করা
  // যাবে।
  // ==========================================================

  static Future<void> load() async {
    final prefs =
        await SharedPreferences.getInstance();

    _businessName =
        prefs.getString(_businessNameKey) ??
            GABProfile.businessName;

    _phone =
        prefs.getString(_phoneKey) ??
            GABProfile.phone;

    _address =
        prefs.getString(_addressKey) ??
            GABProfile.address;
  }

  // ==========================================================
  // REFRESH
  //
  // load()-এর explicit alias।
  // License activate / verify হওয়ার পরে ব্যবহার করা যাবে।
  // ==========================================================

  static Future<void> refresh() async {
    await load();
  }

  // ==========================================================
  // UPDATE CACHE DIRECTLY
  //
  // LicenseService যখন নতুন customer/license save করবে,
  // তখন app restart ছাড়াই Branding cache update করার জন্য।
  // ==========================================================

  static void updateCache({
    String? businessName,
    String? phone,
    String? address,
  }) {
    if (businessName != null &&
        businessName.trim().isNotEmpty) {
      _businessName =
          businessName.trim();
    }

    if (phone != null) {
      _phone = phone.trim();
    }

    if (address != null) {
      _address = address.trim();
    }
  }

  // ==========================================================
  // CLEAR CACHE
  //
  // License deactivate / logout / testing-এর সময় ব্যবহার করা
  // যেতে পারে।
  // ==========================================================

  static void clearCache() {
    _businessName =
        GABProfile.businessName;

    _phone =
        GABProfile.phone;

    _address =
        GABProfile.address;
  }

  // ==========================================================
  // SYNC GETTERS
  //
  // PDF / Report / Invoice এগুলো এগুলো ব্যবহার করবে।
  // ==========================================================

  static String get businessName =>
      _businessName;

  static String get phone =>
      _phone;

  static String get address =>
      _address;

  static String get email =>
      GABProfile.email;

  static String get storeName =>
      _businessName;

  // ==========================================================
  // DEVELOPER IDENTITY
  //
  // Customer business name থেকে সম্পূর্ণ আলাদা।
  // ==========================================================

  static String get developedBy =>
      GABProfile.developedBy;

  static String get appVersion =>
      GABProfile.appVersion;

  static String get logoAsset =>
      GABProfile.logoAsset;

  // ==========================================================
  // CURRENCY
  // ==========================================================

  static String get currency =>
      GABProfile.currency;

  static String get currencySymbol =>
      GABProfile.currencySymbol;

  // ==========================================================
  // LICENSE
  // ==========================================================

  static String get licenseCustomerId =>
      GABProfile.licenseCustomerId;

  static bool get licenseEnabled =>
      GABProfile.licenseEnabled;
}