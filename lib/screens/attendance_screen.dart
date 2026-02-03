import 'package:flutter/material.dart';
import 'package:membership_tracker/controllers/club_controller.dart';

class AttendanceScreen extends StatefulWidget {
  final ClubController controller;

  const AttendanceScreen({super.key, required this.controller});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  String _selectedClass = "Wednesday1"; // Default
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    // Current Date
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month}-${now.day}";

    // Get members who have attended THIS class type TODAY
    final attendedMemberIds = widget.controller.attendance
        .where((a) {
          final aDate = "${a.date.year}-${a.date.month}-${a.date.day}";
          return aDate == todayStr && a.classType == _selectedClass;
        })
        .map((a) => a.memberId)
        .toSet();

    // Filter list for check-in
    final members = widget.controller.members.where((m) {
      final query = _searchQuery.toLowerCase();
      return m.firstName.toLowerCase().contains(query) ||
          m.lastName.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Class Check-In")),
      body: Column(
        children: [
          // Class Selector
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).cardColor,
            child: Row(
              children: [
                const Text(
                  "Select Class: ",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedClass,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: "Wednesday1",
                        child: Text("Wednesday - Class 1 (Kids/Beg)"),
                      ),
                      DropdownMenuItem(
                        value: "Wednesday2",
                        child: Text("Wednesday - Class 2 (Adults/Adv)"),
                      ),
                      DropdownMenuItem(
                        value: "Friday",
                        child: Text("Friday - Mixed Class"),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedClass = val);
                    },
                  ),
                ),
              ],
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: "Search Member to Check In",
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // List
          Expanded(
            child: ListView.builder(
              itemCount: members.length,
              itemBuilder: (context, index) {
                final member = members[index];
                final isCheckedIn = attendedMemberIds.contains(member.id);
                final balance = widget.controller.getMemberBalance(member.id);

                // Calculate approx classes remaining (Assuming $10/class)
                final classesRemaining = (balance / 10).floor();

                Color balanceColor = Colors.grey;
                if (balance > 0) balanceColor = Colors.green;
                if (balance < 0) balanceColor = Colors.red;

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Row: Name + Balance
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${member.firstName} ${member.lastName}",
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: balanceColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: balanceColor),
                              ),
                              child: Text(
                                "\$${balance.toStringAsFixed(2)} (${balance >= 0 ? '$classesRemaining left' : 'Owe'})",
                                style: TextStyle(
                                  color: balanceColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Actions Row
                        if (isCheckedIn)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            color: Colors.green.withValues(alpha: 0.1),
                            child: const Center(
                              child: Text(
                                "Check In Complete",
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                        else
                          Row(
                            children: [
                              // Pay & Check In
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    await widget.controller.checkInAndPay(
                                      member.id,
                                      _selectedClass,
                                      10.0, // Standard class price
                                    );
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.attach_money),
                                  label: const Text(
                                    "Pay \$10 & In",
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Check In Only
                              Expanded(
                                flex: 1,
                                child: OutlinedButton(
                                  onPressed: () async {
                                    await widget.controller.checkIn(
                                      member.id,
                                      _selectedClass,
                                    );
                                    setState(() {});
                                  },
                                  child: const Text(
                                    "In Only",
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Custom Payment
                              IconButton.filledTonal(
                                onPressed: () =>
                                    _showCustomPaymentDialog(context, member),
                                icon: const Icon(Icons.payments),
                                tooltip: "Custom Payment",
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCustomPaymentDialog(
    BuildContext context,
    dynamic member,
  ) async {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController(text: "Custom Payment");

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Add Funds for ${member.firstName}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: "Amount",
                prefixText: "\$",
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
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
                  member.id,
                  amount,
                  descriptionController.text,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                setState(() {}); // Refresh balance
              }
            },
            child: const Text("Add Funds"),
          ),
        ],
      ),
    );
  }
}
