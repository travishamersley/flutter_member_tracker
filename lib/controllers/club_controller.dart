import 'package:flutter/foundation.dart';
import 'package:membership_tracker/models.dart';
import 'package:membership_tracker/services/local_storage_service.dart';
import 'package:membership_tracker/services/data_exchange_service.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class ClubController extends ChangeNotifier {
  final LocalStorageService _localStorage = LocalStorageService();
  final DataExchangeService _dataExchangeService = DataExchangeService();

  List<PriceRule> priceRules = [];
  String consentDocumentText = "I agree to participate and understand the risks involved.";

  double getCurrentClassPrice(DateTime date) {
    if (priceRules.isEmpty) return 6.0;
    final pastRules = priceRules.where((r) => r.effectiveDate.isBefore(date) || r.effectiveDate.isAtSameMomentAs(date)).toList();
    if (pastRules.isEmpty) return priceRules.first.price;
    pastRules.sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));
    return pastRules.first.price;
  }

  bool isLoading = true;
  String? lastError;

  // Data
  List<Member> members = [];
  List<Transaction> transactions = [];
  List<ClassAttendance> attendance = [];
  List<ClassSession> classSessions = [];
  List<GradeLevel> gradeLevels = [];
  List<StudentGrade> studentGrades = [];

  List<ClassSession> get sessions =>
      List.of(classSessions)..sort((a, b) => b.dateTime.compareTo(a.dateTime));

  ClassSession? get activeSession {
    try {
      return sessions.firstWhere((s) => !s.isCompleted);
    } catch (_) {
      return null;
    }
  }

  List<ClassSession> get pastSessions =>
      sessions.where((s) => s.isCompleted).toList();

  Future<void> init() async {
    isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();

      final rulesJson = prefs.getStringList('priceRules');
      if (rulesJson != null) {
        priceRules = rulesJson.map((r) => PriceRule.fromJson(jsonDecode(r))).toList();
      } else {
        priceRules = [PriceRule.create(price: 6.0, effectiveDate: DateTime(2000, 1, 1))];
      }

      consentDocumentText = prefs.getString('consentDocumentText') ??
          "I agree to participate and understand the risks involved. I release the club from any liability regarding injuries sustained during training.";

      final data = await _localStorage.loadAllData();
      members = data['members'] as List<Member>? ?? [];
      transactions = data['transactions'] as List<Transaction>? ?? [];
      attendance = data['attendance'] as List<ClassAttendance>? ?? [];
      classSessions = data['classSessions'] as List<ClassSession>? ?? [];
      gradeLevels = data['gradeLevels'] as List<GradeLevel>? ?? [];
      studentGrades = data['studentGrades'] as List<StudentGrade>? ?? [];
      
      _recalculateBalances();
    } catch (e) {
      lastError = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveLocal() async {
    await _localStorage.saveData(
      members,
      transactions,
      attendance,
      classSessions,
      gradeLevels,
      studentGrades,
    );
    _recalculateBalances();
    notifyListeners();
  }

  Future<void> updateConsentDoc(String newConsentDoc) async {
    consentDocumentText = newConsentDoc;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('consentDocumentText', newConsentDoc);
    notifyListeners();
  }

  Future<void> savePriceRules(List<PriceRule> rules) async {
    priceRules = rules;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('priceRules', rules.map((r) => jsonEncode(r.toJson())).toList());
    _recalculateBalances();
    notifyListeners();
  }

  Future<void> addPriceRule(PriceRule rule) async {
    priceRules.add(rule);
    await savePriceRules(priceRules);
  }

  // --- One-Way Export ---
  bool isSyncing = false;
  Future<void> exportToExcel() async {
    if (isSyncing) return;
    isSyncing = true;
    notifyListeners();

    try {
      await _dataExchangeService.exportDatabaseToExcel(
        members: members,
        transactions: transactions,
        attendance: attendance,
        classSessions: classSessions,
        gradeLevels: gradeLevels,
        studentGrades: studentGrades,
      );
    } catch (e) {
      lastError = "Export Failed: $e";
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> importExcel() async {
    if (isSyncing) return;
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result != null && result.files.single.path != null) {
        isSyncing = true;
        notifyListeners();

        final File file = File(result.files.single.path!);
        final bytes = await file.readAsBytes();
        
        final parsedData = await _dataExchangeService.importFromExcel(bytes);

        // Merge logic: Upsert by ID
        void mergeList<T>(List<dynamic> parsed, List<T> current, String Function(T) getId, String Function(dynamic) getParsedId) {
            for (var incoming in parsed) {
                final incId = getParsedId(incoming);
                final index = current.indexWhere((e) => getId(e) == incId);
                if (index != -1) {
                  current[index] = incoming as T;
                } else {
                  current.add(incoming as T);
                }
            }
        }

        mergeList<Member>(parsedData['members'] ?? [], members, (m) => m.id, (m) => m.id);
        mergeList<Transaction>(parsedData['transactions'] ?? [], transactions, (t) => t.id, (t) => t.id);
        mergeList<ClassAttendance>(parsedData['attendance'] ?? [], attendance, (a) => a.id, (a) => a.id);
        mergeList<ClassSession>(parsedData['classSessions'] ?? [], classSessions, (s) => s.id, (s) => s.id);
        mergeList<GradeLevel>(parsedData['gradeLevels'] ?? [], gradeLevels, (g) => g.id, (g) => g.id);
        mergeList<StudentGrade>(parsedData['studentGrades'] ?? [], studentGrades, (g) => g.id, (g) => g.id);

        await _saveLocal();
        lastError = null; // Clear any old errors if successful
      }
    } catch (e) {
      lastError = "Import Failed: $e";
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
  bool hasPaidForSession(String memberId, String sessionId) {
    return transactions.any((t) =>
        t.memberId == memberId && t.classSessionId == sessionId);
  }

  Future<void> addMemberObj(Member member) async {
    members.add(member);
    await _saveLocal();
  }

  Future<void> recordPayment(
    String memberId,
    double amount,
    String description, [
    String? classSessionId,
  ]) async {
    final transaction = Transaction.create(
      memberId: memberId,
      amount: amount.abs(),
      description: description,
      classSessionId: classSessionId,
      type: TransactionType.payment,
    );
    transactions.add(transaction);
    await _saveLocal();
  }

  Future<void> checkIn(String memberId, String classSessionId) async {
    final checkIn = ClassAttendance.create(
      memberId: memberId,
      classSessionId: classSessionId,
    );
    attendance.add(checkIn);
    
    double currentPrice = getCurrentClassPrice(DateTime.now());
    if (currentPrice > 0) {
      transactions.add(Transaction.create(
        memberId: memberId,
        amount: -currentPrice,
        description: "Class Fee",
        classSessionId: classSessionId,
        type: TransactionType.classFee,
      ));
    }
    
    await _saveLocal();
  }

  Future<void> checkInAndPay(
    String memberId,
    String classSessionId,
    double amount,
  ) async {
    await recordPayment(memberId, amount, "Class Payment", classSessionId);
    await checkIn(memberId, classSessionId);
  }

  Future<void> addGradeLevel(String name) async {
    final grade = GradeLevel.create(name: name);
    gradeLevels.add(grade);
    await _saveLocal();
  }

  Future<void> recordGrading({
    required String memberId,
    required String gradeId,
    required String notes,
    required String areasOfImprovement,
    required double feeAmount,
    String? classSessionId,
  }) async {
    final grade = gradeLevels.firstWhere(
      (g) => g.id == gradeId,
      orElse: () => GradeLevel(id: '', name: 'Unknown Grade'),
    );

    final studentGrade = StudentGrade.create(
      memberId: memberId,
      gradeId: gradeId,
      notes: notes,
      areasOfImprovement: areasOfImprovement,
    );
    studentGrades.add(studentGrade);

    if (feeAmount > 0) {
      final transaction = Transaction.create(
        memberId: memberId,
        amount: -feeAmount.abs(),
        description: "Grading Fee - ${grade.name}",
        classSessionId: classSessionId,
        type: TransactionType.gradingFee,
      );
      transactions.add(transaction);
    }

    if (classSessionId != null) {
      final checkIn = ClassAttendance.create(
        memberId: memberId,
        classSessionId: classSessionId,
        isGrading: true, // Waive class fee
      );
      attendance.add(checkIn);
    }
    
    await _saveLocal();
  }

  Future<void> createClassForNow({bool isGrading = false}) async {
    final now = DateTime.now();
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
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final amPm = now.hour >= 12 ? 'PM' : 'AM';
    final minuteToken = now.minute.toString().padLeft(2, '0');
    final prefix = isGrading ? "Grading - " : "";
    final name = "$prefix$dayName ${now.month}/${now.day} - $hour:$minuteToken $amPm";

    final session = ClassSession.create(name: name, isGrading: isGrading);
    classSessions.add(session);
    await _saveLocal();
  }

  Future<void> endClass(ClassSession session) async {
    final index = classSessions.indexWhere((s) => s.id == session.id);
    if (index != -1) {
      classSessions[index] = ClassSession(
        id: session.id,
        name: session.name,
        dateTime: session.dateTime,
        isCompleted: true,
      );
      await _saveLocal();
    }
  }

  void _recalculateBalances() {
    _memberBalances = {};

    Map<String, double> rawBalances = {};

    for (var m in members) {
      rawBalances[m.id] = 0.0;
    }

    for (var t in transactions) {
      if (rawBalances.containsKey(t.memberId)) {
        rawBalances[t.memberId] = (rawBalances[t.memberId] ?? 0) + t.amount;
      }
    }

    // Attendance no longer factors into balance recalculation directly.
    // Balances are derived purely from Transactions.

    Map<String, double> familyTotals = {};

    for (var m in members) {
      if (m.familyGroupId != null && m.familyGroupId!.isNotEmpty) {
        familyTotals[m.familyGroupId!] =
            (familyTotals[m.familyGroupId!] ?? 0) + (rawBalances[m.id] ?? 0);
      }
    }

    for (var m in members) {
      if (m.familyGroupId != null && m.familyGroupId!.isNotEmpty) {
        _memberBalances[m.id] = familyTotals[m.familyGroupId!] ?? 0.0;
      } else {
        _memberBalances[m.id] = rawBalances[m.id] ?? 0.0;
      }
      m.balance = _memberBalances[m.id] ?? 0.0;
    }
  }

  // Family Management

  Future<void> createFamilyGroup(Member initiator, List<Member> others) async {
    final String newFamilyId =
        "fam_${DateTime.now().millisecondsSinceEpoch}_${initiator.id.substring(0, 4)}";

    final iIndex = members.indexWhere((m) => m.id == initiator.id);
    if(iIndex != -1) members[iIndex].familyGroupId = newFamilyId;

    for (var o in others) {
       final oIndex = members.indexWhere((m) => m.id == o.id);
       if(oIndex != -1) members[oIndex].familyGroupId = newFamilyId;
    }

    await _saveLocal();
  }

  Future<void> addToFamilyGroup(Member member, String familyGroupId) async {
    final iIndex = members.indexWhere((m) => m.id == member.id);
    if(iIndex != -1) members[iIndex].familyGroupId = familyGroupId;
    await _saveLocal();
  }

  Future<void> removeFromFamilyGroup(Member member) async {
    final iIndex = members.indexWhere((m) => m.id == member.id);
    if(iIndex != -1) members[iIndex].familyGroupId = null;
    await _saveLocal();
  }

  Future<void> updateMember(Member member) async {
    final index = members.indexWhere((m) => m.id == member.id);
    if (index != -1) {
      members[index] = member;
      await _saveLocal();
    }
  }

  // Developer Features
  Future<void> clearClassesAndPayments() async {
    transactions.clear();
    attendance.clear();
    classSessions.clear();
    priceRules = [PriceRule.create(price: 6.0, effectiveDate: DateTime(2000, 1, 1))];
    await savePriceRules(priceRules);
    await _saveLocal();
  }
}
