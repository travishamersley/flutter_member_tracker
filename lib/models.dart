import 'dart:convert';
import 'package:uuid/uuid.dart';

class MedicalHistory {
  bool backInjury;
  bool hernia;
  bool epilepsy;
  bool allergies;
  bool heartCondition;
  bool physicalDisability;
  bool asthma;
  bool psychological;
  bool other;
  String? otherDetails;

  MedicalHistory({
    this.backInjury = false,
    this.hernia = false,
    this.epilepsy = false,
    this.allergies = false,
    this.heartCondition = false,
    this.physicalDisability = false,
    this.asthma = false,
    this.psychological = false,
    this.other = false,
    this.otherDetails,
  });

  Map<String, dynamic> toJson() {
    return {
      'backInjury': backInjury,
      'hernia': hernia,
      'epilepsy': epilepsy,
      'allergies': allergies,
      'heartCondition': heartCondition,
      'physicalDisability': physicalDisability,
      'asthma': asthma,
      'psychological': psychological,
      'other': other,
      'otherDetails': otherDetails,
    };
  }

  factory MedicalHistory.fromJson(Map<String, dynamic> json) {
    return MedicalHistory(
      backInjury: json['backInjury'] ?? false,
      hernia: json['hernia'] ?? false,
      epilepsy: json['epilepsy'] ?? false,
      allergies: json['allergies'] ?? false,
      heartCondition: json['heartCondition'] ?? false,
      physicalDisability: json['physicalDisability'] ?? false,
      asthma: json['asthma'] ?? false,
      psychological: json['psychological'] ?? false,
      other: json['other'] ?? false,
      otherDetails: json['otherDetails'],
    );
  }

  @override
  String toString() {
    final List<String> conditions = [];
    if (backInjury) conditions.add("Back Injury");
    if (hernia) conditions.add("Hernia");
    if (epilepsy) conditions.add("Epilepsy");
    if (allergies) conditions.add("Allergies");
    if (heartCondition) conditions.add("Heart Condition");
    if (physicalDisability) conditions.add("Physical Disability");
    if (asthma) conditions.add("Asthma");
    if (psychological) conditions.add("Psychological");
    if (other) conditions.add("Other: ${otherDetails ?? ''}");

    if (conditions.isEmpty) return "None";
    return conditions.join(", ");
  }
}

class Member {
  final String id;
  String firstName;
  String lastName;
  String address;
  String email;
  DateTime dob;
  String mobile;
  String homePhone;
  String emergencyContact;
  MedicalHistory medicalHistory;
  bool hasBeenSuspended;
  String? suspendedDetails;
  String heardAbout;
  String? legalGuardian; // Required if age < 18
  bool consentSigned;

  String? familyGroupId;
  double balance;

  Member({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.address,
    required this.email,
    required this.dob,
    required this.mobile,
    this.homePhone = "",
    required this.emergencyContact,
    required this.medicalHistory,
    this.hasBeenSuspended = false,
    this.suspendedDetails,
    required this.heardAbout,
    this.legalGuardian,
    this.consentSigned = false,
    this.familyGroupId,
    this.balance = 0.0,
  });

  factory Member.create({
    required String firstName,
    required String lastName,
    required String address,
    required String email,
    required DateTime dob,
    required String mobile,
    String homePhone = "",
    required String emergencyContact,
    required MedicalHistory medicalHistory,
    bool hasBeenSuspended = false,
    String? suspendedDetails,
    required String heardAbout,
    String? legalGuardian,
    bool consentSigned = false,
    String? familyGroupId,
  }) {
    return Member(
      id: const Uuid().v4(),
      firstName: firstName,
      lastName: lastName,
      address: address,
      email: email,
      dob: dob,
      mobile: mobile,
      homePhone: homePhone,
      emergencyContact: emergencyContact,
      medicalHistory: medicalHistory,
      hasBeenSuspended: hasBeenSuspended,
      suspendedDetails: suspendedDetails,
      heardAbout: heardAbout,
      legalGuardian: legalGuardian,
      consentSigned: consentSigned,
      familyGroupId: familyGroupId,
    );
  }

  // Calculate age helper
  int get age {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  String get contactInfo =>
      "$email | $mobile"; // Backwards compatibility helper for UI display

  String get medicalInfo =>
      medicalHistory.toString(); // Backwards compatibility for UI display

  // From Google Sheet Row
  factory Member.fromRow(List<dynamic> row) {
    if (row.length < 15) {
      // Handle legacy or invalid rows gracefully?
      // User said they will delete all data, so we can be strict or default.
      // Let's try to parse what we can or default.
      // But for now, let's assume correct schema or throw.
      // Given "I will delete all existing data", we expect fresh rows.
    }

    // Safety check for index availability
    dynamic getCol(int index) => (index < row.length) ? row[index] : "";

    // Parse Medical History JSON
    MedicalHistory medHist;
    try {
      String jsonStr = getCol(9).toString();
      if (jsonStr.isNotEmpty && jsonStr != "null") {
        medHist = MedicalHistory.fromJson(jsonDecode(jsonStr));
      } else {
        medHist = MedicalHistory();
      }
    } catch (e) {
      medHist = MedicalHistory();
    }

    return Member(
      id: getCol(0).toString(),
      firstName: getCol(1).toString(),
      lastName: getCol(2).toString(),
      address: getCol(3).toString(),
      email: getCol(4).toString(),
      dob: _parseDate(getCol(5).toString()) ?? DateTime.now(),
      mobile: getCol(6).toString(),
      homePhone: getCol(7).toString(),
      emergencyContact: getCol(8).toString(),
      medicalHistory: medHist,
      hasBeenSuspended: getCol(10).toString().toLowerCase() == 'true',
      suspendedDetails: getCol(11).toString(),
      heardAbout: getCol(12).toString(),
      legalGuardian: getCol(13).toString(),
      consentSigned: getCol(14).toString().toLowerCase() == 'true',
      familyGroupId:
          (getCol(15).toString() == 'null' || getCol(15).toString().isEmpty)
          ? null
          : getCol(15).toString(),
      balance: 0.0,
    );
  }

  List<dynamic> toRow() {
    return [
      id,
      firstName,
      lastName,
      address,
      email,
      dob.toIso8601String(),
      mobile,
      homePhone,
      emergencyContact,
      jsonEncode(medicalHistory.toJson()),
      hasBeenSuspended.toString(),
      suspendedDetails ?? "",
      heardAbout,
      legalGuardian ?? "",
      consentSigned.toString(),
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
      date: _parseDate(row[3].toString()) ?? DateTime.now(),
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
      dateTime: _parseDate(row[2] as String) ?? DateTime.now(),
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
      date: _parseDate(row[2].toString()) ?? DateTime.now(),
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

DateTime? _parseDate(String input) {
  if (input.isEmpty || input == 'null') return null;
  final cleanInput = input.trim();

  // 1. ISO 8601
  try {
    final iso = DateTime.tryParse(cleanInput);
    if (iso != null) return iso;
  } catch (_) {}

  // 2. DD/MM/YYYY
  try {
    final parts = cleanInput.split('/');
    if (parts.length == 3) {
      final part1 = int.parse(parts[0].trim());
      final part2 = int.parse(parts[1].trim());
      final part3Str = parts[2].trim().split(' ')[0];
      final part3 = int.parse(part3Str);
      return DateTime(part3, part2, part1);
    }
  } catch (_) {}

  return null;
}
