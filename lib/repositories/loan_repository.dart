import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/loan.dart';
import '../models/loan_payment.dart';
import '../services/ff/ff_journal_service.dart';
import '../services/ff/ff_loan_posting_service.dart';

class LoanRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  final FFLoanPostingService _ffLoanPostingService =
      FFLoanPostingService.instance;

  final FFJournalService _ffJournalService = FFJournalService.instance;

  // ============================================================
  // CONSTANTS
  // ============================================================

  static const double _epsilon = 0.000001;
  static const double _moneyTolerance = 0.01;

  // ============================================================
  // DATE HELPERS
  // ============================================================

  DateTime _dateOnly(String value) {
    return DateTime.parse(_normalizeDate(value));
  }

  String _normalizeDate(String value) {
    return value.split('T').first;
  }

  int _daysBetween(String fromDate, String toDate) {
    final from = _dateOnly(fromDate);
    final to = _dateOnly(toDate);

    return to.difference(from).inDays;
  }

  // ============================================================
  // MONEY HELPER
  // ============================================================

  double _cleanMoney(double value) {
    if (value.abs() < _epsilon) {
      return 0.0;
    }

    return double.parse(value.toStringAsFixed(2));
  }

  // ============================================================
  // CREATE LOAN
  // ============================================================

  Future<int> insertLoan(Loan loan) async {
    final Database db = await _databaseHelper.database;

    final loanType = loan.loanType.toUpperCase();

    if (loanType != 'GIVEN' && loanType != 'TAKEN') {
      throw ArgumentError('Invalid loan type.');
    }

    if (loan.principalAmount <= 0) {
      throw ArgumentError('Loan amount must be greater than zero.');
    }

    if (loan.interestRate < 0) {
      throw ArgumentError('Interest rate cannot be negative.');
    }

    if (loan.accountId == null) {
      throw ArgumentError('Loan account is required.');
    }

    return await db.transaction((txn) async {
      final loanMap = loan.toMap();

      loanMap['loan_type'] = loanType;

      loanMap['accrued_interest'] = 0.0;

      loanMap['last_interest_date'] = _normalizeDate(loan.loanDate);

      loanMap['paid_amount'] = 0.0;

      loanMap['interest_amount'] = 0.0;

      loanMap['status'] = 'ACTIVE';

      final loanId = await txn.insert(
        'loans',
        loanMap,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      // --------------------------------------------------------
      // ACCOUNT TRANSACTION
      // --------------------------------------------------------

      final createdAt = DateTime.now().toIso8601String();

      final voucherNo = 'LOAN-${loanId.toString().padLeft(6, '0')}';

      if (loanType == 'GIVEN') {
        await txn.insert('account_transactions', {
          'account_id': loan.accountId,
          'transaction_type': 'LOAN_GIVEN',
          'reference_type': 'LOAN',
          'reference_id': loanId,
          'voucher_no': voucherNo,
          'debit': _cleanMoney(loan.principalAmount),
          'credit': 0.0,
          'transaction_date': _normalizeDate(loan.loanDate),
          'note': loan.note,
          'created_at': createdAt,
        });
      } else {
        await txn.insert('account_transactions', {
          'account_id': loan.accountId,
          'transaction_type': 'LOAN_TAKEN',
          'reference_type': 'LOAN',
          'reference_id': loanId,
          'voucher_no': voucherNo,
          'debit': 0.0,
          'credit': _cleanMoney(loan.principalAmount),
          'transaction_date': _normalizeDate(loan.loanDate),
          'note': loan.note,
          'created_at': createdAt,
        });
      }

      await _ffLoanPostingService.postLoanWithExecutor(
        txn,
        loanId: loanId,
        loanType: loanType,
        accountId: loan.accountId!,
        principalAmount: _cleanMoney(loan.principalAmount),
        transactionDate: _normalizeDate(loan.loanDate),
        note: loan.note,
      );

      return loanId;
    });
  }

  // ============================================================
  // GET ALL LOANS
  // ============================================================

  Future<List<Loan>> getLoans() async {
    final Database db = await _databaseHelper.database;

    final maps = await db.query('loans', orderBy: 'id DESC');

    return maps.map((map) => Loan.fromMap(map)).toList();
  }

  // ============================================================
  // GET ACTIVE LOANS
  // ============================================================

  Future<List<Loan>> getActiveLoans() async {
    final Database db = await _databaseHelper.database;

    final maps = await db.query(
      'loans',
      where: 'status != ?',
      whereArgs: ['PAID'],
      orderBy: 'id DESC',
    );

    return maps.map((map) => Loan.fromMap(map)).toList();
  }

  // ============================================================
  // GET GIVEN LOANS
  // ============================================================

  Future<List<Loan>> getGivenLoans() async {
    final Database db = await _databaseHelper.database;

    final maps = await db.query(
      'loans',
      where: 'loan_type = ?',
      whereArgs: ['GIVEN'],
      orderBy: 'id DESC',
    );

    return maps.map((map) => Loan.fromMap(map)).toList();
  }

  // ============================================================
  // GET TAKEN LOANS
  // ============================================================

  Future<List<Loan>> getTakenLoans() async {
    final Database db = await _databaseHelper.database;

    final maps = await db.query(
      'loans',
      where: 'loan_type = ?',
      whereArgs: ['TAKEN'],
      orderBy: 'id DESC',
    );

    return maps.map((map) => Loan.fromMap(map)).toList();
  }

  // ============================================================
  // GET SINGLE LOAN
  // ============================================================

  Future<Loan?> getLoanById(int id) async {
    final Database db = await _databaseHelper.database;

    final maps = await db.query(
      'loans',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return Loan.fromMap(maps.first);
  }

  // ============================================================
  // CALCULATE ACCRUED INTEREST
  //
  // remaining principal
  // × annual rate
  // ÷ 365
  // × days
  //
  // Accrued interest is NOT added to principal.
  // ============================================================

  Future<double> calculateAccruedInterest(
    int loanId, {
    String? calculationDate,
  }) async {
    final Database db = await _databaseHelper.database;

    final maps = await db.query(
      'loans',
      where: 'id = ?',
      whereArgs: [loanId],
      limit: 1,
    );

    if (maps.isEmpty) {
      throw StateError('Loan does not exist.');
    }

    final loan = Loan.fromMap(maps.first);

    final targetDate = _normalizeDate(
      calculationDate ?? DateTime.now().toIso8601String(),
    );

    final lastDate = _normalizeDate(loan.lastInterestDate ?? loan.loanDate);

    final days = _daysBetween(lastDate, targetDate);

    if (days < 0) {
      throw ArgumentError(
        'Calculation date cannot be before last interest date.',
      );
    }

    if (loan.remainingPrincipal <= _epsilon) {
      return _cleanMoney(loan.accruedInterest);
    }

    if (days == 0 || loan.interestRate <= 0) {
      return _cleanMoney(loan.accruedInterest);
    }

    final dailyRate = loan.interestRate / 100 / 365;

    final newInterest = loan.remainingPrincipal * dailyRate * days;

    return _cleanMoney(loan.accruedInterest + newInterest);
  }

  // ============================================================
  // ACCRUE INTEREST INSIDE TRANSACTION
  // ============================================================

  double _accrueInterestInsideTransaction(Loan loan, String calculationDate) {
    final targetDate = _normalizeDate(calculationDate);

    final lastDate = _normalizeDate(loan.lastInterestDate ?? loan.loanDate);

    final days = _daysBetween(lastDate, targetDate);

    if (days < 0) {
      throw ArgumentError('Payment date cannot be before last interest date.');
    }

    double accrued = loan.accruedInterest;

    if (days > 0 &&
        loan.remainingPrincipal > _epsilon &&
        loan.interestRate > 0) {
      final dailyRate = loan.interestRate / 100 / 365;

      final newInterest = loan.remainingPrincipal * dailyRate * days;

      accrued += newInterest;
    }

    return _cleanMoney(accrued);
  }

  // ============================================================
  // CALCULATE ACCRUED INTEREST FROM PAYMENT HISTORY
  //
  // Payment history is the source of truth.
  //
  // Interest:
  // outstanding principal
  // × annual rate
  // ÷ 365
  // × days
  //
  // Interest is NOT added to principal.
  // ============================================================

  Future<double> _calculateAccruedInterestFromHistory(
    Transaction txn,
    Loan loan,
    String targetDate,
  ) async {
    final normalizedTarget = _normalizeDate(targetDate);

    final loanDate = _normalizeDate(loan.loanDate);

    if (_daysBetween(loanDate, normalizedTarget) < 0) {
      throw ArgumentError('Calculation date cannot be before loan date.');
    }

    final payments = await txn.query(
      'loan_payments',
      where: 'loan_id = ?',
      whereArgs: [loan.id],
      orderBy: 'payment_date ASC, id ASC',
    );

    double outstandingPrincipal = loan.principalAmount;

    double accruedInterest = 0.0;

    String currentDate = loanDate;

    for (final map in payments) {
      final payment = LoanPayment.fromMap(map);

      final paymentDate = _normalizeDate(payment.paymentDate);

      // Ignore payments after target date.
      if (_daysBetween(paymentDate, normalizedTarget) < 0) {
        break;
      }

      // Safety: invalid payment date.
      if (_daysBetween(loanDate, paymentDate) < 0) {
        continue;
      }

      // --------------------------------------------------------
      // ACCRUE INTEREST BEFORE THIS PAYMENT
      // --------------------------------------------------------

      final days = _daysBetween(currentDate, paymentDate);

      if (days > 0 &&
          outstandingPrincipal > _epsilon &&
          loan.interestRate > 0) {
        final dailyRate = loan.interestRate / 100 / 365;

        final newInterest = outstandingPrincipal * dailyRate * days;

        accruedInterest += newInterest;
      }

      accruedInterest = _cleanMoney(accruedInterest);

      // --------------------------------------------------------
      // PAYMENT FIRST CLEARS INTEREST
      // --------------------------------------------------------

      accruedInterest -= payment.interestAmount;

      accruedInterest = _cleanMoney(accruedInterest);

      if (accruedInterest < _epsilon) {
        accruedInterest = 0.0;
      }

      // --------------------------------------------------------
      // REMAINING PAYMENT REDUCES PRINCIPAL
      // --------------------------------------------------------

      outstandingPrincipal -= payment.principalAmount;

      outstandingPrincipal = _cleanMoney(outstandingPrincipal);

      if (outstandingPrincipal < _epsilon) {
        outstandingPrincipal = 0.0;
      }

      currentDate = paymentDate;

      if (outstandingPrincipal <= _epsilon) {
        break;
      }
    }

    // ----------------------------------------------------------
    // ACCRUE FROM LAST PAYMENT UNTIL TARGET DATE
    // ----------------------------------------------------------

    final remainingDays = _daysBetween(currentDate, normalizedTarget);

    if (remainingDays > 0 &&
        outstandingPrincipal > _epsilon &&
        loan.interestRate > 0) {
      final dailyRate = loan.interestRate / 100 / 365;

      accruedInterest += outstandingPrincipal * dailyRate * remainingDays;
    }

    return _cleanMoney(accruedInterest);
  }

  // ============================================================
  // GET PAYMENTS
  // ============================================================

  Future<List<LoanPayment>> getLoanPayments(int loanId) async {
    final Database db = await _databaseHelper.database;

    final maps = await db.query(
      'loan_payments',
      where: 'loan_id = ?',
      whereArgs: [loanId],
      orderBy: 'payment_date ASC, id ASC',
    );

    return maps.map((map) => LoanPayment.fromMap(map)).toList();
  }

  // ============================================================
  // GET SINGLE PAYMENT
  // ============================================================

  Future<LoanPayment?> getLoanPaymentById(int id) async {
    final Database db = await _databaseHelper.database;

    final maps = await db.query(
      'loan_payments',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return LoanPayment.fromMap(maps.first);
  }

  // ============================================================
  // INSERT LOAN PAYMENT
  //
  // PAYMENT AMOUNT = TOTAL CASH MOVEMENT
  //
  // Allocation:
  //
  // 1. Interest first
  // 2. Remaining amount → Principal
  // ============================================================

  Future<int> insertLoanPayment(LoanPayment payment) async {
    final Database db = await _databaseHelper.database;

    return await db.transaction((txn) async {
      // ------------------------------------------------------
      // LOAD LOAN
      // ------------------------------------------------------

      final loanMaps = await txn.query(
        'loans',
        where: 'id = ?',
        whereArgs: [payment.loanId],
        limit: 1,
      );

      if (loanMaps.isEmpty) {
        throw StateError('Loan does not exist.');
      }

      final loan = Loan.fromMap(loanMaps.first);

      // ------------------------------------------------------
      // LOAN STATUS
      // ------------------------------------------------------

      if (loan.status == 'PAID') {
        throw StateError('This loan is already fully settled.');
      }

      // ------------------------------------------------------
      // PAYMENT DATE
      // ------------------------------------------------------

      final paymentDate = _normalizeDate(payment.paymentDate);

      if (_daysBetween(loan.loanDate, paymentDate) < 0) {
        throw ArgumentError('Payment date cannot be before loan date.');
      }

      final lastInterestDate = _normalizeDate(
        loan.lastInterestDate ?? loan.loanDate,
      );

      if (_daysBetween(lastInterestDate, paymentDate) < 0) {
        throw ArgumentError(
          'Payment date cannot be before last interest date.',
        );
      }

      // ------------------------------------------------------
      // VALIDATE PAYMENT
      // ------------------------------------------------------

      if (payment.amount <= 0) {
        throw ArgumentError('Payment amount must be greater than zero.');
      }

      if (payment.accountId == null) {
        throw ArgumentError('Payment account is required.');
      }

      // ------------------------------------------------------
      // CURRENT ACCRUED INTEREST
      // ------------------------------------------------------

      final currentAccrued = await _calculateAccruedInterestFromHistory(
        txn,
        loan,
        paymentDate,
      );

      final remainingPrincipal = loan.remainingPrincipal;

      final totalOutstanding = remainingPrincipal + currentAccrued;

      // ------------------------------------------------------
      // PAYMENT CANNOT EXCEED OUTSTANDING
      // ------------------------------------------------------

      if (payment.amount > totalOutstanding + _moneyTolerance) {
        throw ArgumentError('Payment exceeds total outstanding amount.');
      }

      // ------------------------------------------------------
      // AUTOMATIC PAYMENT ALLOCATION
      //
      // INTEREST FIRST
      // ------------------------------------------------------

      final interestPaid = _cleanMoney(
        payment.amount <= currentAccrued ? payment.amount : currentAccrued,
      );

      final principalPaid = _cleanMoney(payment.amount - interestPaid);

      if (principalPaid > remainingPrincipal + _moneyTolerance) {
        throw ArgumentError('Principal payment exceeds remaining principal.');
      }

      // ------------------------------------------------------
      // NEW LOAN STATE
      // ------------------------------------------------------

      final newPaidAmount = _cleanMoney(loan.paidAmount + principalPaid);

      double newRemainingPrincipal = loan.principalAmount - newPaidAmount;

      if (newRemainingPrincipal.abs() < _moneyTolerance) {
        newRemainingPrincipal = 0.0;
      }

      double newAccruedInterest = _cleanMoney(currentAccrued - interestPaid);

      if (newAccruedInterest.abs() < _moneyTolerance) {
        newAccruedInterest = 0.0;
      }

      final newInterestAmount = _cleanMoney(loan.interestAmount + interestPaid);

      // ------------------------------------------------------
      // STATUS
      // ------------------------------------------------------

      String newStatus;

      if (newRemainingPrincipal <= _epsilon && newAccruedInterest <= _epsilon) {
        newStatus = 'PAID';
      } else if (newPaidAmount > _epsilon) {
        newStatus = 'PARTIAL';
      } else {
        newStatus = 'ACTIVE';
      }

      // ------------------------------------------------------
      // CREATE PAYMENT MAP
      // ------------------------------------------------------

      final paymentMap = payment.toMap();

      paymentMap['payment_date'] = paymentDate;

      paymentMap['amount'] = _cleanMoney(payment.amount);

      paymentMap['interest_amount'] = interestPaid;

      paymentMap['principal_amount'] = principalPaid;

      // ------------------------------------------------------
      // INSERT PAYMENT
      // ------------------------------------------------------

      final paymentId = await txn.insert(
        'loan_payments',
        paymentMap,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      // ------------------------------------------------------
      // UPDATE LOAN
      // ------------------------------------------------------

      await txn.update(
        'loans',
        {
          'paid_amount': newPaidAmount,
          'interest_amount': newInterestAmount,
          'accrued_interest': newAccruedInterest,
          'last_interest_date': paymentDate,
          'status': newStatus,
        },
        where: 'id = ?',
        whereArgs: [loan.id],
      );

      // ------------------------------------------------------
      // ACCOUNT TRANSACTION
      // ------------------------------------------------------

      final createdAt = DateTime.now().toIso8601String();

      final voucherNo =
          payment.voucherNo ?? 'LP-${paymentId.toString().padLeft(6, '0')}';

      if (loan.isGiven) {
        await txn.insert('account_transactions', {
          'account_id': payment.accountId,
          'transaction_type': 'LOAN_PAYMENT_RECEIVED',
          'reference_type': 'LOAN_PAYMENT',
          'reference_id': paymentId,
          'voucher_no': voucherNo,
          'debit': 0.0,
          'credit': _cleanMoney(payment.amount),
          'transaction_date': paymentDate,
          'note': payment.note,
          'created_at': createdAt,
        });
      } else {
        await txn.insert('account_transactions', {
          'account_id': payment.accountId,
          'transaction_type': 'LOAN_PAYMENT',
          'reference_type': 'LOAN_PAYMENT',
          'reference_id': paymentId,
          'voucher_no': voucherNo,
          'debit': _cleanMoney(payment.amount),
          'credit': 0.0,
          'transaction_date': paymentDate,
          'note': payment.note,
          'created_at': createdAt,
        });
      }

      // ------------------------------------------------------
      // INTEREST → INCOME / EXPENSE
      // ------------------------------------------------------

      if (interestPaid > _epsilon) {
        final interestVoucher =
            'LOAN-INT-${paymentId.toString().padLeft(6, '0')}';

        if (loan.isGiven) {
          await txn.insert('incomes', {
            'category': 'Loan Interest',
            'amount': interestPaid,
            'account_id': null,
            'income_date': paymentDate,
            'note': payment.note ?? 'Loan interest received',
            'created_at': createdAt,
            'voucher_no': interestVoucher,
          }, conflictAlgorithm: ConflictAlgorithm.abort);
        } else {
          await txn.insert('expenses', {
            'category': 'Loan Interest',
            'amount': interestPaid,
            'account_id': null,
            'expense_date': paymentDate,
            'note': payment.note ?? 'Loan interest paid',
            'created_at': createdAt,
            'voucher_no': interestVoucher,
          }, conflictAlgorithm: ConflictAlgorithm.abort);
        }
      }

      await _ffLoanPostingService.postLoanPaymentWithExecutor(
        txn,
        paymentId: paymentId,
        loanId: loan.id!,
        isGiven: loan.isGiven,
        accountId: payment.accountId!,
        totalAmount: _cleanMoney(payment.amount),
        principalAmount: principalPaid,
        interestAmount: interestPaid,
        voucherNo: voucherNo,
        transactionDate: paymentDate,
        note: payment.note,
      );

      return paymentId;
    });
  }

  // ============================================================
  // DELETE LOAN PAYMENT
  // ============================================================

  Future<void> deleteLoanPayment(int paymentId) async {
    final Database db = await _databaseHelper.database;

    await db.transaction((txn) async {
      // ------------------------------------------------------
      // LOAD PAYMENT
      // ------------------------------------------------------

      final paymentMaps = await txn.query(
        'loan_payments',
        where: 'id = ?',
        whereArgs: [paymentId],
        limit: 1,
      );

      if (paymentMaps.isEmpty) {
        throw StateError('Loan payment not found.');
      }

      final deletedPayment = LoanPayment.fromMap(paymentMaps.first);

      await _ffJournalService.deleteJournalByReferenceWithExecutor(
        txn,
        referenceType: 'LOAN_PAYMENT',
        referenceId: paymentId,
      );

      // ------------------------------------------------------
      // LOAD LOAN
      // ------------------------------------------------------

      final loanMaps = await txn.query(
        'loans',
        where: 'id = ?',
        whereArgs: [deletedPayment.loanId],
        limit: 1,
      );

      if (loanMaps.isEmpty) {
        throw StateError('Loan does not exist.');
      }

      final loan = Loan.fromMap(loanMaps.first);

      // ------------------------------------------------------
      // DELETE ACCOUNT TRANSACTION
      // ------------------------------------------------------

      await txn.delete(
        'account_transactions',
        where: '''
            reference_type = ?
            AND reference_id = ?
            AND transaction_type IN (?, ?)
          ''',
        whereArgs: [
          'LOAN_PAYMENT',
          paymentId,
          'LOAN_PAYMENT_RECEIVED',
          'LOAN_PAYMENT',
        ],
      );

      // ------------------------------------------------------
      // DELETE INTEREST INCOME
      // ------------------------------------------------------

      final interestVoucher =
          'LOAN-INT-${paymentId.toString().padLeft(6, '0')}';

      await txn.delete(
        'incomes',
        where: 'voucher_no = ?',
        whereArgs: [interestVoucher],
      );

      // ------------------------------------------------------
      // DELETE INTEREST EXPENSE
      // ------------------------------------------------------

      await txn.delete(
        'expenses',
        where: 'voucher_no = ?',
        whereArgs: [interestVoucher],
      );

      // ------------------------------------------------------
      // DELETE PAYMENT
      // ------------------------------------------------------

      await txn.delete(
        'loan_payments',
        where: 'id = ?',
        whereArgs: [paymentId],
      );

      // ------------------------------------------------------
      // LOAD REMAINING PAYMENTS
      // ------------------------------------------------------

      final remainingPayments = await txn.query(
        'loan_payments',
        where: 'loan_id = ?',
        whereArgs: [deletedPayment.loanId],
        orderBy: 'payment_date ASC, id ASC',
      );

      // ------------------------------------------------------
      // REBUILD LOAN STATE
      // ------------------------------------------------------

      double paidPrincipal = 0.0;
      double actualInterest = 0.0;
      double accruedInterest = 0.0;

      String lastInterestDate = _normalizeDate(loan.loanDate);

      for (final map in remainingPayments) {
        final p = LoanPayment.fromMap(map);

        final paymentDate = _normalizeDate(p.paymentDate);

        final remainingPrincipalBefore = loan.principalAmount - paidPrincipal;

        final days = _daysBetween(lastInterestDate, paymentDate);

        if (days < 0) {
          throw StateError('Invalid payment history.');
        }

        // ----------------------------------------------------
        // ACCRUE INTEREST
        // ----------------------------------------------------

        if (days > 0 &&
            remainingPrincipalBefore > _epsilon &&
            loan.interestRate > 0) {
          final dailyRate = loan.interestRate / 100 / 365;

          final newInterest = remainingPrincipalBefore * dailyRate * days;

          accruedInterest += newInterest;
        }

        accruedInterest = _cleanMoney(accruedInterest);

        // ----------------------------------------------------
        // PRINCIPAL PAYMENT
        // ----------------------------------------------------

        paidPrincipal += p.principalAmount;

        paidPrincipal = _cleanMoney(paidPrincipal);

        // ----------------------------------------------------
        // INTEREST PAYMENT
        // ----------------------------------------------------

        accruedInterest -= p.interestAmount;

        accruedInterest = _cleanMoney(accruedInterest);

        if (accruedInterest < _epsilon) {
          accruedInterest = 0.0;
        }

        actualInterest += p.interestAmount;

        actualInterest = _cleanMoney(actualInterest);

        lastInterestDate = paymentDate;
      }

      // ------------------------------------------------------
      // NEW STATUS
      // ------------------------------------------------------

      double remainingPrincipal = loan.principalAmount - paidPrincipal;

      remainingPrincipal = _cleanMoney(remainingPrincipal);

      String newStatus;

      if (remainingPrincipal <= _epsilon && accruedInterest <= _epsilon) {
        newStatus = 'PAID';
      } else if (paidPrincipal > _epsilon) {
        newStatus = 'PARTIAL';
      } else {
        newStatus = 'ACTIVE';
      }

      // ------------------------------------------------------
      // UPDATE LOAN
      // ------------------------------------------------------

      await txn.update(
        'loans',
        {
          'paid_amount': paidPrincipal,
          'interest_amount': actualInterest,
          'accrued_interest': accruedInterest,
          'last_interest_date': lastInterestDate,
          'status': newStatus,
        },
        where: 'id = ?',
        whereArgs: [loan.id],
      );
    });
  }

  // ============================================================
  // UPDATE LOAN
  // ============================================================

  Future<int> updateLoan(Loan loan) async {
    final Database db = await _databaseHelper.database;

    if (loan.id == null || loan.id! <= 0) {
      throw ArgumentError('Invalid loan ID.');
    }

    final existingMaps = await db.query(
      'loans',
      where: 'id = ?',
      whereArgs: [loan.id],
      limit: 1,
    );

    if (existingMaps.isEmpty) {
      throw StateError('Loan does not exist.');
    }

    final existing = Loan.fromMap(existingMaps.first);

    // ----------------------------------------------------------
    // DO NOT ALLOW ACCOUNT CHANGE
    // ----------------------------------------------------------

    if (existing.accountId != loan.accountId) {
      throw ArgumentError('Loan account cannot be changed after creation.');
    }

    // ----------------------------------------------------------
    // DO NOT ALLOW PRINCIPAL CHANGE IF PAYMENTS EXIST
    // ----------------------------------------------------------

    final paymentCountResult = await db.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM loan_payments
      WHERE loan_id = ?
      ''',
      [loan.id],
    );

    final paymentCount =
        (paymentCountResult.first['total'] as num?)?.toInt() ?? 0;

    if (paymentCount > 0 &&
        (existing.principalAmount - loan.principalAmount).abs() >
            _moneyTolerance) {
      throw ArgumentError(
        'Loan principal cannot be changed after payments have been recorded.',
      );
    }

    // ----------------------------------------------------------
    // BASIC VALIDATION
    // ----------------------------------------------------------

    final loanType = loan.loanType.toUpperCase();

    if (loanType != 'GIVEN' && loanType != 'TAKEN') {
      throw ArgumentError('Invalid loan type.');
    }

    if (loan.principalAmount <= 0) {
      throw ArgumentError('Loan amount must be greater than zero.');
    }

    if (loan.interestRate < 0) {
      throw ArgumentError('Interest rate cannot be negative.');
    }

    if (loan.accountId == null) {
      throw ArgumentError('Loan account is required.');
    }

    return await db.transaction((txn) async {
      final updated = await txn.update(
        'loans',
        {
          'loan_type': loanType,
          'person_name': loan.personName,
          'phone': loan.phone,
          'principal_amount': loan.principalAmount,
          'interest_rate': loan.interestRate,
          'interest_type': loan.interestType,
          'loan_date': _normalizeDate(loan.loanDate),
          'due_date': loan.dueDate,
          'account_id': existing.accountId,
          'payment_method': loan.paymentMethod,
          'note': loan.note,
        },
        where: 'id = ?',
        whereArgs: [loan.id],
      );

      await _ffJournalService.deleteJournalByReferenceWithExecutor(
        txn,
        referenceType: 'LOAN',
        referenceId: loan.id!,
      );

      await _ffLoanPostingService.postLoanWithExecutor(
        txn,
        loanId: loan.id!,
        loanType: loanType,
        accountId: existing.accountId!,
        principalAmount: _cleanMoney(loan.principalAmount),
        transactionDate: _normalizeDate(loan.loanDate),
        note: loan.note,
      );

      return updated;
    });
  }

  // ============================================================
  // DELETE LOAN
  // ============================================================

  Future<void> deleteLoan(int loanId) async {
    final Database db = await _databaseHelper.database;

    await db.transaction((txn) async {
      // ------------------------------------------------------
      // VERIFY LOAN
      // ------------------------------------------------------

      final loanMaps = await txn.query(
        'loans',
        where: 'id = ?',
        whereArgs: [loanId],
        limit: 1,
      );

      if (loanMaps.isEmpty) {
        throw StateError('Loan does not exist.');
      }

      // ------------------------------------------------------
      // LOAD PAYMENT IDS
      // ------------------------------------------------------

      final paymentMaps = await txn.query(
        'loan_payments',
        columns: ['id'],
        where: 'loan_id = ?',
        whereArgs: [loanId],
      );

      final paymentIds = paymentMaps
          .map((map) => (map['id'] as num).toInt())
          .toList();

      for (final paymentId in paymentIds) {
        await _ffJournalService.deleteJournalByReferenceWithExecutor(
          txn,
          referenceType: 'LOAN_PAYMENT',
          referenceId: paymentId,
        );
      }

      await _ffJournalService.deleteJournalByReferenceWithExecutor(
        txn,
        referenceType: 'LOAN',
        referenceId: loanId,
      );

      // ------------------------------------------------------
      // DELETE INTEREST INCOME / EXPENSE
      // ------------------------------------------------------

      for (final paymentId in paymentIds) {
        final interestVoucher =
            'LOAN-INT-${paymentId.toString().padLeft(6, '0')}';

        await txn.delete(
          'incomes',
          where: 'voucher_no = ?',
          whereArgs: [interestVoucher],
        );

        await txn.delete(
          'expenses',
          where: 'voucher_no = ?',
          whereArgs: [interestVoucher],
        );
      }

      // ------------------------------------------------------
      // DELETE ORIGINAL LOAN ACCOUNT TRANSACTION
      // ------------------------------------------------------

      await txn.delete(
        'account_transactions',
        where: '''
            reference_type = ?
            AND reference_id = ?
          ''',
        whereArgs: ['LOAN', loanId],
      );

      // ------------------------------------------------------
      // DELETE PAYMENT ACCOUNT TRANSACTIONS
      // ------------------------------------------------------

      await txn.delete(
        'account_transactions',
        where: '''
            reference_type = ?
            AND reference_id IN (
              SELECT id
              FROM loan_payments
              WHERE loan_id = ?
            )
          ''',
        whereArgs: ['LOAN_PAYMENT', loanId],
      );

      // ------------------------------------------------------
      // DELETE PAYMENTS
      // ------------------------------------------------------

      await txn.delete(
        'loan_payments',
        where: 'loan_id = ?',
        whereArgs: [loanId],
      );

      // ------------------------------------------------------
      // DELETE LOAN
      // ------------------------------------------------------

      await txn.delete('loans', where: 'id = ?', whereArgs: [loanId]);
    });
  }

  // ============================================================
  // TOTAL GIVEN PRINCIPAL
  // ============================================================

  Future<double> getTotalGivenPrincipal() async {
    final Database db = await _databaseHelper.database;

    final result = await db.rawQuery('''
      SELECT COALESCE(
        SUM(principal_amount),
        0
      ) AS total
      FROM loans
      WHERE loan_type = 'GIVEN'
      ''');

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // ============================================================
  // TOTAL TAKEN PRINCIPAL
  // ============================================================

  Future<double> getTotalTakenPrincipal() async {
    final Database db = await _databaseHelper.database;

    final result = await db.rawQuery('''
      SELECT COALESCE(
        SUM(principal_amount),
        0
      ) AS total
      FROM loans
      WHERE loan_type = 'TAKEN'
      ''');

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // ============================================================
  // OUTSTANDING GIVEN
  // ============================================================

  Future<double> getOutstandingGiven() async {
    final loans = await getGivenLoans();

    double total = 0.0;

    final today = DateTime.now().toIso8601String().split('T').first;

    for (final loan in loans) {
      if (loan.isPaid) {
        continue;
      }

      final accrued = await calculateAccruedInterest(
        loan.id!,
        calculationDate: today,
      );

      total += loan.remainingPrincipal + accrued;
    }

    return _cleanMoney(total);
  }

  // ============================================================
  // OUTSTANDING TAKEN
  // ============================================================

  Future<double> getOutstandingTaken() async {
    final loans = await getTakenLoans();

    double total = 0.0;

    final today = DateTime.now().toIso8601String().split('T').first;

    for (final loan in loans) {
      if (loan.isPaid) {
        continue;
      }

      final accrued = await calculateAccruedInterest(
        loan.id!,
        calculationDate: today,
      );

      total += loan.remainingPrincipal + accrued;
    }

    return _cleanMoney(total);
  }

  // ============================================================
  // TOTAL ACTUAL GIVEN INTEREST
  // ============================================================

  Future<double> getTotalGivenInterest() async {
    final Database db = await _databaseHelper.database;

    final result = await db.rawQuery('''
      SELECT COALESCE(
        SUM(interest_amount),
        0
      ) AS total
      FROM loans
      WHERE loan_type = 'GIVEN'
      ''');

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // ============================================================
  // TOTAL ACTUAL TAKEN INTEREST
  // ============================================================

  Future<double> getTotalTakenInterest() async {
    final Database db = await _databaseHelper.database;

    final result = await db.rawQuery('''
      SELECT COALESCE(
        SUM(interest_amount),
        0
      ) AS total
      FROM loans
      WHERE loan_type = 'TAKEN'
      ''');

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // ============================================================
  // GENERATE PAYMENT VOUCHER
  // ============================================================

  Future<String> generatePaymentVoucher() async {
    final Database db = await _databaseHelper.database;

    final result = await db.rawQuery('''
      SELECT COUNT(*) AS total
      FROM loan_payments
      ''');

    final total = (result.first['total'] as num?)?.toInt() ?? 0;

    return 'LP-${(total + 1).toString().padLeft(6, '0')}';
  }
}
