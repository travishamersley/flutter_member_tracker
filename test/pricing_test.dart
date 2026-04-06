import 'package:flutter_test/flutter_test.dart';
import 'package:membership_tracker/controllers/club_controller.dart';
import 'package:membership_tracker/models.dart';

void main() {
  group('Pricing Verification (Refactored to Local)', () {
    late ClubController controller;

    setUp(() {
      controller = ClubController();
      controller.isLoading = false;

      // Add a test member directly
      controller.members.add(
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

    test('Single Class Cost', () async {
      final now = DateTime.now();

      // Ensure class session exists for correct check-in path
      final session = ClassSession(id: 'session_1', name: 'Test', dateTime: now);
      controller.classSessions.add(session);

      await controller.checkIn('1', 'session_1');

      final balance = controller.getMemberBalance('1');
      expect(balance, -10.0);
    });

    test('Two Classes Same Day (No Bundling)', () async {
      final now = DateTime.now();
   
      final session1 = ClassSession(id: 'session_1', name: 'Test1', dateTime: now);
      final session2 = ClassSession(id: 'session_2', name: 'Test2', dateTime: now.add(const Duration(hours: 1)));
      
      controller.classSessions.addAll([session1, session2]);

      // Check in to both
      await controller.checkIn('1', 'session_1');
      await controller.checkIn('1', 'session_2');

      final balance = controller.getMemberBalance('1');
      expect(balance, -20.0); // 2 * -10
    });

    test('Legacy Attendance (No Session ID) still charges', () async {
      // Direct insertion to mimic legacy data loaded from disk
      final now = DateTime.now();
      controller.attendance.add(
        ClassAttendance(
          id: 'a1',
          memberId: '1',
          date: now,
          classType: 'LegacyClass', // No session ID
        ),
      );
      
      // We must manually trigger recalculation since we bypassed the controller action
      // However, checkIn / recordPayment normally handles this. Since _recalculateBalances is private,
      // we can trigger a recalculation by checking in a fake user or calling an update.
      // Better yet for tests, adding a transaction of 0.0 forces _saveLocal and _recalculateBalances!
      await controller.recordPayment('1', 0.0, 'Balance trigger');

      final balance = controller.getMemberBalance('1');
      expect(balance, -10.0);
    });
  });
}
