import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'storage_interface.dart';

class StorageIo implements StorageInterface {
  Future<File> _getFile(String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$filename');
  }

  Future<void> _writeJsonList(String filename, List<dynamic> data) async {
    final file = await _getFile(filename);
    await file.writeAsString(json.encode(data));
  }

  Future<List<dynamic>> _readJsonList(String filename) async {
    try {
      final file = await _getFile(filename);
      if (await file.exists()) {
        final contents = await file.readAsString();
        return json.decode(contents) as List<dynamic>;
      }
    } catch (e) {
      // Return empty list on failure
    }
    return [];
  }

  @override
  Future<void> saveData(
    List<dynamic> members,
    List<dynamic> transactions,
    List<dynamic> attendance,
    List<dynamic> classSessions,
    List<dynamic> gradeLevels,
    List<dynamic> studentGrades,
  ) async {
    await _writeJsonList('members.json', members);
    await _writeJsonList('transactions.json', transactions);
    await _writeJsonList('attendance.json', attendance);
    await _writeJsonList('class_sessions.json', classSessions);
    await _writeJsonList('grade_levels.json', gradeLevels);
    await _writeJsonList('student_grades.json', studentGrades);
  }

  @override
  Future<Map<String, List<dynamic>>> loadAllData() async {
    return {
      'members': await _readJsonList('members.json'),
      'transactions': await _readJsonList('transactions.json'),
      'attendance': await _readJsonList('attendance.json'),
      'classSessions': await _readJsonList('class_sessions.json'),
      'gradeLevels': await _readJsonList('grade_levels.json'),
      'studentGrades': await _readJsonList('student_grades.json'),
    };
  }
}

StorageInterface getStorage() => StorageIo();
