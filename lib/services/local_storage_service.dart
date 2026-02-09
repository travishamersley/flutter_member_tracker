import 'dart:convert';
import 'package:membership_tracker/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const String _membersKey = 'local_members_data';
  static const String _transactionsKey = 'local_transactions_data';
  static const String _attendanceKey = 'local_attendance_data';
  static const String _classSessionsKey = 'local_class_sessions_data';

  Future<void> saveMembers(List<Member> members) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = members.map((m) => m.toRow()).toList();
    await prefs.setString(_membersKey, json.encode(jsonList));
  }

  Future<List<Member>> loadMembers() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_membersKey);
    if (jsonString == null) return [];
    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList
          .map((j) => Member.fromRow(j))
          .toList(); // Re-use fromRow if compatible? No, strictly fromRow expects List. We need proper JSON serialization.
    } catch (e) {
      return [];
    }
  }

  // Helper: We need to ensure Models support JSON serialization.
  // Currently they have fromRow (List) and toRow (List).
  // I will just store the List<List<dynamic>> directly to avoid creating new serialization logic if possible,
  // or just Map<String, dynamic>.
  // Keeping it aligned with Sheets "Row" format is easiest for compatibility.

  Future<void> saveData(
    List<Member> members,
    List<Transaction> transactions,
    List<ClassAttendance> attendance,
    List<ClassSession> classSessions,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    // Save Members as List of Rows
    final memberRows = members.map((m) => m.toRow()).toList();
    await prefs.setString(_membersKey, json.encode(memberRows));

    // Save Transactions
    final transactionRows = transactions.map((t) => t.toRow()).toList();
    await prefs.setString(_transactionsKey, json.encode(transactionRows));

    // Save Attendance
    final attendanceRows = attendance.map((a) => a.toRow()).toList();
    await prefs.setString(_attendanceKey, json.encode(attendanceRows));

    // Save Class Sessions
    final sessionRows = classSessions.map((s) => s.toRow()).toList();
    await prefs.setString(_classSessionsKey, json.encode(sessionRows));
  }

  Future<Map<String, List<dynamic>>> loadAllData() async {
    final prefs = await SharedPreferences.getInstance();

    final membersStr = prefs.getString(_membersKey);
    final transactionsStr = prefs.getString(_transactionsKey);
    final attendanceStr = prefs.getString(_attendanceKey);
    final classSessionsStr = prefs.getString(_classSessionsKey);

    List<Member> members = [];
    List<Transaction> transactions = [];
    List<ClassAttendance> attendance = [];
    List<ClassSession> classSessions = [];

    if (membersStr != null) {
      try {
        final List<dynamic> rows = json.decode(membersStr);
        members = rows.map((r) => Member.fromRow(r)).toList();
      } catch (_) {}
    }

    if (transactionsStr != null) {
      try {
        final List<dynamic> rows = json.decode(transactionsStr);
        transactions = rows.map((r) => Transaction.fromRow(r)).toList();
      } catch (_) {}
    }

    if (attendanceStr != null) {
      try {
        final List<dynamic> rows = json.decode(attendanceStr);
        attendance = rows.map((r) => ClassAttendance.fromRow(r)).toList();
      } catch (_) {}
    }

    if (classSessionsStr != null) {
      try {
        final List<dynamic> rows = json.decode(classSessionsStr);
        classSessions = rows.map((r) => ClassSession.fromRow(r)).toList();
      } catch (_) {}
    }

    return {
      'members': members,
      'transactions': transactions,
      'attendance': attendance,
      'classSessions': classSessions,
    };
  }
}
