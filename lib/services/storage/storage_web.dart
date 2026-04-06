import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'storage_interface.dart';

class StorageWeb implements StorageInterface {
  static const String _membersKey = 'local_members_data';
  static const String _transactionsKey = 'local_transactions_data';
  static const String _attendanceKey = 'local_attendance_data';
  static const String _classSessionsKey = 'local_class_sessions_data';
  static const String _gradeLevelsKey = 'local_grade_levels_data';
  static const String _studentGradesKey = 'local_student_grades_data';

  @override
  Future<void> saveData(
    List<dynamic> members,
    List<dynamic> transactions,
    List<dynamic> attendance,
    List<dynamic> classSessions,
    List<dynamic> gradeLevels,
    List<dynamic> studentGrades,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString(_membersKey, json.encode(members));
    await prefs.setString(_transactionsKey, json.encode(transactions));
    await prefs.setString(_attendanceKey, json.encode(attendance));
    await prefs.setString(_classSessionsKey, json.encode(classSessions));
    await prefs.setString(_gradeLevelsKey, json.encode(gradeLevels));
    await prefs.setString(_studentGradesKey, json.encode(studentGrades));
  }

  @override
  Future<Map<String, List<dynamic>>> loadAllData() async {
    final prefs = await SharedPreferences.getInstance();

    List<dynamic> readValue(String key) {
      final str = prefs.getString(key);
      if (str != null) {
        try {
          return json.decode(str) as List<dynamic>;
        } catch (_) {}
      }
      return [];
    }

    return {
      'members': readValue(_membersKey),
      'transactions': readValue(_transactionsKey),
      'attendance': readValue(_attendanceKey),
      'classSessions': readValue(_classSessionsKey),
      'gradeLevels': readValue(_gradeLevelsKey),
      'studentGrades': readValue(_studentGradesKey),
    };
  }
}

StorageInterface getStorage() => StorageWeb();
