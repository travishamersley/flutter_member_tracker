import 'package:flutter_test/flutter_test.dart';
import 'package:membership_tracker/controllers/club_controller.dart';
import 'package:membership_tracker/models.dart';

// Since ClubController integrates LocalStorage directly now,
// we can manipulate its core lists for isolated testing,
// or use its public methods. For speed and avoiding disk writes
// in unit tests, we'll just populate its public lists and call methods
// that trigger state updates.

void main() {
  group('Class Lifecycle Logic', () {
    late ClubController controller;

    setUp(() {
      controller = ClubController();
      controller.isLoading = false; // Mock finish init
    });

    test('Active vs Past Sessions', () async {
      final pastSession = ClassSession(
        id: 'completed_1',
        name: 'Past Class',
        dateTime: DateTime.now().subtract(const Duration(days: 1)),
        isCompleted: true,
      );

      final activeSession = ClassSession(
        id: 'active_1',
        name: 'Active Class',
        dateTime: DateTime.now(),
        isCompleted: false,
      );

      // Directly manipulate the state lists for pure unit tests
      controller.classSessions.add(pastSession);
      controller.classSessions.add(activeSession);

      expect(controller.activeSession?.id, 'active_1');
      expect(controller.pastSessions.length, 1);
      expect(controller.pastSessions.first.id, 'completed_1');
    });

    test('End Class moves session to history', () async {
      final s = ClassSession(
        id: 's1',
        name: 'My Class',
        dateTime: DateTime.now(),
        isCompleted: false,
      );
      
      controller.classSessions.add(s);

      expect(controller.activeSession?.id, 's1');
      expect(controller.pastSessions, isEmpty);

      // Simulate ending the class
      await controller.endClass(s);

      expect(controller.activeSession, isNull);
      expect(controller.pastSessions.length, 1);
      expect(controller.pastSessions.first.id, 's1');
      expect(controller.pastSessions.first.isCompleted, true);
    });

    test('Create Class logic', () async {
      await controller.createClassForNow();

      expect(controller.classSessions.length, 1);
      expect(controller.activeSession, isNotNull);
      expect(controller.activeSession!.isCompleted, false);
      
      expect(
        controller.activeSession!.name,
        contains(DateTime.now().month.toString()),
      );
    });
  });
}
