import 'package:flutter/material.dart';
import 'package:membership_tracker/controllers/club_controller.dart';

class GradeLevelsScreen extends StatefulWidget {
  final ClubController controller;

  const GradeLevelsScreen({super.key, required this.controller});

  @override
  State<GradeLevelsScreen> createState() => _GradeLevelsScreenState();
}

class _GradeLevelsScreenState extends State<GradeLevelsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Grade Levels Configuration"),
      ),
      body: widget.controller.gradeLevels.isEmpty
          ? const Center(child: Text("No Grade Levels configured. Add one below."))
          : ListView.builder(
              itemCount: widget.controller.gradeLevels.length,
              itemBuilder: (context, index) {
                final grade = widget.controller.gradeLevels[index];
                return ListTile(
                  leading: const Icon(Icons.star, color: Colors.amber),
                  title: Text(grade.name),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddGradeDialog(context),
        icon: const Icon(Icons.add),
        label: const Text("Add Grade Level"),
      ),
    );
  }

  Future<void> _showAddGradeDialog(BuildContext context) async {
    final gradeNameController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Grade Level"),
        content: TextField(
          controller: gradeNameController,
          decoration: const InputDecoration(labelText: "Grade Name (e.g., Yellow Belt)"),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (gradeNameController.text.trim().isNotEmpty) {
                await widget.controller.addGradeLevel(gradeNameController.text.trim());
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                setState(() {});
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }
}
