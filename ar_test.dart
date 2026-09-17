import 'package:flutter/widgets.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:nexera_inventory/services/ar_data_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final ar = ARDataService();

  print('');
  print('================ AR DATA TEST ================');

  print('Today Sales     : ${await ar.getTodaySales()}');
  print('Today Purchase  : ${await ar.getTodayPurchase()}');
  print('Today Expense   : ${await ar.getTodayExpense()}');
  print('Today Income    : ${await ar.getTodayIncome()}');
  print('Money Received  : ${await ar.getTodayMoneyReceived()}');
  print('Money Given     : ${await ar.getTodayMoneyGiven()}');
  print('Cash Closing    : ${await ar.getCashClosing()}');

  final products = await ar.getBestSellingProducts(limit: 5);

  print('');
  print('Best Selling Products:');

  for (final product in products) {
    print('${product.productName} -> ${product.quantity}');
  }

  print('==============================================');
}
