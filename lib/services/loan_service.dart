import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/loan.dart';
import '../models/loan_payment.dart';
import '../repositories/loan_repository.dart';

class LoanService {
  LoanService._();

  static final LoanService instance =
      LoanService._();

  final DatabaseHelper _databaseHelper =
      DatabaseHelper.instance;

  final LoanRepository _loanRepository =
      LoanRepository();

  // ============================================================
  // CREATE LOAN
  // ============================================================

  Future<int> createLoan({
    required Loan loan,
  }) async {
    // ----------------------------------------------------------
    // Principal validation
    // ----------------------------------------------------------

    if (loan.principalAmount <= 0) {
      throw ArgumentError(
        'Loan amount must be greater than zero.',
      );
    }

    // ----------------------------------------------------------
    // Interest validation
    // ----------------------------------------------------------

    if (loan.interestRate < 0) {
      throw ArgumentError(
        'Interest rate cannot be negative.',
      );
    }

    // ----------------------------------------------------------
    // Account validation
    // ----------------------------------------------------------

    if (loan.accountId == null) {
      throw ArgumentError(
        'Payment account is required.',
      );
    }

    // ----------------------------------------------------------
    // Loan type validation
    // ----------------------------------------------------------

    final loanType =
        loan.loanType.toUpperCase();

    if (loanType != 'GIVEN' &&
        loanType != 'TAKEN' &&
        loanType != 'LOAN_GIVEN' &&
        loanType != 'LOAN_TAKEN') {
      throw ArgumentError(
        'Invalid loan type.',
      );
    }

    // ----------------------------------------------------------
    // New loan should not already have payment
    // ----------------------------------------------------------

    if (loan.paidAmount.abs() >
        0.000001) {
      throw ArgumentError(
        'New loan cannot have paid principal.',
      );
    }

    if (loan.interestAmount.abs() >
        0.000001) {
      throw ArgumentError(
        'New loan cannot have paid interest.',
      );
    }

    if (loan.accruedInterest.abs() >
        0.000001) {
      throw ArgumentError(
        'New loan cannot have accrued interest.',
      );
    }

    return await _loanRepository.insertLoan(
      loan,
    );
  }

  // ============================================================
  // GET ALL LOANS
  // ============================================================

  Future<List<Loan>> getLoans() async {
    return await _loanRepository.getLoans();
  }

  // ============================================================
  // GET ACTIVE LOANS
  // ============================================================

  Future<List<Loan>> getActiveLoans() async {
    return await _loanRepository.getActiveLoans();
  }

  // ============================================================
  // GET GIVEN LOANS
  // ============================================================

  Future<List<Loan>> getGivenLoans() async {
    return await _loanRepository.getGivenLoans();
  }

  // ============================================================
  // GET TAKEN LOANS
  // ============================================================

  Future<List<Loan>> getTakenLoans() async {
    return await _loanRepository.getTakenLoans();
  }

  // ============================================================
  // GET SINGLE LOAN
  // ============================================================

  Future<Loan?> getLoanById(
    int loanId,
  ) async {
    if (loanId <= 0) {
      throw ArgumentError(
        'Invalid loan ID.',
      );
    }

    return await _loanRepository.getLoanById(
      loanId,
    );
  }

  // ============================================================
  // GET ACCOUNTS
  // ============================================================

  Future<List<Map<String, dynamic>>>
      getAccounts() async {
    final db =
        await _databaseHelper.database;

    return await db.query(
      'accounts',
      orderBy: 'id ASC',
    );
  }

  // ============================================================
  // GET LOAN PAYMENTS
  // ============================================================

  Future<List<LoanPayment>> getLoanPayments(
    int loanId,
  ) async {
    if (loanId <= 0) {
      throw ArgumentError(
        'Invalid loan ID.',
      );
    }

    return await _loanRepository
        .getLoanPayments(loanId);
  }

  // ============================================================
  // GET SINGLE PAYMENT
  // ============================================================

  Future<LoanPayment?> getLoanPaymentById(
    int paymentId,
  ) async {
    if (paymentId <= 0) {
      throw ArgumentError(
        'Invalid payment ID.',
      );
    }

    return await _loanRepository
        .getLoanPaymentById(paymentId);
  }

  // ============================================================
  // CALCULATE CURRENT ACCRUED INTEREST
  //
  // This does NOT save anything.
  //
  // Example:
  //
  // Principal = 50,000
  // Rate = 12%
  // Last interest date = yesterday
  // Today = today
  //
  // 50,000 × 12% ÷ 365
  // = 16.44
  // ============================================================

  Future<double> getAccruedInterest(
    int loanId, {
    String? calculationDate,
  }) async {
    if (loanId <= 0) {
      throw ArgumentError(
        'Invalid loan ID.',
      );
    }

    return await _loanRepository
        .calculateAccruedInterest(
      loanId,
      calculationDate:
          calculationDate,
    );
  }

  // ============================================================
  // GET TOTAL OUTSTANDING
  //
  // Principal outstanding
  // +
  // Current accrued interest
  // ============================================================

  Future<double> getTotalOutstanding(
    int loanId, {
    String? calculationDate,
  }) async {
    final loan =
        await getLoanById(loanId);

    if (loan == null) {
      throw StateError(
        'Loan does not exist.',
      );
    }

    final accrued =
        await getAccruedInterest(
      loanId,
      calculationDate:
          calculationDate,
    );

    return loan.remainingPrincipal +
        accrued;
  }

