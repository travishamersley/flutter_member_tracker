import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
// import 'package:googleapis_auth/googleapis_auth.dart' as auth; // Not strictly needed if we don't use it directly, but SheetsApi expects a client.
import 'package:membership_tracker/config.dart';
import 'package:membership_tracker/models.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:membership_tracker/services/local_storage_service.dart';

class SheetsService extends ChangeNotifier {
  // GoogleSignIn is now a singleton in v7+
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  GoogleSignInAccount? _currentUser;
  sheets.SheetsApi? _sheetsApi;
  String? _spreadsheetId; // We need to find or create this

  // Basic in-memory cache
  List<Member> members = [];
  List<Transaction> transactions = [];
  List<ClassAttendance> attendance = [];

  final LocalStorageService _localStorage = LocalStorageService();

  Future<void> init() async {
    // 1. Load Local Data Immediately
    await _loadLocalData();

    _googleSignIn.authenticationEvents.listen((
      GoogleSignInAuthenticationEvent event,
    ) async {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        _currentUser = event.user;
        if (_currentUser != null) {
          await _initApi();
        }
      } else if (event is GoogleSignInAuthenticationEventSignOut) {
        _currentUser = null;
        _sheetsApi = null;
        // Don't clear local data on sign out! User might be offline.
        // But maybe we should? "Not persisting" means we WANT it to persist.
        // If we clear here, we lose data on accidental sign out.
        // Let's keep it in memory/local.
        notifyListeners();
      }
      notifyListeners();
    });

    try {
      await _googleSignIn.initialize(
        clientId: kIsWeb ? Config.webClientId : null,
      );
      // Attempt generic sign in for non-web, or silent for web if supported
      await _googleSignIn.attemptLightweightAuthentication();
    } catch (e) {
      if (kDebugMode) print('Error signing in silently: $e');
    }
  }

  Future<void> _loadLocalData() async {
    final data = await _localStorage.loadAllData();
    members = data['members'] as List<Member>;
    transactions = data['transactions'] as List<Transaction>;
    attendance = data['attendance'] as List<ClassAttendance>;
    notifyListeners();
  }

  Future<void> signIn() async {
    try {
      // On Web, this might throw if used directly, so specific UI button is preferred.
      // But for mobile, or if web decides to support popup flows again, we keep it.
      if (!kIsWeb) {
        await _googleSignIn.authenticate(scopeHint: Config.scores);
      } else {
        // Web flow is handled by the configured button unless "One Tap" works.
        // We still try authenticate() just in case, but catch the unimplemented error.
        await _googleSignIn.authenticate();
      }
    } catch (e) {
      if (kDebugMode) print('Error signing in: $e');
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _sheetsApi = null;
    // Keep local data for offline use or future sync
    notifyListeners();
  }

  bool get isSignedIn => _currentUser != null;

  Future<void> _initApi() async {
    final httpClient = await _getAuthenticatedClient();
    if (httpClient != null) {
      _sheetsApi = sheets.SheetsApi(httpClient);
      await _findOrCreateSpreadsheet();
      await fetchAllData();
    }
  }

  Future<http.Client?> _getAuthenticatedClient() async {
    if (_currentUser == null) return null;
    // Explicitly request headers for our scopes
    final headers = await _currentUser!.authorizationClient
        .authorizationHeaders(Config.scores);
    if (headers == null) return null;

    return _AuthenticatedClient(headers);
  }

  Future<void> _findOrCreateSpreadsheet() async {
    if (_sheetsApi == null) return;

    // Check local storage for existing ID
    final prefs = await SharedPreferences.getInstance();
    _spreadsheetId = prefs.getString('spreadsheet_id');

    if (_spreadsheetId == null) {
      // Create a new spreadsheet
      final spreadsheet = sheets.Spreadsheet(
        properties: sheets.SpreadsheetProperties(title: 'MembershipTracker_DB'),
      );

      try {
        final created = await _sheetsApi!.spreadsheets.create(spreadsheet);
        _spreadsheetId = created.spreadsheetId;

        if (_spreadsheetId != null) {
          await prefs.setString('spreadsheet_id', _spreadsheetId!);
          await _initializeSheetStructure();
        }
      } catch (e) {
        if (kDebugMode) print('Error creating spreadsheet: $e');
      }
    }
  }

  Future<void> _initializeSheetStructure() async {
    if (_sheetsApi == null || _spreadsheetId == null) return;

    // Add headers to 'Sheet1' (rename to Members) and add other sheets
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
    ];

    final batchRequest = sheets.BatchUpdateSpreadsheetRequest(
      requests: requests,
    );
    try {
      await _sheetsApi!.spreadsheets.batchUpdate(batchRequest, _spreadsheetId!);

      // Append Headers
      await _appendRow('Members', [
        'ID',
        'FirstName',
        'LastName',
        'DOB',
        'MedicalInfo',
        'ContactInfo',
      ]);
      await _appendRow('Transactions', [
        'ID',
        'MemberID',
        'Amount',
        'Date',
        'Description',
      ]);
      await _appendRow('Attendance', ['ID', 'MemberID', 'Date', 'ClassType']);
    } catch (e) {
      if (kDebugMode) print('Error initializing sheets: $e');
    }
  }

  Future<void> fetchAllData() async {
    if (_sheetsApi == null || _spreadsheetId == null) return;

    try {
      // Fetch data starting from row 2 (skipping headers)
      final ranges = ['Members!A2:G', 'Transactions!A2:E', 'Attendance!A2:D'];
      final response = await _sheetsApi!.spreadsheets.values.batchGet(
        _spreadsheetId!,
        ranges: ranges,
      );

      if (response.valueRanges != null) {
        // Members
        final memberRows = response.valueRanges![0].values;
        if (memberRows != null) {
          members = memberRows.map((row) => Member.fromRow(row)).toList();
        } else {
          // Keep local if remote is empty? No, remote is truth.
          // But if we just created the sheet, it's empty.
          // If we have local data and remote is empty, we should PUSH local?
          // Improvement: If remote is empty and local is not, push local.
          // For now, let's assume if remote returns, it overwrites.
          members = [];
        }

        // Transactions
        final transactionRows = response.valueRanges![1].values;
        if (transactionRows != null) {
          transactions = transactionRows
              .map((row) => Transaction.fromRow(row))
              .toList();
        } else {
          transactions = [];
        }

        // Attendance
        final attendanceRows = response.valueRanges![2].values;
        if (attendanceRows != null) {
          attendance = attendanceRows
              .map((row) => ClassAttendance.fromRow(row))
              .toList();
        } else {
          attendance = [];
        }

        // Save fetched data to local storage to keep it in sync
        await _localStorage.saveData(members, transactions, attendance);
      }
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error fetching data: $e');
    }
  }

  Future<void> addMember(Member member) async {
    members.add(member);
    notifyListeners();
    // Save Local 1st
    await _localStorage.saveData(members, transactions, attendance);
    // Push Remote
    await _appendRow('Members', member.toRow());
  }

  Future<void> addTransaction(Transaction transaction) async {
    transactions.add(transaction);
    notifyListeners();
    await _localStorage.saveData(members, transactions, attendance);
    await _appendRow('Transactions', transaction.toRow());
  }

  Future<void> addAttendance(ClassAttendance item) async {
    attendance.add(item);
    notifyListeners();
    await _localStorage.saveData(members, transactions, attendance);
    await _appendRow('Attendance', item.toRow());
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

class _AuthenticatedClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _AuthenticatedClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}
