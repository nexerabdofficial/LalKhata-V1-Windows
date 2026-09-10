import 'package:shared_preferences/shared_preferences.dart';

class CurrencyHelper {
  static Future<String> getSymbol() async {
    final prefs = await SharedPreferences.getInstance();

    final currency =
        prefs.getString("currency") ?? "BDT";

    switch (currency) {
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