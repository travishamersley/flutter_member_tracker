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
        length: 3,
        child: Column(
          children: [
            _buildProfileHeader(context, balance),
            const TabBar(
              tabs: [
                Tab(text: "History"),
                Tab(text: "Gradings"),
                Tab(text: "Profile"),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildHistoryTab(transactions, attendance),
                  _buildGradingsTab(),
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

  Widget _buildGradingsTab() {
    final studentGrades = widget.controller.studentGrades
        .where((g) => g.memberId == widget.member.id)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader("Grading History"),
        if (studentGrades.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text("No gradings recorded yet"),
            ),
          ),
        ...studentGrades.map((g) {
          final gradeName = widget.controller.gradeLevels.firstWhere(
            (lvl) => lvl.id == g.gradeId,
            orElse: () => GradeLevel(id: '', name: 'Unknown'),
          ).name;

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        gradeName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(g.date.toIso8601String().split('T').first),
                    ],
                  ),
                  const Divider(),
                  if (g.notes.isNotEmpty) ...[
                    const Text("Notes:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(g.notes),
                    const SizedBox(height: 8),
                  ],
                  if (g.areasOfImprovement.isNotEmpty) ...[
                    const Text("Areas of Improvement:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(g.areasOfImprovement),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildProfileTab() {
    final studentGrades = widget.controller.studentGrades
        .where((g) => g.memberId == widget.member.id)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    String currentGradeName = "None";
    if (studentGrades.isNotEmpty) {
      final currentGradeId = studentGrades.first.gradeId;
      final grade = widget.controller.gradeLevels.firstWhere(
        (g) => g.id == currentGradeId,
        orElse: () => GradeLevel(id: '', name: 'Unknown Grade'),
      );
      currentGradeName = grade.name;
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader("Personal Details"),
            _infoRow("Current Grade", currentGradeName),
            _infoRow(
              "Date of Birth",
              widget.member.dob.toIso8601String().split('T').first,
            ),
            _infoRow("Age", widget.member.age.toString()),
            if (widget.member.age < 18)
              _infoRow("Legal Guardian", widget.member.legalGuardian ?? "N/A"),
            _infoRow("Address", widget.member.address),
            _infoRow("Email", widget.member.email),
            _infoRow("Heard About", widget.member.heardAbout),

            _sectionHeader("Contact Info"),
            _infoRow("Mobile", widget.member.mobile),
            _infoRow(
              "Home Phone",
              widget.member.homePhone.isNotEmpty
                  ? widget.member.homePhone
                  : "N/A",
            ),
            _infoRow("Emergency Contact", widget.member.emergencyContact),

            _sectionHeader("Medical History"),
            // Display as chips or list
            if (widget.member.medicalHistory.toString() == "None")
              const Text("None", style: TextStyle(color: Colors.white70))
            else
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: widget.member.medicalHistory
                    .toString()
                    .split(", ")
                    .map((condition) {
                      return Chip(label: Text(condition));
                    })
                    .toList(),
              ),

            if (widget.member.hasBeenSuspended) ...[
              _sectionHeader("Suspension Details"),
              Text(
                widget.member.suspendedDetails ?? "No details provided.",
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],

            _sectionHeader("Consent"),
            _infoRow(
              "Signed Consent Form",
              widget.member.consentSigned ? "Yes" : "No",
            ),

            const Divider(height: 32),
            _buildFamilySection(),

            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () {
                // Edit Logic
                // We should probably reuse MemberForm for editing too
                // For now, I'll just leave this as is or implement edit later if requested
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Edit functionality to be implemented"),
                  ),
                );
              },
              icon: const Icon(Icons.edit),
              label: const Text("Edit Details"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilySection() {
    final familyId = widget.member.familyGroupId;
    final List<Member> familyMembers = [];

    if (familyId != null && familyId.isNotEmpty) {
      familyMembers.addAll(
        widget.controller.members.where((m) => m.familyGroupId == familyId),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("Family Group"),
        if (familyId == null || familyId.isEmpty) ...[
          const Text("Not part of a family group."),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _showCreateFamilyDialog(),
            child: const Text("Create Family Group"),
          ),
        ] else ...[
          Text("Family Members (${familyMembers.length})"),
          const SizedBox(height: 8),
          ...familyMembers.map(
            (m) => ListTile(
              leading: const Icon(Icons.person),
              title: Text("${m.firstName} ${m.lastName}"),
              subtitle: m.id == widget.member.id
                  ? const Text("This Member")
                  : null,
              trailing: m.id == widget.member.id
                  ? null
                  : IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.red,
                      ),
                      onPressed: () async {
                        // Allow removing other members? Or just self leaving?
                        // Let's assume we can remove others if we want, or just "Leave" self.
                        // For now, let's keep it simple: Remove THIS member from family == Leave.
                        // To remove another member, we'd need to go to their profile or have a specific button.
                        // For simplicity, let's just show the list.
                      },
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text("Add Member"),
                onPressed: () => _showAddMemberToFamilyDialog(familyId),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
                label: const Text(
                  "Leave Family",
                  style: TextStyle(color: Colors.redAccent),
                ),
                onPressed: () async {
                  await widget.controller.removeFromFamilyGroup(widget.member);
                  setState(() {});
                },
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _showCreateFamilyDialog() {
    // Show list of members NOT in a family
    final candidates = widget.controller.members
        .where(
          (m) =>
              (m.familyGroupId == null || m.familyGroupId!.isEmpty) &&
              m.id != widget.member.id,
        )
        .toList();

    Map<String, bool> selected = {};

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Create Family Group"),
              content: SizedBox(
                width: double.maxFinite,
                child: candidates.isEmpty
                    ? const Text("No other available members to add.")
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: candidates.length,
                        itemBuilder: (context, index) {
                          final m = candidates[index];
                          return CheckboxListTile(
                            title: Text("${m.firstName} ${m.lastName}"),
                            value: selected[m.id] ?? false,
                            onChanged: (val) {
                              setState(() {
                                selected[m.id] = val ?? false;
                              });
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                if (candidates.isNotEmpty)
                  ElevatedButton(
                    onPressed: () async {
                      final membersToAdd = candidates
                          .where((m) => selected[m.id] == true)
                          .toList();
                      if (membersToAdd.isNotEmpty) {
                        await widget.controller.createFamilyGroup(
                          widget.member,
                          membersToAdd,
                        );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        this.setState(() {});
                      }
                    },
                    child: const Text("Create"),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddMemberToFamilyDialog(String familyId) {
    // Show list of members NOT in a family
    final candidates = widget.controller.members
        .where(
          (m) =>
              (m.familyGroupId == null || m.familyGroupId!.isEmpty) &&
              m.id != widget.member.id,
        )
        .toList();

    // Single select for simplicity or reuse the multi select
    // Let's allow adding one at a time for now to keep it simple or reuse the same logic
    // Actually, adding multiple at once is better.
    Map<String, bool> selected = {};

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Add to Family"),
              content: SizedBox(
                width: double.maxFinite,
                child: candidates.isEmpty
                    ? const Text("No available members to add.")
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: candidates.length,
                        itemBuilder: (context, index) {
                          final m = candidates[index];
                          return CheckboxListTile(
                            title: Text("${m.firstName} ${m.lastName}"),
                            value: selected[m.id] ?? false,
                            onChanged: (val) {
                              setState(() {
                                selected[m.id] = val ?? false;
                              });
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                if (candidates.isNotEmpty)
                  ElevatedButton(
                    onPressed: () async {
                      final membersToAdd = candidates
                          .where((m) => selected[m.id] == true)
                          .toList();
                      for (var m in membersToAdd) {
                        await widget.controller.addToFamilyGroup(m, familyId);
                      }
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      this.setState(() {});
                    },
                    child: const Text("Add"),
                  ),
              ],
            );
          },
        );
      },
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
