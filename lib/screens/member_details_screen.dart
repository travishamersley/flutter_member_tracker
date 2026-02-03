import 'package:flutter/material.dart';
import 'package:membership_tracker/controllers/club_controller.dart';
import 'package:membership_tracker/models.dart';

class MemberDetailsScreen extends StatefulWidget {
  final ClubController controller;
  final Member member;

  const MemberDetailsScreen({
    super.key,
    required this.controller,
    required this.member,
  });

  @override
  State<MemberDetailsScreen> createState() => _MemberDetailsScreenState();
}

class _MemberDetailsScreenState extends State<MemberDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    // Re-fetch balance
    final balance = widget.controller.getMemberBalance(widget.member.id);

    // History
    final transactions =
        widget.controller.transactions
            .where((t) => t.memberId == widget.member.id)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date)); // Descending

    final attendance =
        widget.controller.attendance
            .where((a) => a.memberId == widget.member.id)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date)); // Descending

    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.member.firstName} ${widget.member.lastName}"),
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            _buildProfileHeader(context, balance),
            const TabBar(
              tabs: [
                Tab(text: "History"),
                Tab(text: "Profile"),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildHistoryTab(transactions, attendance),
                  _buildProfileTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPaymentDialog(context),
        label: const Text("Add Payment"),
        icon: const Icon(Icons.attach_money),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, double balance) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Theme.of(context).cardColor,
      width: double.infinity,
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Theme.of(context).primaryColor,
            child: Text(
              widget.member.firstName[0] + widget.member.lastName[0],
              style: const TextStyle(
                fontSize: 32,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Balance: \$${balance.abs().toStringAsFixed(2)}",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: balance < 0 ? Colors.redAccent : Colors.greenAccent,
            ),
          ),
          Text(balance < 0 ? "Outstanding Debt" : "Credit Available"),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(
    List<Transaction> transactions,
    List<ClassAttendance> attendance,
  ) {
    // Combine lists for a consolidated view? Or separate?
    // Let's do two sections.
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader("Recent Activity"),
        if (transactions.isEmpty && attendance.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text("No history yet"),
            ),
          ),

        ...transactions.map(
          (t) => ListTile(
            leading: const Icon(Icons.attach_money, color: Colors.green),
            title: Text("Payment: \$${t.amount.toStringAsFixed(2)}"),
            subtitle: Text(t.description),
            trailing: Text(t.date.toIso8601String().split('T').first),
          ),
        ),

        ...attendance.map(
          (a) => ListTile(
            leading: const Icon(Icons.sports_martial_arts, color: Colors.white),
            title: Text("Class: ${a.classType}"),
            subtitle: Text("Checked In"),
            trailing: Text(a.date.toIso8601String().split('T').first),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _infoRow(
            "Date of Birth",
            widget.member.dob.toIso8601String().split('T').first,
          ),
          _infoRow("Contact", widget.member.contactInfo),
          _infoRow("Medical", widget.member.medicalInfo),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () {
              // Edit Logic
            },
            icon: const Icon(Icons.edit),
            label: const Text("Edit Details"),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: Color(0xFFD4AF37),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showPaymentDialog(BuildContext context) {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController(text: "Fee Payment");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Record Payment"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: "Amount",
                prefixText: "\$",
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: "Description"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount != null) {
                await widget.controller.recordPayment(
                  widget.member.id,
                  amount,
                  descriptionController.text,
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                setState(() {});
              }
            },
            child: const Text("Pay"),
          ),
        ],
      ),
    );
  }
}
