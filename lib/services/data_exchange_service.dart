import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:membership_tracker/models.dart';
import 'package:uuid/uuid.dart';

class DataExchangeService {
  List<CellValue> _convertToCells(List<dynamic> rowData) {
    return rowData.map((e) => TextCellValue(e.toString())).toList();
  }

  List<CellValue> _convertHeaders(List<String> headers) {
    return headers.map((e) => TextCellValue(e)).toList();
  }

  Future<void> exportDatabaseToExcel({
    required List<Member> members,
    required List<Transaction> transactions,
    required List<ClassAttendance> attendance,
    required List<ClassSession> classSessions,
    required List<GradeLevel> gradeLevels,
    required List<StudentGrade> studentGrades,
  }) async {
    try {
      var excel = Excel.createExcel();
      
      excel.rename('Sheet1', 'Members');

      Sheet sheetObject = excel['Members'];
      sheetObject.appendRow(_convertHeaders(['ID', 'FirstName', 'LastName', 'Address', 'Email', 'DOB', 'Mobile', 'HomePhone', 'EmergencyContact', 'MedicalHistory', 'HasBeenSuspended', 'SuspendedDetails', 'HeardAbout', 'LegalGuardian', 'ConsentSigned', 'FamilyGroupId']));
      for (var m in members) sheetObject.appendRow(_convertToCells(m.toRow()));
      
      sheetObject = excel['Transactions'];
      sheetObject.appendRow(_convertHeaders(['ID', 'MemberID', 'Amount', 'Date', 'Description', 'ClassSessionID']));
      for (var t in transactions) sheetObject.appendRow(_convertToCells(t.toRow()));
      
      sheetObject = excel['Attendance'];
      sheetObject.appendRow(_convertHeaders(['ID', 'MemberID', 'Date', 'ClassType', 'ClassSessionID', 'IsGrading']));
      for (var t in attendance) sheetObject.appendRow(_convertToCells(t.toRow()));
      
      sheetObject = excel['ClassSessions'];
      sheetObject.appendRow(_convertHeaders(['ID', 'Name', 'DateTime', 'IsCompleted']));
      for (var t in classSessions) sheetObject.appendRow(_convertToCells(t.toRow()));
      
      sheetObject = excel['GradeLevels'];
      sheetObject.appendRow(_convertHeaders(['ID', 'Name']));
      for (var t in gradeLevels) sheetObject.appendRow(_convertToCells(t.toRow()));
      
      sheetObject = excel['StudentGrades'];
      sheetObject.appendRow(_convertHeaders(['ID', 'MemberID', 'GradeID', 'Date', 'Notes', 'AreasOfImprovement']));
      for (var t in studentGrades) sheetObject.appendRow(_convertToCells(t.toRow()));
      
      final fileBytes = excel.save();
      if (fileBytes == null) return;
      
      final directory = await getTemporaryDirectory();
      final String filePath = '${directory.path}/DojoManager_Export_${DateTime.now().toIso8601String().substring(0, 10)}.xlsx';
      
      final File file = File(filePath);
      await file.writeAsBytes(fileBytes);

      await Share.shareXFiles([XFile(filePath)], text: 'Dojo Manager Database Backup');

    } catch (e) {
      if (kDebugMode) print("Export Error: $e");
      rethrow;
    }
  }

  Future<Map<String, List<dynamic>>> importFromExcel(List<int> bytes) async {
    final Map<String, List<dynamic>> results = {
      'members': <Member>[],
      'transactions': <Transaction>[],
      'attendance': <ClassAttendance>[],
      'classSessions': <ClassSession>[],
      'gradeLevels': <GradeLevel>[],
      'studentGrades': <StudentGrade>[],
    };

    try {
      var excel = Excel.decodeBytes(bytes);
      final uuid = const Uuid();

      List<String> extractRow(List<Data?> row, int requiredLength) {
        var strRow = row.map((cell) => cell?.value?.toString().trim() ?? "").toList();
        while (strRow.length < requiredLength) {
          strRow.add("");
        }
        return strRow;
      }

      void process(String sheetName, int requiredLength, Function(List<String>) processor) {
        if (excel.tables.containsKey(sheetName)) {
           final sheet = excel.tables[sheetName]!;
           bool isHeader = true;
           for (var row in sheet.rows) {
             if (isHeader) {
               isHeader = false;
               continue;
             }
             final strRow = extractRow(row, requiredLength);
             if (strRow.every((element) => element.isEmpty)) continue;
             
             // Auto-generate UUID if ID is blank
             if (strRow[0].isEmpty) {
                 strRow[0] = uuid.v4();
             }
             
             try {
               processor(strRow);
             } catch (e) {
               if (kDebugMode) print("Error parsing $sheetName row: $e");
             }
           }
        }
      }

      process('Members', 16, (row) => results['members']!.add(Member.fromRow(row)));
      process('Transactions', 6, (row) => results['transactions']!.add(Transaction.fromRow(row)));
      process('Attendance', 6, (row) => results['attendance']!.add(ClassAttendance.fromRow(row)));
      process('ClassSessions', 4, (row) => results['classSessions']!.add(ClassSession.fromRow(row)));
      process('GradeLevels', 2, (row) => results['gradeLevels']!.add(GradeLevel.fromRow(row)));
      process('StudentGrades', 6, (row) => results['studentGrades']!.add(StudentGrade.fromRow(row)));
      
    } catch (e) {
      if (kDebugMode) print("Import Error: $e");
      rethrow;
    }
    
    return results;
  }
}
