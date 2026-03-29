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
  List<ClassSession> get sessions =>
      List.of(_sheetsService.classSessions)
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

  String? get spreadsheetUrl => _sheetsService.spreadsheetUrl;
  String? get lastError => _sheetsService.lastError;

  // Lifecycle Getters
  ClassSession? get activeSession {
    try {
      // Find the most recent session that is NOT completed
      // Since 'sessions' is sorted DESC, we check first ones.
      // But we should strictly allow only one?
      // For now, if there are multiple open, returning the latest is safest.
      return sessions.firstWhere((s) => !s.isCompleted);
    } catch (_) {
      return null;
    }
  }

  List<ClassSession> get pastSessions =>
      sessions.where((s) => s.isCompleted).toList();

  Future<void> init() async {
    await _sheetsService.init();
  }

  Future<void> signIn() => _sheetsService.signIn();
  Future<void> signOut() => _sheetsService.signOut();

  // --- Manual Sync ---
  bool isSyncing = false;
  Future<void> sync() async {
    if (isSyncing) return;
    isSyncing = true;
    notifyListeners();

    try {
      // Revert to simple data fetch
      debugPrint('ClubController: Calling _sheetsService.syncData()');
      await _sheetsService.syncData();
      debugPrint('ClubController: _sheetsService.syncData() completed');
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  Map<String, double> _memberBalances = {};

  double getMemberBalance(String memberId) {
    return _memberBalances[memberId] ?? 0.0;
  }

  // Data actions
  Future<void> addMember(
    String firstName,
    String lastName,
    String address,
    String email,
    DateTime dob,
    String mobile,
    String homePhone,
    String emergencyContact,
    MedicalHistory medicalHistory,
    bool hasBeenSuspended,
    String? suspendedDetails,
    String heardAbout,
    String? legalGuardian,
    bool consentSigned,
  ) async {
    final member = Member.create(
      firstName: firstName,
      lastName: lastName,
      address: address,
      email: email,
      dob: dob,
      mobile: mobile,
      homePhone: homePhone,
      emergencyContact: emergencyContact,
      medicalHistory: medicalHistory,
      hasBeenSuspended: hasBeenSuspended,
      suspendedDetails: suspendedDetails,
      heardAbout: heardAbout,
      legalGuardian: legalGuardian,
      consentSigned: consentSigned,
    );
    await _sheetsService.addMember(member);
  }

  Future<void> recordPayment(
    String memberId,
    double amount,
    String description, [
    String? classSessionId,
  ]) async {
    final transaction = Transaction.create(
      memberId: memberId,
      amount: amount,
      description: description,
      classSessionId: classSessionId,
    );
    await _sheetsService.addTransaction(transaction);
  }

  Future<void> checkIn(String memberId, String classSessionId) async {
    final checkIn = ClassAttendance.create(
      memberId: memberId,
      classSessionId: classSessionId,
    );
    await _sheetsService.addAttendance(checkIn);
  }

  Future<void> checkInAndPay(
    String memberId,
    String classSessionId,
    double amount,
  ) async {
    await recordPayment(memberId, amount, "Class Payment", classSessionId);
    await checkIn(memberId, classSessionId);
  }

  Future<void> createClassForNow() async {
    // If there is already an active session, maybe we should auto-close it?
    // Or just let user create another one (no restriction requested).
    // But good UX suggests checking.
    // Proceeding to create.

    final now = DateTime.now();
    // Helper to format: "Wednesday 5:00 PM"
    final days = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };
    final dayName = days[now.weekday];
    final hour = now.hour > 12
        ? now.hour - 12
        : (now.hour == 0 ? 12 : now.hour);
    final amPm = now.hour >= 12 ? 'PM' : 'AM';
    final minuteToken = now.minute.toString().padLeft(2, '0');
    final name = "$dayName ${now.month}/${now.day} - $hour:$minuteToken $amPm";

    final session = ClassSession.create(name: name);
    await _sheetsService.addClassSession(session);
  }

  Future<void> endClass(ClassSession session) async {
    final updated = ClassSession(
      id: session.id,
      name: session.name,
      dateTime: session.dateTime,
      isCompleted: true,
    );
    await _sheetsService.updateClassSession(updated);
  }

  void _recalculateBalances() {
    debugPrint("Recalculating Balances...");
    _memberBalances = {};

    // 1. Calculate Raw Individual Balances
    Map<String, double> rawBalances = {};

    // Initialize with 0
    for (var m in members) {
      rawBalances[m.id] = 0.0;
    }

    // Add Payments
    debugPrint("Processing ${transactions.length} transactions for balances.");
    for (var t in transactions) {
      if (rawBalances.containsKey(t.memberId)) {
        rawBalances[t.memberId] = (rawBalances[t.memberId] ?? 0) + t.amount;
      } else {
        // Transaction for unknown member?
        debugPrint("Warning: Transaction for unknown memberId: ${t.memberId}");
      }
    }

    // Subtract Class Costs
    // New Logic: 1 Attendance = 1 Charge (classPrice)
    debugPrint(
      "Processing ${attendance.length} attendance records for charges.",
    );
    for (var a in attendance) {
      if (rawBalances.containsKey(a.memberId)) {
        if (a.classSessionId != null && a.classSessionId!.isNotEmpty) {
          // Valid new session attendance
          rawBalances[a.memberId] = (rawBalances[a.memberId] ?? 0) - classPrice;
        } else {
          // Legacy attendance counts too
          rawBalances[a.memberId] = (rawBalances[a.memberId] ?? 0) - classPrice;
        }
      }
    }

    // Debug output a few balances
    // rawBalances.forEach((k, v) => debugPrint("Member $k Raw Balance: $v"));

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
      // Update the member object's ephemeral balance field if needed for UI (though UI uses controller getter usually)
      m.balance = _memberBalances[m.id] ?? 0.0;
    }
    debugPrint("Balance recalculation complete.");
  }

  // Family Management

  Future<void> createFamilyGroup(Member initiator, List<Member> others) async {
    // We need a unique ID for the family.
    // Since we don't import uuid here, let's reuse the initiator's ID + timestamp or something,
    // OR we can just modify models.dart to export Uuid, or import it here.
    // Ideally we should import uuid. I'll stick to a simple unique string generation for now or assume Uuid is available if I add import.
    // Actually, let's just use a simple random string generator since we don't want to break imports if not needed,
    // BUT we are already using models.dart which uses uuid.
    // Let's just use DateTime.now().millisecondsSinceEpoch.toString() + initiator.id; somewhat unique.
    // Better: import uuid. But I can't easily add import top of file with replace_file_content unless I do whole file.
    // I'll assume I can add the import later or use a workaround.
    // Workaround: `const Uuid().v4()` is standard but needs import.
    // I'll stick to string concatenation for uniqueness for now to avoid import hassle in this specific tool call?
    // No, I should do it right. I will add the import in a separate call if needed, or just use a simple unique string.
    final String newFamilyId =
        "fam_${DateTime.now().millisecondsSinceEpoch}_${initiator.id.substring(0, 4)}";

    // Update initiator
    initiator.familyGroupId = newFamilyId;
    await _sheetsService.updateMember(
      initiator,
    ); // We need updateMember in SheetsService!

    // Update others
    for (var m in others) {
      m.familyGroupId = newFamilyId;
      await _sheetsService.updateMember(m);
    }

    _recalculateBalances();
    notifyListeners();
  }

  Future<void> addToFamilyGroup(Member member, String familyGroupId) async {
    member.familyGroupId = familyGroupId;
    await _sheetsService.updateMember(member);
    _recalculateBalances();
    notifyListeners();
  }

  Future<void> removeFromFamilyGroup(Member member) async {
    member.familyGroupId = null;
    await _sheetsService.updateMember(member); // Will write empty string
    _recalculateBalances();
    notifyListeners();
  }
}
