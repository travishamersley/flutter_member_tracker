import 'package:flutter/material.dart';
import 'package:membership_tracker/controllers/club_controller.dart';
import 'package:membership_tracker/screens/attendance_screen.dart';
import 'package:membership_tracker/screens/financials_screen.dart';
import 'package:membership_tracker/screens/members_screen.dart';
import 'package:membership_tracker/screens/grade_levels_screen.dart';
import 'package:membership_tracker/screens/settings_screen.dart';

class DashboardScreen extends StatelessWidget {
  final ClubController controller;

  const DashboardScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    // Calculate simple stats
    final totalMembers = controller.members.length;
    // Today's attendance
    final now = DateTime.now();
    final todayAttendance = controller.attendance
        .where(
          (a) =>
              a.date.year == now.year &&
              a.date.month == now.month &&
              a.date.day == now.day,
        )
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dojo Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(controller: controller),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (controller.lastError != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                color: Colors.red.shade100,
                child: Text(
                  controller.lastError!,
                  style: TextStyle(color: Colors.red.shade900),
                ),
              ),
            _buildStatCard(
              context,
              "Total Members",
              totalMembers.toString(),
              Icons.group,
            ),
            const SizedBox(height: 16),
            _buildStatCard(
              context,
              "Today's Attendance",
              todayAttendance.toString(),
              Icons.check_circle_outline,
            ),
            const SizedBox(height: 32),
            Text(
              "Quick Actions",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildActionButton(context, "Members", Icons.people, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MembersScreen(controller: controller),
                    ),
                  );
                }),
                _buildActionButton(
                  context,
                  "Check-In",
                  Icons.qr_code_scanner,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AttendanceScreen(controller: controller),
                      ),
                    );
                  },
                ),
                _buildActionButton(
                  context,
                  "Financials",
                  Icons.attach_money,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            FinancialsScreen(controller: controller),
                      ),
                    );
                  },
                ),
                _buildActionButton(
                  context,
                  "Grade Levels",
                  Icons.grade,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            GradeLevelsScreen(controller: controller),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Divider(),
            if (controller.isSyncing)
               const Center(child: CircularProgressIndicator())
            else
               Column(
                 children: [
                   Center(
                     child: ElevatedButton.icon(
                       icon: const Icon(Icons.table_view),
                       label: const Text("Export to Excel Workbook"),
                       style: ElevatedButton.styleFrom(
                         backgroundColor: Colors.green.shade50,
                         foregroundColor: Colors.green.shade800,
                         padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                         textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                       ),
                       onPressed: () {
                         controller.exportToExcel();
                       },
                     ),
                   ),
                   const SizedBox(height: 16),
                   Center(
                     child: OutlinedButton.icon(
                       icon: const Icon(Icons.file_upload),
                       label: const Text("Import from Excel"),
                       style: OutlinedButton.styleFrom(
                         padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                         textStyle: const TextStyle(fontSize: 16)
                       ),
                       onPressed: () {
                         controller.importExcel();
                       },
                     ),
                   )
                 ],
               ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            Icon(icon, size: 48, color: Theme.of(context).primaryColor),
            const SizedBox(width: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(minimumSize: const Size(150, 50)),
    );
  }
}
