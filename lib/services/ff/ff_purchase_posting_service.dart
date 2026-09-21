import 'package:sqflite/sqflite.dart';

import '../../models/payment_allocation.dart';
import '../../models/purchase.dart';
import 'ff_journal_models.dart';
import 'ff_journal_service.dart';
import 'ff_party_account_service.dart';
import 'ff_system_accounts.dart';

class FFPurchasePostingService {
  FFPurchasePostingService._();

  static final FFPurchasePostingService instance = FFPurchasePostingService._();

  final FFJournalService _journalService = FFJournalService.instance;

  final FFPartyAccountService _partyAccountService =
      FFPartyAccountService.instance;

  // ============================================================
  // LEGACY / SINGLE PAYMENT COMPATIBILITY
  // ============================================================

  Future<int> postPurchaseWithExecutor(
    DatabaseExecutor db, {
    required int purchaseId,
    required Purchase purchase,
    required String voucherNo,
  }) async {
    final allocations = <PaymentAllocation>[];

    if (purchase.paid > 0) {
      if (purchase.accountId == null) {
        throw ArgumentError('Payment account is required.');
      }

      allocations.add(
        PaymentAllocation(
          referenceType: 'PURCHASE',
          referenceId: purchaseId,
          accountId: purchase.accountId!,
          amount: purchase.paid,
          paymentMethod: purchase.paymentMethod,
          createdAt: purchase.createdAt,
        ),
      );
    }

    return postPurchaseWithAllocationsWithExecutor(
      db,
      purchaseId: purchaseId,
      purchase: purchase,
      allocations: allocations,
      voucherNo: voucherNo,
    );
  }

  // ============================================================
  // MULTI ACCOUNT PURCHASE POSTING
  // ============================================================

  Future<int> postPurchaseWithAllocationsWithExecutor(
    DatabaseExecutor db, {
    required int purchaseId,
    required Purchase purchase,
    required List<PaymentAllocation> allocations,
    required String voucherNo,
  }) async {
    if (purchaseId <= 0) {
      throw ArgumentError('Invalid purchase ID.');
    }

    if (purchase.supplierId <= 0) {
      throw ArgumentError('Invalid supplier ID.');
    }

    if (purchase.grandTotal <= 0) {
      throw ArgumentError('Purchase grand total must be greater than zero.');
    }

    if (purchase.paid < 0 || purchase.paid > purchase.grandTotal) {
      throw ArgumentError('Invalid purchase paid amount.');
    }

    double allocationTotal = 0;

    for (final allocation in allocations) {
      if (allocation.referenceType != 'PURCHASE') {
        throw ArgumentError('Invalid purchase allocation reference type.');
      }

      if (allocation.referenceId != purchaseId) {
        throw ArgumentError('Purchase allocation reference mismatch.');
      }

      if (allocation.accountId <= 0) {
        throw ArgumentError('Invalid purchase payment account.');
      }

      if (allocation.amount <= 0) {
        throw ArgumentError(
          'Purchase payment allocation must be greater than zero.',
        );
      }

      allocationTotal += allocation.amount;
    }

    if ((allocationTotal - purchase.paid).abs() > 0.000001) {
      throw StateError(
        'Purchase payment allocation total '
        '($allocationTotal) does not match '
        'purchase paid amount (${purchase.paid}).',
      );
    }

    final inventoryAccountId = await _resolveSystemAccountId(
      db,
      FFSystemAccountCodes.inventory,
    );

    final supplierPayableAccountId = await _partyAccountService
        .ensureSupplierAccountWithExecutor(db, purchase.supplierId);

    final additionalChargeAccountId = purchase.additionalCharge > 0.000001
        ? await _resolveSystemAccountId(
            db,
            FFSystemAccountCodes.purchaseAdditionalCharge,
          )
        : null;

    final purchaseDiscountAccountId = purchase.invoiceDiscount > 0.000001
        ? await _resolveSystemAccountId(
            db,
            FFSystemAccountCodes.purchaseDiscount,
          )
        : null;

    // Product stock_value is increased only by purchase item subtotal.
    // Therefore FF Inventory must represent the same inventory value.
    //
    // grandTotal =
    //   itemSubtotal + additionalCharge - invoiceDiscount
    //
    // itemSubtotal =
    //   grandTotal - additionalCharge + invoiceDiscount
    final inventoryAmount =
        purchase.grandTotal -
        purchase.additionalCharge +
        purchase.invoiceDiscount;

    if (inventoryAmount <= 0.000001) {
      throw StateError('Purchase inventory amount must be greater than zero.');
    }

    final lines = <FFJournalLine>[
      FFJournalLine(
        accountId: inventoryAccountId,
        debit: inventoryAmount,
        note: 'Inventory purchase',
      ),
    ];

    if (purchase.additionalCharge > 0.000001) {
      lines.add(
        FFJournalLine(
          accountId: additionalChargeAccountId!,
          debit: purchase.additionalCharge,
          note: 'Purchase additional charge',
        ),
      );
    }

    if (purchase.invoiceDiscount > 0.000001) {
      lines.add(
        FFJournalLine(
          accountId: purchaseDiscountAccountId!,
          credit: purchase.invoiceDiscount,
          note: 'Purchase discount',
        ),
      );
    }

    for (final allocation in allocations) {
      lines.add(
        FFJournalLine(
          accountId: allocation.accountId,
          credit: allocation.amount,
          note: allocation.paymentMethod.trim().isEmpty
              ? 'Purchase payment'
              : 'Purchase payment - ${allocation.paymentMethod}',
        ),
      );
    }

    final due = purchase.grandTotal - allocationTotal;

    if (due > 0.000001) {
      lines.add(
        FFJournalLine(
          accountId: supplierPayableAccountId,
          entityType: 'SUPPLIER',
          entityId: purchase.supplierId,
          credit: due,
          note: 'Supplier payable',
        ),
      );
    }

    return _journalService.createJournalWithExecutor(
      db,
      FFJournalEntry(
        transactionType: 'PURCHASE',
        voucherNo: voucherNo,
        transactionDate: purchase.purchaseDate,
        referenceType: 'PURCHASE',
        referenceId: purchaseId,
        description: (purchase.note ?? '').trim().isEmpty
            ? 'Purchase'
            : purchase.note!.trim(),
        createdAt: purchase.createdAt,
        lines: lines,
      ),
    );
  }

  Future<int> _resolveSystemAccountId(DatabaseExecutor db, String type) async {
    final rows = await db.query(
      'accounts',
      columns: ['id'],
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'id ASC',
      limit: 1,
    );

    if (rows.isEmpty) {
      throw StateError('FF system account not found: $type');
    }

    return (rows.first['id'] as num).toInt();
  }
}
