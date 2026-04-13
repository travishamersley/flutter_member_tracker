import 'package:flutter/material.dart';
import 'package:membership_tracker/controllers/club_controller.dart';

import 'package:membership_tracker/screens/member_details_screen.dart';
import 'package:membership_tracker/widgets/member_form.dart';

class MembersScreen extends StatefulWidget {
  final ClubController controller;

  const MembersScreen({super.key, required this.controller});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    // Filter members
    final members = widget.controller.members.where((m) {
      final query = _searchQuery.toLowerCase();
      return m.firstName.toLowerCase().contains(query) ||
          m.lastName.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Members")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: "Search Members",
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: members.length,
              itemBuilder: (context, index) {
                final member = members[index];
                final balance = widget.controller.getMemberBalance(member.id);
                final isDebt = balance < 0;

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Text(
                        member.firstName[0] + member.lastName[0],
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      "${member.firstName} ${member.lastName}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(member.contactInfo),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "\$${balance.abs().toStringAsFixed(2)}",
                          style: TextStyle(
                            color: isDebt
                                ? Colors.redAccent
                                : Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          isDebt ? "DEBT" : "PRECO",
                          style: TextStyle(
                            color: isDebt
                                ? Colors.redAccent
                                : Colors.greenAccent,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MemberDetailsScreen(
                            controller: widget.controller,
                            member: member,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMemberDialog(context),
        label: const Text("Add Member"),
        icon: const Icon(Icons.person_add),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text("Add New Member")),
          body: MemberForm(
            controller: widget.controller,
            onSubmit: (member) async {
                  await widget.controller.addMemberObj(member);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  setState(() {}); // Refresh list
                },
          ),
        ),
      ),
    );
  }
}
