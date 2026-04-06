import 'package:membership_tracker/models.dart';
import 'package:membership_tracker/services/storage/storage_stub.dart'
    if (dart.library.html) 'package:membership_tracker/services/storage/storage_web.dart'
    if (dart.library.io) 'package:membership_tracker/services/storage/storage_io.dart';

class LocalStorageService {
  final _storage = getStorage();

  Future<void> saveData(
    List<Member> members,
    List<Transaction> transactions,
    List<ClassAttendance> attendance,
    List<ClassSession> classSessions,
    [List<GradeLevel>? gradeLevels,
    List<StudentGrade>? studentGrades,]
  ) async {
    await _storage.saveData(
      members.map((m) => m.toRow()).toList(),
      transactions.map((t) => t.toRow()).toList(),
      attendance.map((a) => a.toRow()).toList(),
      classSessions.map((s) => s.toRow()).toList(),
      gradeLevels?.map((g) => g.toRow()).toList() ?? [],
      studentGrades?.map((g) => g.toRow()).toList() ?? [],
    );
  }

  Future<Map<String, List<dynamic>>> loadAllData() async {
    final rawData = await _storage.loadAllData();

    List<Member> members = [];
    List<Transaction> transactions = [];
    List<ClassAttendance> attendance = [];
    List<ClassSession> classSessions = [];
    List<GradeLevel> gradeLevels = [];
    List<StudentGrade> studentGrades = [];

    try {
      members = (rawData['members'] ?? []).map((r) => Member.fromRow(r)).toList();
    } catch (_) {}

    try {
      transactions = (rawData['transactions'] ?? []).map((r) => Transaction.fromRow(r)).toList();
    } catch (_) {}

    try {
      attendance = (rawData['attendance'] ?? []).map((r) => ClassAttendance.fromRow(r)).toList();
    } catch (_) {}

    try {
      classSessions = (rawData['classSessions'] ?? []).map((r) => ClassSession.fromRow(r)).toList();
    } catch (_) {}

    try {
      gradeLevels = (rawData['gradeLevels'] ?? []).map((r) => GradeLevel.fromRow(r)).toList();
    } catch (_) {}

    try {
      studentGrades = (rawData['studentGrades'] ?? []).map((r) => StudentGrade.fromRow(r)).toList();
    } catch (_) {}

    return {
      'members': members,
      'transactions': transactions,
      'attendance': attendance,
      'classSessions': classSessions,
      'gradeLevels': gradeLevels,
      'studentGrades': studentGrades,
    };
  }
}