  // ============================================================
  // ADD LOAN PAYMENT
  //
  // IMPORTANT:
  //
  // Payment allocation is explicit.
  //
  // principalAmount = principal being paid
  // interestAmount  = interest actually paid
  //
  // Accrued interest does NOT automatically become
  // income/expense until it is actually paid/received.
  // ============================================================

  Future<int> addLoanPayment({
    required LoanPayment payment,
  }) async {
    // ----------------------------------------------------------
    // Basic validation
    // ----------------------------------------------------------

    if (payment.loanId <= 0) {
      throw ArgumentError(
        'Invalid loan ID.',
      );
    }

    if (payment.amount <= 0) {
      throw ArgumentError(
        'Payment amount must be greater than zero.',
      );
    }

    if (payment.principalAmount < 0) {
      throw ArgumentError(
        'Principal amount cannot be negative.',
      );
    }

    if (payment.interestAmount < 0) {
      throw ArgumentError(
        'Interest amount cannot be negative.',
      );
    }

    // ----------------------------------------------------------
    // Account required
    // ----------------------------------------------------------

    if (payment.accountId == null) {
      throw ArgumentError(
        'Payment account is required.',
      );
    }

    // ----------------------------------------------------------
    // Principal + interest = total payment
    // ----------------------------------------------------------

    final calculatedAmount =
        payment.principalAmount +
            payment.interestAmount;

    if ((calculatedAmount -
                payment.amount)
            .abs() >
        0.01) {
      throw ArgumentError(
        'Principal + interest must equal payment amount.',
      );
    }

    // ----------------------------------------------------------
    // Get loan
    // ----------------------------------------------------------

    final loan =
        await getLoanById(payment.loanId);

    if (loan == null) {
      throw StateError(
        'Loan does not exist.',
      );
    }

    // ----------------------------------------------------------
    // Principal validation
    // ----------------------------------------------------------

    if (payment.principalAmount >
        loan.remainingPrincipal +
            0.000001) {
      throw ArgumentError(
        'Principal payment exceeds remaining principal.',
      );
    }

    // ----------------------------------------------------------
    // Prevent payment after fully settled loan
    // ----------------------------------------------------------

    if (loan.isPaid) {
      throw StateError(
        'This loan is already fully settled.',
      );
    }

    // ----------------------------------------------------------
    // Repository performs transaction
    // ----------------------------------------------------------

    return await _loanRepository
        .insertLoanPayment(
      payment,
    );
  }

  // ============================================================
  // DELETE LOAN PAYMENT
  // ============================================================

  Future<void> deleteLoanPayment(
    int paymentId,
  ) async {
    if (paymentId <= 0) {
      throw ArgumentError(
        'Invalid payment ID.',
      );
    }

    await _loanRepository
        .deleteLoanPayment(paymentId);
  }

  // ============================================================
  // UPDATE LOAN
  //
  // Financial history should not be silently changed.
  // ============================================================

  Future<int> updateLoan(
    Loan loan,
  ) async {
    if (loan.id == null ||
        loan.id! <= 0) {
      throw ArgumentError(
        'Invalid loan ID.',
      );
    }

    if (loan.principalAmount <= 0) {
      throw ArgumentError(
        'Loan amount must be greater than zero.',
      );
    }

    if (loan.interestRate < 0) {
      throw ArgumentError(
        'Interest rate cannot be negative.',
      );
    }

    if (loan.accountId == null) {
      throw ArgumentError(
        'Payment account is required.',
      );
    }

    final loanType =
        loan.loanType.toUpperCase();

    if (loanType != 'GIVEN' &&
        loanType != 'TAKEN' &&
        loanType != 'LOAN_GIVEN' &&
        loanType != 'LOAN_TAKEN') {
      throw ArgumentError(
        'Invalid loan type.',
      );
    }

    return await _loanRepository.updateLoan(
      loan,
    );
  }

  // ============================================================
  // DELETE LOAN
  // ============================================================

  Future<void> deleteLoan(
    int loanId,
  ) async {
    if (loanId <= 0) {
      throw ArgumentError(
        'Invalid loan ID.',
      );
    }

    await _loanRepository.deleteLoan(
      loanId,
    );
  }

  // ============================================================
  // TOTAL GIVEN PRINCIPAL
  // ============================================================

  Future<double>
      getTotalGivenPrincipal() async {
    return await _loanRepository
        .getTotalGivenPrincipal();
  }

  // ============================================================
  // TOTAL TAKEN PRINCIPAL
  // ============================================================

  Future<double>
      getTotalTakenPrincipal() async {
    return await _loanRepository
        .getTotalTakenPrincipal();
  }

  // ============================================================
  // OUTSTANDING GIVEN
  // ============================================================

  Future<double>
      getOutstandingGiven() async {
    return await _loanRepository
        .getOutstandingGiven();
  }

  // ============================================================
  // OUTSTANDING TAKEN
  // ============================================================

  Future<double>
      getOutstandingTaken() async {
    return await _loanRepository
        .getOutstandingTaken();
  }

  // ============================================================
  // TOTAL GIVEN INTEREST
  // ============================================================

  Future<double>
      getTotalGivenInterest() async {
    return await _loanRepository
        .getTotalGivenInterest();
  }

  // ============================================================
  // TOTAL TAKEN INTEREST
  // ============================================================

  Future<double>
      getTotalTakenInterest() async {
    return await _loanRepository
        .getTotalTakenInterest();
  }

  // ============================================================
  // GENERATE PAYMENT VOUCHER
  // ============================================================

  Future<String>
      generatePaymentVoucher() async {
    return await _loanRepository
        .generatePaymentVoucher();
  }
}