import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
class CurrencyScreen extends StatefulWidget {
  const CurrencyScreen({super.key});

  @override
  State<CurrencyScreen> createState() =>
      _CurrencyScreenState();
}

class _CurrencyScreenState
    extends State<CurrencyScreen> {
  String selectedCurrency = "BDT";
  Future<void> _loadCurrency() async {
  final prefs = await SharedPreferences.getInstance();

  setState(() {
    selectedCurrency =
        prefs.getString("currency") ?? "BDT";
  });
}

Future<void> _saveCurrency(String value) async {
  final prefs = await SharedPreferences.getInstance();

  await prefs.setString("currency", value);

  setState(() {
    selectedCurrency = value;
  });
}
@override
void initState() {
  super.initState();
  _loadCurrency();
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Currency"),
      ),
      body: ListView(
        children: [
          RadioListTile<String>(
            value: "BDT",
            groupValue: selectedCurrency,
            onChanged: (value) {
              _saveCurrency(value!);
            },
            title: const Text("BDT (৳)"),
          ),
          RadioListTile<String>(
            value: "USD",
            groupValue: selectedCurrency,
            onChanged: (value) {
              _saveCurrency(value!);
            },
            title: const Text("USD (\$)"),
          ),
          RadioListTile<String>(
            value: "CNY",
            groupValue: selectedCurrency,
            onChanged: (value) {
              _saveCurrency(value!);
            },
            title: const Text("CNY (¥)"),
          ),
          RadioListTile<String>(
            value: "INR",
            groupValue: selectedCurrency,
            onChanged: (value) {
              _saveCurrency(value!);
            },
            title: const Text("INR (₹)"),
          ),
        ],
      ),
    );
  }
}