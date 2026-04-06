import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:membership_tracker/config.dart';
import 'package:membership_tracker/models.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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
  String? _spreadsheetId;
  String? lastError;

  // Expose Spreadsheet URL
  String? get spreadsheetUrl => _spreadsheetId != null
      ? 'https://docs.google.com/spreadsheets/d/$_spreadsheetId'
      : null;

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

    _googleSignIn.onCurrentUserChanged.listen((
      GoogleSignInAccount? account,
    ) async {
      _currentUser = account;
      if (_currentUser != null) {
        // Automatically init API on sign in
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
      debugPrint('SheetsService: _initApi - HttpClient created');
      _sheetsApi = sheets.SheetsApi(httpClient);
      _driveApi = drive.DriveApi(httpClient);
      // Auto-load on init
      await _findOrCreateSpreadsheet();
      await _findOrCreateSpreadsheet();
      await syncData();
    } else {
      debugPrint(
        'SheetsService: _initApi - Failed to create authenticated client (httpClient is null)',
      );
    }
  }

  Future<http.Client?> _getAuthenticatedClient() async {
    // Check local tracker, then fallback to the source of truth
    final user = _currentUser ?? _googleSignIn.currentUser;
    if (user == null) {
      debugPrint(
        'SheetsService: _getAuthenticatedClient - No user found (_currentUser is null, _googleSignIn.currentUser is null)',
      );
      return null;
    }
    debugPrint(
      'SheetsService: _getAuthenticatedClient - Using user: ${user.email}',
    );
    try {
      final client = await _googleSignIn.authenticatedClient();
      if (client == null) {
        debugPrint(
          'SheetsService: _getAuthenticatedClient - authenticatedClient() returned null (no exception thrown)',
        );
      }
      return client;
    } catch (e) {
      lastError = "Auth Error: $e";
      debugPrint('SheetsService: _getAuthenticatedClient error: $e');
      return null;
    }
  }

  Future<void> _findOrCreateSpreadsheet() async {
    if (_sheetsApi == null) return;
    lastError = null;
    debugPrint('SheetsService: _findOrCreateSpreadsheet calling...');

    try {
      final prefs = await SharedPreferences.getInstance();
      _spreadsheetId = prefs.getString('spreadsheet_id');

      if (_spreadsheetId == null) {
        _spreadsheetId = await _searchForSpreadsheet();
        if (_spreadsheetId != null) {
          await prefs.setString('spreadsheet_id', _spreadsheetId!);
        }
      }

      if (_spreadsheetId == null) {
        final spreadsheet = sheets.Spreadsheet(
          properties: sheets.SpreadsheetProperties(
            title: 'MembershipTracker_DB',
          ),
        );

        final created = await _sheetsApi!.spreadsheets.create(spreadsheet);
        _spreadsheetId = created.spreadsheetId;

        if (_spreadsheetId != null) {
          await prefs.setString('spreadsheet_id', _spreadsheetId!);
          await _initializeSheetStructure();
        }
      }
    } catch (e) {
      lastError = "Sync Error: $e";
      if (kDebugMode) print('Error in _findOrCreateSpreadsheet: $e');
      notifyListeners();
    }
  }

  Future<String?> _searchForSpreadsheet() async {
    if (_driveApi == null) return null;
    try {
      final fileList = await _driveApi!.files.list(
        q: "name = 'MembershipTracker_DB' and mimeType = 'application/vnd.google-apps.spreadsheet' and trashed = false",
        $fields: "files(id, name)",
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first.id;
      }
    } catch (e) {
      if (kDebugMode) print('Error searching for spreadsheet: $e');
    }
    return null;
  }

  Future<void> _initializeSheetStructure() async {
    if (_sheetsApi == null || _spreadsheetId == null) return;

    final requests = [
      sheets.Request(
        updateSheetProperties: sheets.UpdateSheetPropertiesRequest(
          properties: sheets.SheetProperties(title: 'Members', sheetId: 0),
          fields: 'title',
        ),
      ),
      sheets.Request(
        addSheet: sheets.AddSheetRequest(
          properties: sheets.SheetProperties(title: 'Transactions'),
        ),
      ),
      sheets.Request(
        addSheet: sheets.AddSheetRequest(
          properties: sheets.SheetProperties(title: 'Attendance'),
        ),
      ),
      sheets.Request(
        addSheet: sheets.AddSheetRequest(
          properties: sheets.SheetProperties(title: 'ClassSessions'),
        ),
      ),
      sheets.Request(
        addSheet: sheets.AddSheetRequest(
          properties: sheets.SheetProperties(title: 'GradeLevels'),
        ),
      ),
      sheets.Request(
        addSheet: sheets.AddSheetRequest(
          properties: sheets.SheetProperties(title: 'StudentGrades'),
        ),
      ),
    ];

    final batchRequest = sheets.BatchUpdateSpreadsheetRequest(
      requests: requests,
    );
    try {
      await _sheetsApi!.spreadsheets.batchUpdate(batchRequest, _spreadsheetId!);

      await _appendRow('Members', [
        'ID',
        'FirstName',
        'LastName',
        'Address',
        'Email',
        'DOB',
        'Mobile',
        'HomePhone',
        'EmergencyContact',
        'MedicalHistory',
        'HasBeenSuspended',
        'SuspendedDetails',
        'HeardAbout',
        'LegalGuardian',
        'ConsentSigned',
        'FamilyGroupId',
      ]);
      await _appendRow('Transactions', [
        'ID',
        'MemberID',
        'Amount',
        'Date',
        'Description',
        'ClassSessionID',
      ]);
      await _appendRow('Attendance', [
        'ID',
        'MemberID',
        'Date',
        'ClassType',
        'ClassSessionID',
        'IsGrading',
      ]);
      await _appendRow('ClassSessions', [
        'ID',
        'Name',
        'DateTime',
        'IsCompleted',
      ]);
      await _appendRow('GradeLevels', [
        'ID',
        'Name',
      ]);
      await _appendRow('StudentGrades', [
        'ID',
        'MemberID',
        'GradeID',
        'Date',
        'Notes',
        'AreasOfImprovement',
      ]);
    } catch (e) {
      if (kDebugMode) print('Error initializing sheets: $e');
    }
  }

  Future<void> syncData() async {
    debugPrint('SheetsService: syncData called');

    // 1. Ensure API is ready
    if (_sheetsApi == null) {
      await _ensureApiReady();
    }

    if (_sheetsApi == null || _spreadsheetId == null) {
      debugPrint(
        'SheetsService: syncData aborting. API or Spreadsheet not ready.',
      );
      return;
    }

    try {
      // 2. Fetch Remote Data
      final ranges = [
        'Members!A2:P',
        'Transactions!A2:F',
        'Attendance!A2:F',
        'ClassSessions!A2:D',
        'GradeLevels!A2:B',
        'StudentGrades!A2:F',
      ];

      final response = await _sheetsApi!.spreadsheets.values.batchGet(
        _spreadsheetId!,
        ranges: ranges,
      );

      if (response.valueRanges == null) return;

      // Parse Remote Data
      final remoteMembers = (response.valueRanges![0].values ?? [])
          .map((row) => Member.fromRow(row))
          .toList();
      final remoteTransactions = (response.valueRanges![1].values ?? [])
          .map((row) => Transaction.fromRow(row))
          .toList();
      final remoteAttendance = (response.valueRanges![2].values ?? [])
          .map((row) => ClassAttendance.fromRow(row))
          .toList();
      final remoteSessions = (response.valueRanges!.length > 3)
          ? (response.valueRanges![3].values ?? [])
                .map((row) => ClassSession.fromRow(row))
                .toList()
          : <ClassSession>[];
      final remoteGradeLevels = (response.valueRanges!.length > 4)
          ? (response.valueRanges![4].values ?? [])
                .map((row) => GradeLevel.fromRow(row))
                .toList()
          : <GradeLevel>[];
      final remoteStudentGrades = (response.valueRanges!.length > 5)
          ? (response.valueRanges![5].values ?? [])
                .map((row) => StudentGrade.fromRow(row))
                .toList()
          : <StudentGrade>[];

      // 3. Identify & Push Missing Local Items
      // We compare current 'members' (local state) with 'remoteMembers'.
      // If a local member ID is NOT in remote, it's new/offline. Push it.

      // Members
      final localOnlyMembers = members
          .where((l) => !remoteMembers.any((r) => r.id == l.id))
          .toList();
      for (var m in localOnlyMembers) {
        debugPrint("Syncing Member up: ${m.firstName}");
        await _appendRow('Members', m.toRow());
        remoteMembers.add(
          m,
        ); // Add to our working list so we don't need to re-fetch
      }

      // Transactions
      final localOnlyTransactions = transactions
          .where((l) => !remoteTransactions.any((r) => r.id == l.id))
          .toList();
      for (var t in localOnlyTransactions) {
        debugPrint("Syncing Transaction up: ${t.amount}");
        await _appendRow('Transactions', t.toRow());
        remoteTransactions.add(t);
      }

      // Attendance
      final localOnlyAttendance = attendance
          .where((l) => !remoteAttendance.any((r) => r.id == l.id))
          .toList();
      for (var a in localOnlyAttendance) {
        debugPrint("Syncing Attendance up: ${a.date}");
        await _appendRow('Attendance', a.toRow());
        remoteAttendance.add(a);
      }

      // Sessions
      final localOnlySessions = classSessions
          .where((l) => !remoteSessions.any((r) => r.id == l.id))
          .toList();
      for (var s in localOnlySessions) {
        debugPrint("Syncing Session up: ${s.name}");
        await _appendRow('ClassSessions', s.toRow());
        remoteSessions.add(s);
      }

      // GradeLevels
      final localOnlyGradeLevels = gradeLevels
          .where((l) => !remoteGradeLevels.any((r) => r.id == l.id))
          .toList();
      for (var g in localOnlyGradeLevels) {
        debugPrint("Syncing GradeLevel up: ${g.name}");
        await _appendRow('GradeLevels', g.toRow());
        remoteGradeLevels.add(g);
      }

      // StudentGrades
      final localOnlyStudentGrades = studentGrades
          .where((l) => !remoteStudentGrades.any((r) => r.id == l.id))
          .toList();
      for (var s in localOnlyStudentGrades) {
        debugPrint("Syncing StudentGrade up: ${s.id}");
        await _appendRow('StudentGrades', s.toRow());
        remoteStudentGrades.add(s);
      }

      // 4. Update Local State (Server Wins for conflicts)
      members = remoteMembers;
      transactions = remoteTransactions;
      attendance = remoteAttendance;
      classSessions = remoteSessions;
      gradeLevels = remoteGradeLevels;
      studentGrades = remoteStudentGrades;

      // 5. Persist
      await _saveLocal();

      notifyListeners();
      debugPrint('SheetsService: syncData completed.');
    } catch (e, stack) {
      debugPrint('SheetsService: Error syncing data: $e');
      debugPrint(stack.toString());
      lastError = "Sync Failed: $e";
      notifyListeners();
    }
  }

  // Refactored helper for API init
  Future<void> _ensureApiReady() async {
    if (_sheetsApi == null && _currentUser != null) {
      await _initApi();
    }
    if (_sheetsApi == null) {
      try {
        final account = await _googleSignIn.signIn();
        _currentUser = account;
        await _initApi();
        if (_sheetsApi == null) {
          final granted = await _googleSignIn.requestScopes(Config.scopes);
          if (granted) await _initApi();
        }
      } catch (e) {
        debugPrint('SheetsService: Interactive sign-in failed: $e');
      }
    }
  }

  // Helper methods to save and append
  Future<void> addMember(Member member) async {
    members.add(member);
    notifyListeners();
    await _saveLocal();
    await _appendRow('Members', member.toRow());
  }

  Future<void> addTransaction(Transaction transaction) async {
    transactions.add(transaction);
    notifyListeners();
    await _saveLocal();
    await _appendRow('Transactions', transaction.toRow());
  }

  Future<void> addAttendance(ClassAttendance item) async {
    attendance.add(item);
    notifyListeners();
    await _saveLocal();
    await _appendRow('Attendance', item.toRow());
  }

  Future<void> addClassSession(ClassSession session) async {
    classSessions.add(session);
    notifyListeners();
    await _saveLocal();
    await _appendRow('ClassSessions', session.toRow());
  }

  Future<void> addGradeLevel(GradeLevel grade) async {
    gradeLevels.add(grade);
    notifyListeners();
    await _saveLocal();
    await _appendRow('GradeLevels', grade.toRow());
  }

  Future<void> addStudentGrade(StudentGrade grade) async {
    studentGrades.add(grade);
    notifyListeners();
    await _saveLocal();
    await _appendRow('StudentGrades', grade.toRow());
  }

  Future<void> updateClassSession(ClassSession session) async {
    final index = classSessions.indexWhere((s) => s.id == session.id);
    if (index != -1) {
      classSessions[index] = session;
      notifyListeners();
      await _saveLocal();

      if (_sheetsApi != null && _spreadsheetId != null) {
        final rowIndex = index + 2;
        final range = 'ClassSessions!A$rowIndex:D$rowIndex';
        final valueRange = sheets.ValueRange(values: [session.toRow()]);
        try {
          await _sheetsApi!.spreadsheets.values.update(
            valueRange,
            _spreadsheetId!,
            range,
            valueInputOption: 'USER_ENTERED',
          );
        } catch (e) {
          if (kDebugMode) print('Error updating class session: $e');
        }
      }
    }
  }

  Future<void> updateMember(Member member) async {
    final index = members.indexWhere((m) => m.id == member.id);
    if (index != -1) {
      members[index] = member;
      notifyListeners();
      await _saveLocal();

      if (_sheetsApi != null && _spreadsheetId != null) {
        final rowIndex = index + 2;
        final range = 'Members!A$rowIndex:P$rowIndex'; // Extended range
        final valueRange = sheets.ValueRange(values: [member.toRow()]);
        try {
          await _sheetsApi!.spreadsheets.values.update(
            valueRange,
            _spreadsheetId!,
            range,
            valueInputOption: 'USER_ENTERED',
          );
        } catch (e) {
          if (kDebugMode) print('Error updating member: $e');
        }
      }
    }
  }

  Future<void> _appendRow(String range, List<dynamic> row) async {
    if (_sheetsApi == null || _spreadsheetId == null) return;
    final valueRange = sheets.ValueRange(values: [row]);
    try {
      await _sheetsApi!.spreadsheets.values.append(
        valueRange,
        _spreadsheetId!,
        range,
        valueInputOption: 'USER_ENTERED',
      );
    } catch (e) {
      if (kDebugMode) print('Error appending row to $range: $e');
    }
  }
}
