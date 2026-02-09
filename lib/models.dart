import 'package:uuid/uuid.dart';

class Member {
  final String id;
  String firstName;
  String lastName;
  DateTime dob;
  String medicalInfo;
  String contactInfo;
  String? familyGroupId; // New field for grouping families
  double balance;

  Member({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.dob,
    required this.medicalInfo,
    required this.contactInfo,
    this.familyGroupId,
    this.balance = 0.0,
  });

  factory Member.create({
    required String firstName,
    required String lastName,
    required DateTime dob,
    required String medicalInfo,
    required String contactInfo,
    String? familyGroupId,
  }) {
    return Member(
      id: const Uuid().v4(),
      firstName: firstName,
      lastName: lastName,
      dob: dob,
      medicalInfo: medicalInfo,
      contactInfo: contactInfo,
      familyGroupId: familyGroupId,
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
      // Check if row has familyGroupId at index 6 (actually index 6 was contact in old code? No.)
      // Old: 0=id, 1=first, 2=last, 3=dob, 4=medical, 5=contact
      // New: 6=familyGroupId?
      // Wait, let's check the old file content.
      // 0:id, 1:first, 2:last, 3:dob, 4:medical, 5:contact.
      // So row[6] would be the next one.
      familyGroupId: (row.length > 6) ? (row[6] as String).trim() : null,
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
      familyGroupId ?? "",
    ];
  }
}

class Transaction {
  final String id;
  final String memberId;
  final double amount;
  final DateTime date;
  final String description; // e.g. "Payment", "Class Fee"
  final String? classSessionId; // New field

  Transaction({
    required this.id,
    required this.memberId,
    required this.amount,
    required this.date,
    required this.description,
    this.classSessionId,
  });

  factory Transaction.create({
    required String memberId,
    required double amount,
    required String description,
    String? classSessionId,
  }) {
    return Transaction(
      id: const Uuid().v4(),
      memberId: memberId,
      amount: amount,
      date: DateTime.now(),
      description: description,
      classSessionId: classSessionId,
    );
  }

  factory Transaction.fromRow(List<dynamic> row) {
    if (row.length < 5) throw Exception("Invalid row received for Transaction");

    // Check for 6th column (classSessionId)
    String? sessionId;
    if (row.length > 5) {
      sessionId = row[5]?.toString().trim();
      if (sessionId == 'null' || sessionId!.isEmpty) sessionId = null;
    }

    return Transaction(
      id: row[0],
      memberId: row[1],
      amount: double.tryParse(row[2].toString()) ?? 0.0,
      date: DateTime.tryParse(row[3].toString()) ?? DateTime.now(),
      description: row[4],
      classSessionId: sessionId,
    );
  }

  List<dynamic> toRow() {
    return [
      id,
      memberId,
      amount.toString(),
      date.toIso8601String(),
      description,
      classSessionId ?? "",
    ];
  }
}

class ClassSession {
  final String id;
  final String name; // e.g., "Wednesday 5:00 PM"
  final DateTime dateTime;
  final bool isCompleted;

  ClassSession({
    required this.id,
    required this.name,
    required this.dateTime,
    this.isCompleted = false,
  });

  factory ClassSession.create({required String name}) {
    return ClassSession(
      id: const Uuid().v4(),
      name: name,
      dateTime: DateTime.now(),
      isCompleted: false,
    );
  }

  factory ClassSession.fromRow(List<dynamic> row) {
    if (row.length < 3)
      throw Exception("Invalid row received for ClassSession");
    return ClassSession(
      id: row[0] as String,
      name: row[1] as String,
      dateTime: DateTime.tryParse(row[2] as String) ?? DateTime.now(),
      isCompleted: (row.length > 3)
          ? (row[3].toString().toLowerCase() == 'true')
          : false,
    );
  }

  List<dynamic> toRow() {
    return [id, name, dateTime.toIso8601String(), isCompleted.toString()];
  }
}

class ClassAttendance {
  final String id;
  final String memberId;
  final DateTime date;
  final String? classSessionId; // New field linking to specific session
  final String? classType; // Deprecated/Legacy ("Wednesday1", etc.)

  ClassAttendance({
    required this.id,
    required this.memberId,
    required this.date,
    this.classSessionId,
    this.classType,
  });

  factory ClassAttendance.create({
    required String memberId,
    String? classSessionId,
    String? classType,
  }) {
    return ClassAttendance(
      id: const Uuid().v4(),
      memberId: memberId,
      date: DateTime.now(),
      classSessionId: classSessionId,
      classType: classType,
    );
  }

  factory ClassAttendance.fromRow(List<dynamic> row) {
    if (row.length < 3) throw Exception("Invalid row received for Attendance");
    // Row format: ID, MemberID, Date, ClassType (Legacy), ClassSessionID (New)
    // Legacy rows might only have 4 columns. New rows might have 5.

    String? legacyType;
    if (row.length > 3) legacyType = row[3]?.toString();

    String? sessionId;
    if (row.length > 4) sessionId = row[4]?.toString();

    return ClassAttendance(
      id: row[0],
      memberId: row[1],
      date: DateTime.tryParse(row[2].toString()) ?? DateTime.now(),
      classType: legacyType,
      classSessionId: sessionId,
    );
  }

  List<dynamic> toRow() {
    return [
      id,
      memberId,
      date.toIso8601String(),
      classType ?? "",
      classSessionId ?? "",
    ];
  }
}
