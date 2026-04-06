import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:membership_tracker/config.dart';
import 'package:membership_tracker/models.dart';
import 'package:http/http.dart' as http;
import 'package:membership_tracker/services/local_storage_service.dart';

class SheetsService extends ChangeNotifier {
  // Standard initialization
  final GoogleSignIn _googleSignIn;

  SheetsService({GoogleSignIn? googleSignIn})
    : _googleSignIn =
          googleSignIn ??
          GoogleSignIn(
            scopes: Config.scopes,
            clientId: kIsWeb ? Config.webClientId : null,
          );

  GoogleSignInAccount? _currentUser;
  sheets.SheetsApi? _sheetsApi;
  drive.DriveApi? _driveApi;
  String? lastError;
  bool needsBackup = false;
  String? spreadsheetUrl;

  // Data
  List<Member> members = [];
  List<Transaction> transactions = [];
  List<ClassAttendance> attendance = [];
  List<ClassSession> classSessions = [];
  List<GradeLevel> gradeLevels = [];
  List<StudentGrade> studentGrades = [];

  final LocalStorageService _localStorage = LocalStorageService();

  Future<void> init() async {
    await _loadLocalData();

    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) async {
      _currentUser = account;
      if (_currentUser != null) {
        await _initApi();
      } else {
        _sheetsApi = null;
        _driveApi = null;
      }
      notifyListeners();
    });

    try {
      await _googleSignIn.signInSilently();
    } catch (e) {
      if (kDebugMode) print('Error signing in silently: $e');
    }
  }

  Future<void> _loadLocalData() async {
    final data = await _localStorage.loadAllData();
    members = data['members'] as List<Member>;
    transactions = data['transactions'] as List<Transaction>;
    attendance = data['attendance'] as List<ClassAttendance>;
    classSessions = data['classSessions'] as List<ClassSession>;
    gradeLevels = data['gradeLevels'] as List<GradeLevel>;
    studentGrades = data['studentGrades'] as List<StudentGrade>;
    notifyListeners();
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
    _triggerAutoBackup();
  }

  Future<void> signIn() async {
    try {
      await _googleSignIn.signIn();
    } catch (e) {
      if (kDebugMode) print('Error signing in: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.disconnect();
    } catch (e) {
      if (kDebugMode) print("Error disconnecting: $e");
      await _googleSignIn.signOut();
    }
  }

  bool get isSignedIn => _currentUser != null;

  Future<void> _initApi() async {
    final httpClient = await _getAuthenticatedClient();
    if (httpClient != null) {
      _sheetsApi = sheets.SheetsApi(httpClient);
      _driveApi = drive.DriveApi(httpClient);
      await _restoreFromCloudIfEmpty();
    }
  }

  Future<http.Client?> _getAuthenticatedClient() async {
    final user = _currentUser ?? _googleSignIn.currentUser;
    if (user == null) return null;
    try {
      return await _googleSignIn.authenticatedClient();
    } catch (e) {
      lastError = "Auth Error: $e";
      return null;
    }
  }

  // --- Drive Backup Logic --- //
  
  void _triggerAutoBackup() {
    needsBackup = true;
    notifyListeners();
    _backupToCloud();
  }

  Future<void> _backupToCloud() async {
    if (_driveApi == null) return;
    try {
      final backupJson = jsonEncode({
        'members': members.map((m) => m.toRow()).toList(),
        'transactions': transactions.map((t) => t.toRow()).toList(),
        'attendance': attendance.map((a) => a.toRow()).toList(),
        'classSessions': classSessions.map((s) => s.toRow()).toList(),
        'gradeLevels': gradeLevels.map((g) => g.toRow()).toList(),
        'studentGrades': studentGrades.map((g) => g.toRow()).toList(),
      });

      final media = drive.Media(
        Stream.value(utf8.encode(backupJson)),
        backupJson.length,
      );

      final fileList = await _driveApi!.files.list(
        spaces: 'appDataFolder',
        q: "name = 'dojo_backup.json'",
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        final fileId = fileList.files!.first.id!;
        await _driveApi!.files.update(drive.File(), fileId, uploadMedia: media);
      } else {
        final driveFile = drive.File()
          ..name = 'dojo_backup.json'
          ..parents = ['appDataFolder'];
        await _driveApi!.files.create(driveFile, uploadMedia: media);
      }
      
      needsBackup = false;
      notifyListeners();
      
    } catch (e) {
      if (kDebugMode) print("Backup failed: $e");
      lastError = "Backup Failed: $e";
      notifyListeners();
    }
  }

  Future<void> _restoreFromCloudIfEmpty() async {
    if (_driveApi == null) return;
    
    if (members.isNotEmpty || classSessions.isNotEmpty) {
       return;
    }

    try {
      final fileList = await _driveApi!.files.list(
        spaces: 'appDataFolder',
        q: "name = 'dojo_backup.json'",
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        final fileId = fileList.files!.first.id!;
        final response = await _driveApi!.files.get(
          fileId,
          downloadOptions: drive.DownloadOptions.fullMedia,
        ) as drive.Media;

        final content = await response.stream.transform(utf8.decoder).join();
        final Map<String, dynamic> data = jsonDecode(content);

        members = (data['members'] as List? ?? []).map((e) => Member.fromRow(e)).toList();
        transactions = (data['transactions'] as List? ?? []).map((e) => Transaction.fromRow(e)).toList();
        attendance = (data['attendance'] as List? ?? []).map((e) => ClassAttendance.fromRow(e)).toList();
        classSessions = (data['classSessions'] as List? ?? []).map((e) => ClassSession.fromRow(e)).toList();
        gradeLevels = (data['gradeLevels'] as List? ?? []).map((e) => GradeLevel.fromRow(e)).toList();
        studentGrades = (data['studentGrades'] as List? ?? []).map((e) => StudentGrade.fromRow(e)).toList();

        await _saveLocal();
        needsBackup = false;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) print("Restore failed: $e");
    }
  }

  // --- Export to Google Sheets Logic --- //
  Future<void> exportToSheets() async {
    if (_sheetsApi == null) {
      await _initApi();
      if (_sheetsApi == null) return;
    }
    
    try {
      final spreadsheet = sheets.Spreadsheet(
        properties: sheets.SpreadsheetProperties(
          title: 'DojoManager_Export_${DateTime.now().toIso8601String().substring(0, 10)}',
        ),
      );
      final created = await _sheetsApi!.spreadsheets.create(spreadsheet);
      final spreadsheetId = created.spreadsheetId!;
      spreadsheetUrl = 'https://docs.google.com/spreadsheets/d/$spreadsheetId';

      final requests = [
        sheets.Request(updateSheetProperties: sheets.UpdateSheetPropertiesRequest(properties: sheets.SheetProperties(title: 'Members', sheetId: 0), fields: 'title')),
        sheets.Request(addSheet: sheets.AddSheetRequest(properties: sheets.SheetProperties(title: 'Transactions'))),
        sheets.Request(addSheet: sheets.AddSheetRequest(properties: sheets.SheetProperties(title: 'Attendance'))),
        sheets.Request(addSheet: sheets.AddSheetRequest(properties: sheets.SheetProperties(title: 'ClassSessions'))),
        sheets.Request(addSheet: sheets.AddSheetRequest(properties: sheets.SheetProperties(title: 'GradeLevels'))),
        sheets.Request(addSheet: sheets.AddSheetRequest(properties: sheets.SheetProperties(title: 'StudentGrades'))),
      ];
      await _sheetsApi!.spreadsheets.batchUpdate(sheets.BatchUpdateSpreadsheetRequest(requests: requests), spreadsheetId);

      await _sheetsApi!.spreadsheets.values.append(
         sheets.ValueRange(values: [
           ['ID', 'FirstName', 'LastName', 'Address', 'Email', 'DOB', 'Mobile', 'HomePhone', 'EmergencyContact', 'MedicalHistory', 'HasBeenSuspended', 'SuspendedDetails', 'HeardAbout', 'LegalGuardian', 'ConsentSigned', 'FamilyGroupId'],
           ...members.map((m) => m.toRow()),
         ]),
         spreadsheetId,
         'Members!A1:Z',
         valueInputOption: 'USER_ENTERED',
      );

      await _sheetsApi!.spreadsheets.values.append(
         sheets.ValueRange(values: [
           ['ID', 'MemberID', 'Amount', 'Date', 'Description', 'ClassSessionID'],
           ...transactions.map((t) => t.toRow()),
         ]),
         spreadsheetId,
         'Transactions!A1:Z',
         valueInputOption: 'USER_ENTERED',
      );

      await _sheetsApi!.spreadsheets.values.append(
         sheets.ValueRange(values: [
           ['ID', 'MemberID', 'Date', 'ClassType', 'ClassSessionID', 'IsGrading'],
           ...attendance.map((t) => t.toRow()),
         ]),
         spreadsheetId,
         'Attendance!A1:Z',
         valueInputOption: 'USER_ENTERED',
      );

      await _sheetsApi!.spreadsheets.values.append(
         sheets.ValueRange(values: [
           ['ID', 'Name', 'DateTime', 'IsCompleted'],
           ...classSessions.map((t) => t.toRow()),
         ]),
         spreadsheetId,
         'ClassSessions!A1:Z',
         valueInputOption: 'USER_ENTERED',
      );

      await _sheetsApi!.spreadsheets.values.append(
         sheets.ValueRange(values: [
           ['ID', 'Name'],
           ...gradeLevels.map((t) => t.toRow()),
         ]),
         spreadsheetId,
         'GradeLevels!A1:Z',
         valueInputOption: 'USER_ENTERED',
      );

      await _sheetsApi!.spreadsheets.values.append(
         sheets.ValueRange(values: [
           ['ID', 'MemberID', 'GradeID', 'Date', 'Notes', 'AreasOfImprovement'],
           ...studentGrades.map((t) => t.toRow()),
         ]),
         spreadsheetId,
         'StudentGrades!A1:Z',
         valueInputOption: 'USER_ENTERED',
      );

      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error formatting sheets: $e');
    }
  }

  // --- Local Add/Update Wrappers --- //
  Future<void> addMember(Member member) async {
    members.add(member);
    notifyListeners();
    await _saveLocal();
  }

  Future<void> addTransaction(Transaction transaction) async {
    transactions.add(transaction);
    notifyListeners();
    await _saveLocal();
  }

  Future<void> addAttendance(ClassAttendance item) async {
    attendance.add(item);
    notifyListeners();
    await _saveLocal();
  }

  Future<void> addClassSession(ClassSession session) async {
    classSessions.add(session);
    notifyListeners();
    await _saveLocal();
  }

  Future<void> addGradeLevel(GradeLevel grade) async {
    gradeLevels.add(grade);
    notifyListeners();
    await _saveLocal();
  }

  Future<void> addStudentGrade(StudentGrade grade) async {
    studentGrades.add(grade);
    notifyListeners();
    await _saveLocal();
  }

  Future<void> updateClassSession(ClassSession session) async {
    final index = classSessions.indexWhere((s) => s.id == session.id);
    if (index != -1) {
      classSessions[index] = session;
      notifyListeners();
      await _saveLocal();
    }
  }

  Future<void> updateMember(Member member) async {
    final index = members.indexWhere((m) => m.id == member.id);
    if (index != -1) {
      members[index] = member;
      notifyListeners();
      await _saveLocal();
    }
  }
}
