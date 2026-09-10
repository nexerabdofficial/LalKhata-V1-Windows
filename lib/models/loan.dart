class Loan {
  final int? id;

  /// GIVEN = আমরা অন্যকে টাকা দিয়েছি
  /// TAKEN = আমরা অন্যের কাছ থেকে টাকা নিয়েছি
  final String loanType;

  final String personName;
  final String? phone;

  /// Original loan principal
  final double principalAmount;

  /// Annual interest percentage
  /// Example: 12 = 12% per year
  final double interestRate;

  /// Currently supported:
  /// ANNUAL
  final String interestType;

  /// Loan start date
  final String loanDate;

  /// Optional due date
  final String? dueDate;

  /// Account from which loan was given / received
  final int? accountId;

  /// Cash / Bank / Mobile Banking
  final String? paymentMethod;

  /// Total principal already paid/repaid
  final double paidAmount;

  /// Interest that has ACTUALLY been paid/received
  ///
  /// IMPORTANT:
  /// This is NOT accrued interest.
  ///
  /// Accrued interest remains separate until actual payment.
  final double interestAmount;

  /// Interest accumulated but NOT yet paid/received.
  ///
  /// Example:
  /// Principal = 50,000
  /// Rate = 12%
  /// 1 day = 16.44
  ///
  /// accruedInterest = 16.44
  final double accruedInterest;

  /// Last date up to which interest was calculated.
  ///
  /// This prevents calculating the same day's interest twice.
  final String? lastInterestDate;

  /// ACTIVE / PARTIAL / PAID
  final String status;

  final String? note;

  final String createdAt;

  const Loan({
    this.id,

    required this.loanType,

    required this.personName,

    this.phone,

    required this.principalAmount,

    required this.interestRate,

    required this.interestType,

    required this.loanDate,

    this.dueDate,

    this.accountId,

    this.paymentMethod,

    required this.paidAmount,

    required this.interestAmount,

    required this.accruedInterest,

    this.lastInterestDate,

    required this.status,

    this.note,

    required this.createdAt,
  });

  // ============================================================
  // TO MAP
  // ============================================================

  Map<String, dynamic> toMap() {
    return {
      'id': id,

      'loan_type': loanType,

      'person_name': personName,

      'phone': phone,

      'principal_amount': principalAmount,

      'interest_rate': interestRate,

      'interest_type': interestType,

      'loan_date': loanDate,

      'due_date': dueDate,

      'account_id': accountId,

      'payment_method': paymentMethod,

      'paid_amount': paidAmount,

      'interest_amount': interestAmount,

      'accrued_interest': accruedInterest,

      'last_interest_date': lastInterestDate,

      'status': status,

      'note': note,

      'created_at': createdAt,
    };
  }

  // ============================================================
  // FROM MAP
  // ============================================================

  factory Loan.fromMap(
    Map<String, dynamic> map,
  ) {
    return Loan(
      id: map['id'] as int?,

      loanType:
          map['loan_type'] as String,

      personName:
          map['person_name'] as String,

      phone:
          map['phone'] as String?,

      principalAmount:
          (map['principal_amount'] as num)
              .toDouble(),

      interestRate:
          (map['interest_rate'] as num?)
                  ?.toDouble() ??
              0.0,

      interestType:
          map['interest_type'] as String? ??
              'ANNUAL',

      loanDate:
          map['loan_date'] as String,

      dueDate:
          map['due_date'] as String?,

      accountId:
          (map['account_id'] as num?)?.toInt(),

      paymentMethod:
          map['payment_method'] as String?,

      paidAmount:
          (map['paid_amount'] as num?)
                  ?.toDouble() ??
              0.0,

      interestAmount:
          (map['interest_amount'] as num?)
                  ?.toDouble() ??
              0.0,

      accruedInterest:
          (map['accrued_interest'] as num?)
                  ?.toDouble() ??
              0.0,

      lastInterestDate:
          map['last_interest_date'] as String?,

      status:
          map['status'] as String? ??
              'ACTIVE',

      note:
          map['note'] as String?,

      createdAt:
          map['created_at'] as String,
    );
  }

  // ============================================================
  // REMAINING PRINCIPAL
  // ============================================================

  double get remainingPrincipal {
    final remaining =
        principalAmount - paidAmount;

    return remaining < 0
        ? 0.0
        : remaining;
  }

  // ============================================================
  // TOTAL OUTSTANDING
  //
  // Principal + unpaid accrued interest
  // ============================================================

  double get totalOutstanding {
    return remainingPrincipal +
        accruedInterest;
  }

  // ============================================================
  // WHETHER PRINCIPAL IS FULLY PAID
  // ============================================================

  bool get isPrincipalPaid {
    return remainingPrincipal <=
        0.000001;
  }

  // ============================================================
  // WHETHER EVERYTHING IS SETTLED
  //
  // Principal must be zero AND
  // accrued interest must be zero.
  // ============================================================

  bool get isPaid {
    return remainingPrincipal <=
            0.000001 &&
        accruedInterest <=
            0.000001;
  }

  // ============================================================
  // LOAN TYPE
  // ============================================================

  bool get isGiven {
    final type =
        loanType.toUpperCase();

    return type == 'GIVEN' ||
        type == 'LOAN_GIVEN';
  }

  bool get isTaken {
    final type =
        loanType.toUpperCase();

    return type == 'TAKEN' ||
        type == 'LOAN_TAKEN';
  }

  // ============================================================
  // DAILY INTEREST
  //
  // Annual rate / 365
  // ============================================================

  double get dailyInterestRate {
    return interestRate / 100 / 365;
  }

  // ============================================================
  // DAILY INTEREST AMOUNT
  // ============================================================

  double get dailyInterestAmount {
    return remainingPrincipal *
        dailyInterestRate;
  }
}