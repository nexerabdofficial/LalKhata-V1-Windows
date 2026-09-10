import 'product.dart';

class CartItem {
  final Product product;

  int quantity;

  /// Invoice-এর actual selling rate.
  ///
  /// Product-এর default sellingPrice থেকে শুরু হবে,
  /// কিন্তু invoice করার সময় user চাইলে এটা পরিবর্তন করতে পারবে।
  double saleRate;

  CartItem({
    required this.product,
    required this.quantity,
    required this.saleRate,
  });

  /// Invoice line total
  double get subtotal => saleRate * quantity;
}