import 'package:sqflite/sqflite.dart';

import '../../models/payment_allocation.dart';

class FFPaymentAllocationService {
  FFPaymentAllocationService._();

  static final FFPaymentAllocationService instance =
      FFPaymentAllocationService._();

  Future<void> replaceAllocationsWithExecutor(
    DatabaseExecutor db, {
    required String referenceType,
    required int referenceId,
    required List<PaymentAllocation> allocations,
  }) async {
    if (referenceType.trim().isEmpty) {
      throw ArgumentError('Payment allocation reference type is required.');
    }

    if (referenceId <= 0) {
      throw ArgumentError('Invalid payment allocation reference ID.');
    }

    for (final allocation in allocations) {
      if (allocation.accountId <= 0) {
        throw ArgumentError('Invalid payment allocation account.');
      }

      if (allocation.amount <= 0) {
        throw ArgumentError(
          'Payment allocation amount must be greater than zero.',
        );
      }
    }

    await deleteAllocationsWithExecutor(
      db,
      referenceType: referenceType,
      referenceId: referenceId,
    );

    for (final allocation in allocations) {
      await db.insert('payment_allocations', {
        'reference_type': referenceType,
        'reference_id': referenceId,
        'account_id': allocation.accountId,
        'amount': allocation.amount,
        'payment_method': allocation.paymentMethod,
        'created_at': allocation.createdAt,
      });
    }
  }

  Future<void> deleteAllocationsWithExecutor(
    DatabaseExecutor db, {
    required String referenceType,
    required int referenceId,
  }) async {
    await db.delete(
      'payment_allocations',
      where: 'reference_type = ? AND reference_id = ?',
      whereArgs: [referenceType, referenceId],
    );
  }

  Future<List<PaymentAllocation>> getAllocationsWithExecutor(
    DatabaseExecutor db, {
    required String referenceType,
    required int referenceId,
  }) async {
    final rows = await db.query(
      'payment_allocations',
      where: 'reference_type = ? AND reference_id = ?',
      whereArgs: [referenceType, referenceId],
      orderBy: 'id ASC',
    );

    return rows.map(PaymentAllocation.fromMap).toList();
  }

  double totalAmount(Iterable<PaymentAllocation> allocations) {
    return allocations.fold<double>(
      0,
      (sum, allocation) => sum + allocation.amount,
    );
  }
}
