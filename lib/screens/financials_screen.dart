import 'package:flutter/material.dart';
import 'package:membership_tracker/controllers/club_controller.dart';
import 'package:membership_tracker/models.dart';

class FinancialsScreen extends StatelessWidget {
  final ClubController controller;

  const FinancialsScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final transactions = List<Transaction>.from(controller.transactions)
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(title: const Text("Financial History")),
      body: ListView.builder(
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          final t = transactions[index];
          // Find member name
          final member = controller.members.firstWhere(
            (m) => m.id == t.memberId,
            orElse: () => Member(
              id: '?',
              firstName: 'Unknown',
              lastName: '',
              address: '',
              email: '',
              dob: DateTime.now(),
              mobile: '',
              emergencyContact: '',
              medicalHistory: MedicalHistory(),
              heardAbout: '',
            ),
          );

          return ListTile(
            leading: const Icon(Icons.attach_money, color: Colors.green),
            title: Text(
              "\$${t.amount.toStringAsFixed(2)} - ${member.firstName} ${member.lastName}",
            ),
            subtitle: Text(t.description),
            trailing: Text(t.date.toIso8601String().split('T').first),
          );
        },
      ),
    );
  }
}
