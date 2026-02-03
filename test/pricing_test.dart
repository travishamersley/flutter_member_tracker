import 'package:flutter_test/flutter_test.dart';
import 'package:membership_tracker/controllers/club_controller.dart';
import 'package:membership_tracker/models.dart';
import 'package:membership_tracker/services/sheets_service.dart';

// Mock Service
class FakeSheetsService extends SheetsService {
  @override
  bool get isSignedIn => true;

  @override
  Future<void> init() async {} // Do nothing

  @override
  Future<void> addMember(Member m) async {
    members.add(m);
    notifyListeners();
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
}

void main() {
  group('Pricing Verification', () {
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
          dob: DateTime.now(),
          medicalInfo: '',
          contactInfo: '',
        ),
      );
    });

    test('Wednesday Single Class Cost', () {
      // Wednesday: 2023-10-25 (Wednesday)
      final wed = DateTime(2023, 10, 25, 10, 0);

      service.attendance.add(
        ClassAttendance(
          id: 'a1',
          memberId: '1',
          date: wed,
          classType: 'Wednesday1',
        ),
      );

      // Trigger update
      // Logic is private _recalculateBalances called on listener.
      // But verify logic is inside _recalculateBalances which populates _memberBalances (private).
      // We check via getMemberBalance

      // Reflection or modifying controller to expose recalc?
      // Actually controller listens to service. When we added to service list, we didn't call notifyListeners on service unless we used the methods.
      // FakeService methods call notifyListeners.

      // Force notify
      service.notifyListeners();

      final balance = controller.getMemberBalance('1');
      expect(balance, -10.0);
    });

    test('Wednesday Double Class Cost (2 for 1)', () {
      final wed1 = DateTime(2023, 10, 25, 10, 0); // Class 1
      final wed2 = DateTime(2023, 10, 25, 11, 0); // Class 2

      service.attendance.add(
        ClassAttendance(
          id: 'a1',
          memberId: '1',
          date: wed1,
          classType: 'Wednesday1',
        ),
      );
      service.attendance.add(
        ClassAttendance(
          id: 'a2',
          memberId: '1',
          date: wed2,
          classType: 'Wednesday2',
        ),
      );

      service.notifyListeners(); // Update controller

      final balance = controller.getMemberBalance('1');
      expect(balance, -10.0); // Should still be -10
    });

    test('Friday Class Cost', () {
      final fri = DateTime(2023, 10, 27, 10, 0); // Friday

      service.attendance.add(
        ClassAttendance(
          id: 'a1',
          memberId: '1',
          date: fri,
          classType: 'Friday',
        ),
      );

      service.notifyListeners();

      final balance = controller.getMemberBalance('1');
      expect(balance, -10.0);
    });

    test('Wed + Fri Cost', () {
      final wed = DateTime(2023, 10, 25, 10, 0);
      final fri = DateTime(2023, 10, 27, 10, 0);

      service.attendance.add(
        ClassAttendance(
          id: 'a1',
          memberId: '1',
          date: wed,
          classType: 'Wednesday1',
        ),
      );
      service.attendance.add(
        ClassAttendance(
          id: 'a2',
          memberId: '1',
          date: fri,
          classType: 'Friday',
        ),
      );

      service.notifyListeners();

      final balance = controller.getMemberBalance('1');
      expect(balance, -20.0);
    });
  });
}
