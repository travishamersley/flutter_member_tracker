import 'package:membership_tracker/models.dart';

void main() {
  // Mock Data
  final memberA = Member(
    id: "A",
    firstName: "A",
    lastName: "Fam",
    dob: DateTime.now(),
    medicalInfo: "",
    contactInfo: "",
    familyGroupId: "fam1",
    balance: 0,
  );
  final memberB = Member(
    id: "B",
    firstName: "B",
    lastName: "Fam",
    dob: DateTime.now(),
    medicalInfo: "",
    contactInfo: "",
    familyGroupId: "fam1",
    balance: 0,
  );
  final members = [memberA, memberB];

  // Transactions
  // Member A Check In and Pay TWICE ($20 total)
  final t1 = Transaction(
    id: "t1",
    memberId: "A",
    amount: 10.0,
    date: DateTime.now(),
    description: "Pay 1",
  );
  final t2 = Transaction(
    id: "t2",
    memberId: "A",
    amount: 10.0,
    date: DateTime.now(),
    description: "Pay 2",
  );
  final transactions = [t1, t2];

  // Attendance
  // Member A Check In (Wed) TWICE
  // 2026-02-04 is Wed
  final d = DateTime(2026, 2, 4, 10, 0);
  final a1 = ClassAttendance(
    id: "a1",
    memberId: "A",
    date: d,
    classType: "Class 1",
  );
  final a2 = ClassAttendance(
    id: "a2",
    memberId: "A",
    date: d,
    classType: "Class 2",
  );
  final attendance = [a1, a2];

  // Recalculate Logic (Copy-Paste from Controller)
  Map<String, double> _memberBalances = {};

  // 1. Calculate Raw Individual Balances
  Map<String, double> rawBalances = {};

  // Initialize with 0
  for (var m in members) {
    rawBalances[m.id] = 0.0;
  }

  // Add Payments
  for (var t in transactions) {
    rawBalances[t.memberId] = (rawBalances[t.memberId] ?? 0) + t.amount;
  }

  // Subtract Class Costs
  final Map<String, Map<String, List<ClassAttendance>>> attendanceByMemberDate =
      {};

  for (var a in attendance) {
    final dateKey = "${a.date.year}-${a.date.month}-${a.date.day}";

    if (!attendanceByMemberDate.containsKey(a.memberId)) {
      attendanceByMemberDate[a.memberId] = {};
    }
    attendanceByMemberDate[a.memberId]!.putIfAbsent(dateKey, () => []).add(a);
  }

  double classPrice = 10.0;

  attendanceByMemberDate.forEach((memberId, dateMap) {
    dateMap.forEach((date, dailyClasses) {
      double dailyCost = 0;
      bool isWednesday = false;

      if (dailyClasses.isNotEmpty) {
        // Weekday: Mon=1, Wed=3, Fri=5
        if (dailyClasses.first.date.weekday == 3) {
          isWednesday = true;
        }
      }

      if (isWednesday) {
        // Rule: Pay for one class max
        if (dailyClasses.isNotEmpty) {
          dailyCost = classPrice;
        }
      } else {
        // Normal rule: Pay per class
        dailyCost = dailyClasses.length * classPrice;
      }

      rawBalances[memberId] = (rawBalances[memberId] ?? 0) - dailyCost;
    });
  });

  // 2. Aggregate by Family Group
  // Map<FamilyGroupId, TotalBalance>
  Map<String, double> familyTotals = {};

  for (var m in members) {
    if (m.familyGroupId != null && m.familyGroupId!.isNotEmpty) {
      familyTotals[m.familyGroupId!] =
          (familyTotals[m.familyGroupId!] ?? 0) + (rawBalances[m.id] ?? 0);
    }
  }

  // 3. Assign Balances
  for (var m in members) {
    if (m.familyGroupId != null && m.familyGroupId!.isNotEmpty) {
      // Member is in a family -> balance is the family total
      _memberBalances[m.id] = familyTotals[m.familyGroupId!] ?? 0.0;
    } else {
      // Individual
      _memberBalances[m.id] = rawBalances[m.id] ?? 0.0;
    }
  }

  print("Member A Balance: ${_memberBalances["A"]}");
  print("Member B Balance: ${_memberBalances["B"]}");
  print("Raw A: ${rawBalances["A"]}");
}
