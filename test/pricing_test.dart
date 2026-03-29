import 'package:flutter_test/flutter_test.dart';
import 'package:membership_tracker/controllers/club_controller.dart';
import 'package:membership_tracker/models.dart';
import 'package:membership_tracker/services/sheets_service.dart';

import 'package:google_sign_in/google_sign_in.dart';

// Mock Service
class FakeSheetsService extends SheetsService {
  FakeSheetsService() : super(googleSignIn: GoogleSignIn(clientId: 'fake'));

  @override
  bool get isSignedIn => true;

  @override
  Future<void> init() async {} // Do nothing

  @override
  Future<void> syncData() async {}

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
  group('Pricing Verification (Refactored)', () {
    late ClubController controller;
    late FakeSheetsService service;

    setUp(() {
      service = FakeSheetsService();
      controller = ClubController(service);

      // Add a test member
      service.members.add(
        Member(
          id: '1',
          firstName: 'John',
          lastName: 'Doe',
          address: '123 Fake St',
          email: 'john@example.com',
          dob: DateTime(1990, 1, 1),
          mobile: '0400000000',
          emergencyContact: 'Jane Doe',
          medicalHistory: MedicalHistory(),
          heardAbout: 'Internet',
        ),
      );
    });

    test('Single Class Cost', () {
      final now = DateTime.now();

      service.attendance.add(
        ClassAttendance(
          id: 'a1',
          memberId: '1',
          date: now,
          classSessionId: 'session_1',
        ),
      );

      // Trigger update
      service.notifyListeners();

      final balance = controller.getMemberBalance('1');
      expect(balance, -10.0);
    });

    test('Two Classes Same Day (No Bundling)', () {
      // Logic changed: No longer 2-for-1. Should be 2 charges.
      final now = DateTime.now();

      service.attendance.add(
        ClassAttendance(
          id: 'a1',
          memberId: '1',
          date: now,
          classSessionId: 'session_1',
        ),
      );
      service.attendance.add(
        ClassAttendance(
          id: 'a2',
          memberId: '1',
          date: now,
          classSessionId: 'session_2',
        ),
      );

      service.notifyListeners(); // Update controller

      final balance = controller.getMemberBalance('1');
      expect(balance, -20.0); // 2 * -10
    });

    test('Legacy Attendance (No Session ID) still charges', () {
      final now = DateTime.now();

      service.attendance.add(
        ClassAttendance(
          id: 'a1',
          memberId: '1',
          date: now,
          classType: 'LegacyClass', // No session ID
        ),
      );

      service.notifyListeners();

      final balance = controller.getMemberBalance('1');
      expect(balance, -10.0);
    });
  });
}
