import 'package:flutter/foundation.dart';
import 'package:membership_tracker/models.dart';
import 'package:membership_tracker/services/sheets_service.dart';

class ClubController extends ChangeNotifier {
  final SheetsService _sheetsService;

  static const double classPrice = 10.0;

  ClubController(this._sheetsService) {
    _sheetsService.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate() {
    // Re-calculate balances whenever data changes
    _recalculateBalances();
    notifyListeners();
  }

  // Expose data
  bool get isLoading => !_sheetsService.isSignedIn; // Simplified state
  bool get isSignedIn => _sheetsService.isSignedIn;
  List<Member> get members => _sheetsService.members;
  List<Transaction> get transactions => _sheetsService.transactions;
  List<ClassAttendance> get attendance => _sheetsService.attendance;

  Future<void> init() async {
    await _sheetsService.init();
  }

  Future<void> signIn() => _sheetsService.signIn();
  Future<void> signOut() => _sheetsService.signOut();

  Map<String, double> _memberBalances = {};

  double getMemberBalance(String memberId) {
    return _memberBalances[memberId] ?? 0.0;
  }

  // Data actions
  Future<void> addMember(
    String firstName,
    String lastName,
    DateTime dob,
    String medical,
    String contact,
  ) async {
    final member = Member.create(
      firstName: firstName,
      lastName: lastName,
      dob: dob,
      medicalInfo: medical,
      contactInfo: contact,
    );
    await _sheetsService.addMember(member);
  }

  Future<void> recordPayment(
    String memberId,
    double amount,
    String description,
  ) async {
    final transaction = Transaction.create(
      memberId: memberId,
      amount: amount,
      description: description,
    );
    await _sheetsService.addTransaction(transaction);
  }

  Future<void> checkIn(String memberId, String classType) async {
    final checkIn = ClassAttendance.create(
      memberId: memberId,
      classType: classType,
    );
    await _sheetsService.addAttendance(checkIn);
  }

  void _recalculateBalances() {
    _memberBalances = {};

    // Initialize with 0
    for (var m in members) {
      _memberBalances[m.id] = 0.0;
    }

    // Add Payments
    for (var t in transactions) {
      _memberBalances[t.memberId] =
          (_memberBalances[t.memberId] ?? 0) + t.amount;
    }

    // Subtract Class Costs
    // To handle Wed rule (max 1 charge per day), we need to group attendance by Member AND Date
    // Map<MemberId, Map<DateString, List<ClassAttendance>>>

    final Map<String, Map<String, List<ClassAttendance>>>
    attendanceByMemberDate = {};

    for (var a in attendance) {
      final dateKey = "${a.date.year}-${a.date.month}-${a.date.day}";

      if (!attendanceByMemberDate.containsKey(a.memberId)) {
        attendanceByMemberDate[a.memberId] = {};
      }

      // Fix:
      attendanceByMemberDate[a.memberId]!.putIfAbsent(dateKey, () => []).add(a);
    }

    // Calculate cost
    attendanceByMemberDate.forEach((memberId, dateMap) {
      dateMap.forEach((date, dailyClasses) {
        double dailyCost = 0;

        bool isWednesday = false;
        if (dailyClasses.isNotEmpty) {
          // Check if it was a Wednesday.
          // Weekday: Mon=1, Wed=3, Fri=5
          if (dailyClasses.first.date.weekday == 3) {
            isWednesday = true;
          }
        }

        if (isWednesday) {
          // Rule: Pay for one class max
          // If attended >= 1, cost is classPrice
          if (dailyClasses.isNotEmpty) {
            dailyCost = classPrice;
          }
        } else {
          // Normal rule (e.g. Friday or other): Pay per class
          dailyCost = dailyClasses.length * classPrice;
        }

        _memberBalances[memberId] =
            (_memberBalances[memberId] ?? 0) - dailyCost;
      });
    });
  }
}
