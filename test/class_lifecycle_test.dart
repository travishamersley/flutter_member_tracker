import 'package:flutter_test/flutter_test.dart';
import 'package:membership_tracker/controllers/club_controller.dart';
import 'package:membership_tracker/models.dart';
import 'package:membership_tracker/services/sheets_service.dart';
import 'package:google_sign_in/google_sign_in.dart';

// Mock Service (Duplicated for isolation)
class FakeSheetsService extends SheetsService {
  FakeSheetsService() : super(googleSignIn: GoogleSignIn(clientId: 'fake'));

  @override
  bool get isSignedIn => true;

  @override
  Future<void> init() async {}

  @override
  Future<void> exportToSheets() async {}

  @override
  Future<void> addMember(Member m) async {
    members.add(m);
    notifyListeners();
  }

  @override
  Future<void> updateMember(Member m) async {
    final index = members.indexWhere((existing) => existing.id == m.id);
    if (index != -1) {
      members[index] = m;
      notifyListeners();
    }
  }

  @override
  Future<void> addTransaction(Transaction t) async {
    transactions.add(t);
    notifyListeners();
  }

  @override
  Future<void> addAttendance(ClassAttendance a) async {
    attendance.add(a);
    notifyListeners();
  }

  @override
  Future<void> addClassSession(ClassSession s) async {
    classSessions.add(s);
    notifyListeners();
  }

  @override
  Future<void> updateClassSession(ClassSession s) async {
    final index = classSessions.indexWhere((existing) => existing.id == s.id);
    if (index != -1) {
      classSessions[index] = s;
      notifyListeners();
    }
  }
}

void main() {
  group('Class Lifecycle Logic', () {
    late ClubController controller;
    late FakeSheetsService service;

    setUp(() {
      service = FakeSheetsService();
      controller = ClubController(service);
    });

    test('Active vs Past Sessions', () async {
      // 1. Create a completed session
      final pastSession = ClassSession(
        id: 'completed_1',
        name: 'Past Class',
        dateTime: DateTime.now().subtract(const Duration(days: 1)),
        isCompleted: true,
      );

      // 2. Create an active session
      final activeSession = ClassSession(
        id: 'active_1',
        name: 'Active Class',
        dateTime: DateTime.now(),
        isCompleted: false,
      );

      await service.addClassSession(pastSession);
      await service.addClassSession(activeSession);

      // Verify Controller getters
      expect(controller.activeSession?.id, 'active_1');
      expect(controller.pastSessions.length, 1);
      expect(controller.pastSessions.first.id, 'completed_1');
    });

    test('End Class moves session to history', () async {
      // 1. Add active session
      final s = ClassSession(
        id: 's1',
        name: 'My Class',
        dateTime: DateTime.now(),
        isCompleted: false,
      );
      await service.addClassSession(s);

      // Verify it's active
      expect(controller.activeSession?.id, 's1');
      expect(controller.pastSessions, isEmpty);

      // 2. End Class
      await controller.endClass(s);

      // 3. Verify it's now completed
      expect(controller.activeSession, isNull);
      expect(controller.pastSessions.length, 1);
      expect(controller.pastSessions.first.id, 's1');
      expect(controller.pastSessions.first.isCompleted, true);
    });

    test('Create Class logic', () async {
      await controller.createClassForNow();

      expect(service.classSessions.length, 1);
      expect(controller.activeSession, isNotNull);
      expect(controller.activeSession!.isCompleted, false);
      // Basic name check
      expect(
        controller.activeSession!.name,
        contains(DateTime.now().month.toString()),
      );
    });
  });
}
