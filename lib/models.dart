import 'package:uuid/uuid.dart';

class Member {
  final String id;
  String firstName;
  String lastName;
  DateTime dob;
  String medicalInfo;
  String contactInfo;
  double balance;

  Member({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.dob,
    required this.medicalInfo,
    required this.contactInfo,
    this.balance = 0.0,
  });

  factory Member.create({
    required String firstName,
    required String lastName,
    required DateTime dob,
    required String medicalInfo,
    required String contactInfo,
  }) {
    return Member(
      id: const Uuid().v4(),
      firstName: firstName,
      lastName: lastName,
      dob: dob,
      medicalInfo: medicalInfo,
      contactInfo: contactInfo,
    );
  }

  // From Google Sheet Row
  factory Member.fromRow(List<dynamic> row) {
    if (row.length < 7) throw Exception("Invalid row received for Member");
    return Member(
      id: row[0] as String,
      firstName: row[1] as String,
      lastName: row[2] as String,
      dob: DateTime.tryParse(row[3] as String) ?? DateTime.now(),
      medicalInfo: row[4] as String,
      contactInfo: row[5] as String,
      // Balance is computed, but we might store a cached version or 0
      balance: 0.0,
    );
  }

  List<dynamic> toRow() {
    return [
      id,
      firstName,
      lastName,
      dob.toIso8601String(),
      medicalInfo,
      contactInfo,
      "0", // Placeholder for cached balance if we wanted it
    ];
  }
}

class Transaction {
  final String id;
  final String memberId;
  final double amount;
  final DateTime date;
  final String description; // e.g. "Payment", "Class Fee"

  Transaction({
    required this.id,
    required this.memberId,
    required this.amount,
    required this.date,
    required this.description,
  });

  factory Transaction.create({
    required String memberId,
    required double amount,
    required String description,
  }) {
    return Transaction(
      id: const Uuid().v4(),
      memberId: memberId,
      amount: amount,
      date: DateTime.now(),
      description: description,
    );
  }

  factory Transaction.fromRow(List<dynamic> row) {
    if (row.length < 5) throw Exception("Invalid row received for Transaction");
    return Transaction(
      id: row[0],
      memberId: row[1],
      amount: double.tryParse(row[2].toString()) ?? 0.0,
      date: DateTime.tryParse(row[3].toString()) ?? DateTime.now(),
      description: row[4],
    );
  }

  List<dynamic> toRow() {
    return [
      id,
      memberId,
      amount.toString(),
      date.toIso8601String(),
      description,
    ];
  }
}

class ClassAttendance {
  final String id;
  final String memberId;
  final DateTime date;
  final String classType; // "Wednesday1", "Wednesday2", "Friday"

  ClassAttendance({
    required this.id,
    required this.memberId,
    required this.date,
    required this.classType,
  });

  factory ClassAttendance.create({
    required String memberId,
    required String classType,
  }) {
    return ClassAttendance(
      id: const Uuid().v4(),
      memberId: memberId,
      date: DateTime.now(),
      classType: classType,
    );
  }

  factory ClassAttendance.fromRow(List<dynamic> row) {
    if (row.length < 4) throw Exception("Invalid row received for Attendance");
    return ClassAttendance(
      id: row[0],
      memberId: row[1],
      date: DateTime.tryParse(row[2].toString()) ?? DateTime.now(),
      classType: row[3],
    );
  }

  List<dynamic> toRow() {
    return [id, memberId, date.toIso8601String(), classType];
  }
}
