import 'package:flutter_test/flutter_test.dart';
import 'package:membership_tracker/models.dart';

void main() {
  group('Date Parsing Reproduction', () {
    test('Transaction parses ISO8601 correctly', () {
      final row = ['1', 'm1', '10.0', '2023-01-01T12:00:00.000', 'Payment'];
      final t = Transaction.fromRow(row);
      expect(t.date.year, 2023);
      expect(t.date.month, 1);
      expect(t.date.day, 1);
    });

    test('Transaction parses DD/MM/YYYY correctly (likely fails now)', () {
      final row = ['2', 'm1', '20.0', '31/01/2023', 'Payment'];
      final t = Transaction.fromRow(row);

      // If this fails (defaults to now), then that's the bug.
      // We expect it to be 2023-01-31.
      // If logic is broken, it will be Now().

      final now = DateTime.now();
      // We explicitly check if it matches "now" (which implies failure fallback)
      if (t.date.year == now.year &&
          t.date.month == now.month &&
          t.date.day == now.day) {
        fail(
          "Transaction date defaulted to Now, meaning parsing failed for DD/MM/YYYY",
        );
      }

      expect(t.date.year, 2023);
      expect(t.date.month, 1);
      expect(t.date.day, 31);
    });

    test('ClassSession parses DD/MM/YYYY', () {
      final row = ['s1', 'Class 1', '31/01/2023 10:00:00', 'false'];
      // Sheets might send '31/01/2023' or '31/01/2023 10:00:00'

      final s = ClassSession.fromRow(row);
      final now = DateTime.now();
      if (s.dateTime.year == now.year && s.dateTime.month == now.month) {
        fail("ClassSession date defaulted to Now");
      }
      expect(s.dateTime.year, 2023);
    });
  });
}
