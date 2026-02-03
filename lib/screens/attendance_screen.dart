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

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isCheckedIn ? Colors.green : Colors.grey,
                    child: Icon(isCheckedIn ? Icons.check : Icons.person),
                  ),
                  title: Text("${member.firstName} ${member.lastName}"),
                  trailing: isCheckedIn
                      ? const Chip(
                          label: Text("Checked In"),
                          backgroundColor: Colors.green,
                        )
                      : ElevatedButton(
                          onPressed: () async {
                            await widget.controller.checkIn(
                              member.id,
                              _selectedClass,
                            );
                            setState(() {}); // Refresh UI to show checkmark
                          },
                          child: const Text("Check In"),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
