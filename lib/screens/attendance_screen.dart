import 'package:flutter/material.dart';
import 'package:membership_tracker/controllers/club_controller.dart';
import 'package:membership_tracker/models.dart';
import 'package:intl/intl.dart';

class AttendanceScreen extends StatefulWidget {
  final ClubController controller;

  const AttendanceScreen({super.key, required this.controller});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  // If we are viewing a specific past session, this ID is set.
  // If null, we show the Dashboard (which might show active class or start button).
  ClassSession? _viewingHistorySession;

  @override
  Widget build(BuildContext context) {
    // 1. If viewing history, show History Detail
    if (_viewingHistorySession != null) {
      return _buildHistoryDetailView(_viewingHistorySession!);
    }

    // 2. Dashboard View
    return Scaffold(
      appBar: AppBar(title: const Text("Class Dashboard")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildActiveSection(),
              const SizedBox(height: 24),
              const Text(
                "Recent Classes",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildHistoryList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveSection() {
    final active = widget.controller.activeSession;

    if (active != null) {
      // Active Class Card - Improved Contrast
      return Card(
        color: Colors.blue[800], // Darker background
        elevation: 4,
        child: InkWell(
          onTap: () => _navigateToClass(active),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Text(
                  "Current Class in Progress",
                  style: TextStyle(
                    color: Colors.white, // White text
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  active.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white, // White text
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Tap to Check In / Manage",
                      style: TextStyle(color: Colors.white70),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, color: Colors.white),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // No Active Class - "Start Class" Button
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 100,
            child: ElevatedButton.icon(
              onPressed: () => _startSession(isGrading: false),
              icon: const Icon(Icons.play_arrow, size: 36),
              label: const Text("START CLASS", style: TextStyle(fontSize: 20)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: ElevatedButton.icon(
              onPressed: () => _startSession(isGrading: true),
              icon: const Icon(Icons.star, size: 36),
              label: const Text("START GRADING", style: TextStyle(fontSize: 20)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildHistoryList() {
    final past = widget.controller.pastSessions;
    if (past.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("No previous classes found."),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: past.length,
      itemBuilder: (context, index) {
        final session = past[index];
        // Count attendees
        final count = widget.controller.attendance
            .where((a) => a.classSessionId == session.id)
            .length;

        return Card(
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.blueGrey, // Better contrast than grey
              child: Icon(Icons.history, color: Colors.white),
            ),
            title: Text(session.name),
            subtitle: Text(
              DateFormat('MMM d, y h:mm a').format(session.dateTime),
            ),
            trailing: Chip(label: Text("$count Students")),
            onTap: () {
              setState(() {
                _viewingHistorySession = session;
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildHistoryDetailView(ClassSession session) {
    final attendees = widget.controller.attendance
        .where((a) => a.classSessionId == session.id)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text("History: ${session.name}"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _viewingHistorySession = null),
        ),
      ),
      body: attendees.isEmpty
          ? const Center(child: Text("No students attended this class."))
          : ListView.builder(
              itemCount: attendees.length,
              itemBuilder: (context, index) {
                final att = attendees[index];
                final member = widget.controller.members.firstWhere(
                  (m) => m.id == att.memberId,
                  orElse: () => Member(
                    id: '',
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

                // Find if they paid for this specific class?
                // Hard to link specific transaction to attendance unless we stored transactionId in attendance.
                // But current logic is "CheckInAndPay" adds a generic payment.
                // We can check if there's a payment from this user around the same time?
                // Or just show "Attended". The user asked for "if they paid that lesson".
                // Detailed tracking requires updated model.
                // For now, we only show they attended.
                // User said: "listing only students who participated and if they paid that lesson, and how much they paid."
                // Since we don't link Transaction <-> Attendance explicitly,
                // we'll look for transactions from this member on the SAME DAY as the session.

                final payments = widget.controller.transactions.where((t) {
                  if (t.memberId != member.id) return false;

                  // Strict Logic: Only count payments explicitly linked to this session.
                  // Bulk payments (null classSessionId) are ignored for this specific view.
                  if (t.classSessionId != null &&
                      t.classSessionId!.isNotEmpty) {
                    return t.classSessionId == session.id;
                  }

                  return false;
                }).toList();

                final totalPaid = payments.fold(
                  0.0,
                  (sum, t) => sum + t.amount,
                );

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        // Row 1: Name and Balance
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${member.firstName} ${member.lastName}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (member.balance >= 0
                                            ? Colors.green
                                            : Colors.red)
                                        .withOpacity(0.1),
                                border: Border.all(
                                  color: member.balance >= 0
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "Bal: \$${member.balance.toStringAsFixed(2)}",
                                style: TextStyle(
                                  color: member.balance >= 0
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                        // Row 2: Financial Breakdown
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Debit
                            Text(
                              "${session.isGrading ? 'Grading' : 'Class'} Fee: -\$${widget.controller.classPrice.toStringAsFixed(2)}",
                              style: const TextStyle(color: Colors.red),
                            ),
                            // Payment
                            if (payments.isNotEmpty)
                              Text(
                                "Paid: +\$${totalPaid.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            else
                              const Text(
                                "Paid: \$0.00",
                                style: TextStyle(color: Colors.grey),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _navigateToClass(ClassSession session) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ActiveClassScreen(controller: widget.controller, session: session),
      ),
    ).then((_) => setState(() {}));
  }

  Future<void> _startSession({required bool isGrading}) async {
    final title = isGrading ? "Start Grading" : "Start Class";
    final message = isGrading ? "Start a new grading session now?" : "Start a new class now?";

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Start"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.controller.createClassForNow(isGrading: isGrading);
      setState(() {});

      // Auto-navigate to the new active session
      final active = widget.controller.activeSession;
      if (active != null) {
        _navigateToClass(active);
      }
    }
  }
}

// ----------------------------------------------------------------------
// Active Class Screen (Check-in Mode)
// ----------------------------------------------------------------------

class ActiveClassScreen extends StatefulWidget {
  final ClubController controller;
  final ClassSession session;

  const ActiveClassScreen({
    super.key,
    required this.controller,
    required this.session,
  });

  @override
  State<ActiveClassScreen> createState() => _ActiveClassScreenState();
}

class _ActiveClassScreenState extends State<ActiveClassScreen> {
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    // attenEdees for THIS session
    final attendedIds = widget.controller.attendance
        .where((a) => a.classSessionId == widget.session.id)
        .map((a) => a.memberId)
        .toSet();

    // Filter members
    final members = widget.controller.members.where((m) {
      final query = _searchQuery.toLowerCase();
      return m.firstName.toLowerCase().contains(query) ||
          m.lastName.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Active Class", style: TextStyle(fontSize: 16)),
            Text(
              widget.session.name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          // End Class Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ElevatedButton.icon(
              onPressed: _endClass,
              icon: const Icon(Icons.stop),
              label: const Text("END CLASS"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
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
          Expanded(
            child: ListView.builder(
              itemCount: members.length,
              itemBuilder: (context, index) {
                final member = members[index];
                final isCheckedIn = attendedIds.contains(member.id);
                // We show balance here for active check-in context
                final hasPaid = widget.controller.hasPaidForSession(member.id, widget.session.id);
                final balance = widget.controller.getMemberBalance(member.id);

                Color balanceColor = Colors.grey;
                if (balance > 0) balanceColor = Colors.green;
                if (balance < 0) balanceColor = Colors.red;

                Widget trailingWidget;

                if (widget.session.isGrading) {
                  if (isCheckedIn) {
                    trailingWidget = const Chip(
                      label: Text("Graded", style: TextStyle(color: Colors.white, fontSize: 12)),
                      backgroundColor: Colors.green,
                      visualDensity: VisualDensity.compact,
                    );
                  } else {
                    trailingWidget = OutlinedButton.icon(
                      onPressed: () => _showGradeDialog(context, member),
                      icon: const Icon(Icons.star, color: Colors.amber, size: 16),
                      label: const Text("Grade", style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: Colors.amber.shade700,
                        side: BorderSide(color: Colors.amber.shade700),
                      ),
                    );
                  }
                } else {
                  if (isCheckedIn && hasPaid) {
                    trailingWidget = const Chip(
                      label: Text("Done", style: TextStyle(color: Colors.white, fontSize: 12)),
                      backgroundColor: Colors.green,
                      visualDensity: VisualDensity.compact,
                    );
                  } else if (isCheckedIn && !hasPaid) {
                    trailingWidget = Row(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         const Icon(Icons.check_circle, color: Colors.green, size: 20),
                         const SizedBox(width: 8),
                         ElevatedButton(
                           onPressed: () async {
                              await widget.controller.recordPayment(member.id, widget.controller.classPrice, "Class Payment", widget.session.id);
                              setState(() {});
                           },
                           onLongPress: () => _showCustomPaymentDialog(context, member),
                           style: ElevatedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                           ),
                           child: Text("Pay \$${widget.controller.classPrice.toInt()}"),
                         ),
                       ],
                    );
                  } else {
                    trailingWidget = Row(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         OutlinedButton(
                           onPressed: () async {
                              await widget.controller.checkIn(member.id, widget.session.id);
                              setState(() {});
                           },
                           style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                           ),
                           child: const Text("In Only", style: TextStyle(fontSize: 12)),
                         ),
                         const SizedBox(width: 4),
                         ElevatedButton(
                           onPressed: () async {
                              await widget.controller.checkInAndPay(member.id, widget.session.id, widget.controller.classPrice);
                              setState(() {});
                           },
                           onLongPress: () => _showCustomPaymentDialog(context, member),
                           style: ElevatedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                           ),
                           child: Text("Pay \$${widget.controller.classPrice.toInt()} & In", style: const TextStyle(fontSize: 12)),
                         ),
                       ],
                    );
                  }
                }

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    visualDensity: VisualDensity.compact,
                    title: InkWell(
                      onTap: () => _showCustomPaymentDialog(context, member),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              "${member.firstName} ${member.lastName}",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: balanceColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "\$${balance.toStringAsFixed(2)}",
                              style: TextStyle(
                                 color: balanceColor,
                                 fontWeight: FontWeight.bold,
                                 fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing: trailingWidget,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _endClass() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("End Class?"),
        content: const Text(
          "This will close the session. You won't be able to check in more members.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              "End Class",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.controller.endClass(widget.session);
      if (mounted) Navigator.pop(context); // Go back to Dashboard
    }
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
            child: const Text("Pay Only"),
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
                await widget.controller.checkIn(
                  member.id,
                  widget.session.id,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                setState(() {}); // Refresh balance & checkin state
              }
            },
            child: const Text("Pay & In"),
          ),
        ],
      ),
    );
  }

  Future<void> _showGradeDialog(BuildContext context, dynamic member) async {
    String? selectedGradeId = widget.controller.gradeLevels.first.id;
    final notesController = TextEditingController();
    final areasController = TextEditingController();
    final feeController = TextEditingController(text: "0.00");

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text("Grade ${member.firstName}"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedGradeId,
                      decoration: const InputDecoration(labelText: "Select Grade"),
                      items: widget.controller.gradeLevels.map((g) {
                        return DropdownMenuItem(
                          value: g.id,
                          child: Text(g.name),
                        );
                      }).toList(),
                      onChanged: (val) => setDialogState(() => selectedGradeId = val),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: feeController,
                      decoration: const InputDecoration(labelText: "Grading Fee", prefixText: "\$"),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(labelText: "Notes"),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: areasController,
                      decoration: const InputDecoration(labelText: "Areas of Improvement"),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedGradeId != null) {
                      final fee = double.tryParse(feeController.text) ?? 0.0;
                      await widget.controller.recordGrading(
                        memberId: member.id,
                        gradeId: selectedGradeId!,
                        notes: notesController.text.trim(),
                        areasOfImprovement: areasController.text.trim(),
                        feeAmount: fee,
                        classSessionId: widget.session.id, // Links grade to this session
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      setState(() {}); // update outer screen
                    }
                  },
                  child: const Text("Record & Check In"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
