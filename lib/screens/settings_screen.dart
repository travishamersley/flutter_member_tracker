import 'package:flutter/material.dart';
import 'package:membership_tracker/controllers/club_controller.dart';
import 'package:membership_tracker/models.dart';

const bool kEnableDevControls = true; // Feature flag for developer features

class SettingsScreen extends StatefulWidget {
  final ClubController controller;

  const SettingsScreen({super.key, required this.controller});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _consentDocController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _consentDocController.text = widget.controller.consentDocumentText;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("App Settings")),
      body: SafeArea(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPriceRules(context),
            const SizedBox(height: 24),
            const Text(
              "Consent Document Text",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blueAccent),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _consentDocController,
              maxLines: 15,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Enter the legal consent documentation here...",
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  await widget.controller.updateConsentDoc(_consentDocController.text);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Settings saved successfully!")),
                    );
                    Navigator.pop(context);
                  }
                },
                child: const Text("Save Settings"),
              ),
            ),
            if (kEnableDevControls) ...[
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                "Developer Controls",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.redAccent),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                  ),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("Clear Data?"),
                        content: const Text("This will remove all classes, attendance, and payments. People will be kept. Proceed?"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text("Cancel"),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text("Clear"),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await widget.controller.clearClassesAndPayments();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Classes and payment info cleared.")),
                        );
                      }
                    }
                  },
                  child: const Text("Clear Classes & Payments"),
                ),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildPriceRules(BuildContext context) {
    // Sort rules latest to oldest for display
    final sortedRules = List<PriceRule>.from(widget.controller.priceRules)
      ..sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Class Price Schedule",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blueAccent),
        ),
        const SizedBox(height: 8),
        ...sortedRules.map((rule) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text("\$${rule.price.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Effective: ${rule.effectiveDate.toIso8601String().split('T').first}"),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                 if (widget.controller.priceRules.length == 1) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot delete the only price rule.")));
                   return;
                 }
                 setState(() {
                   widget.controller.priceRules.removeWhere((r) => r.id == rule.id);
                   widget.controller.savePriceRules(widget.controller.priceRules);
                 });
              },
            ),
          );
        }),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () => _showAddPriceRuleDialog(context),
          icon: const Icon(Icons.add),
          label: const Text("Schedule New Price"),
        )
      ],
    );
  }

  void _showAddPriceRuleDialog(BuildContext context) {
    final priceCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(context: context, builder: (ctx) {
      return StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text("Add Price Rule"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: "New Price", prefixText: "\$"),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text("Effective Date"),
                subtitle: Text(selectedDate.toIso8601String().split('T').first),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) {
                    setDialogState(() => selectedDate = d);
                  }
                },
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
                final newPrice = double.tryParse(priceCtrl.text);
                if (newPrice == null) return;

                DateTime? lastClassDate;
                if (widget.controller.classSessions.isNotEmpty) {
                  final completed = widget.controller.classSessions.where((s) => s.isCompleted).toList();
                  if (completed.isNotEmpty) {
                    completed.sort((a, b) => b.dateTime.compareTo(a.dateTime));
                    lastClassDate = completed.first.dateTime;
                  }
                }
                
                if (lastClassDate != null && selectedDate.isBefore(lastClassDate)) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Effective date must be after ${lastClassDate.toIso8601String().split('T').first} (Last Class).")),
                    );
                  }
                  return;
                }

                await widget.controller.addPriceRule(PriceRule.create(price: newPrice, effectiveDate: selectedDate));
                if (context.mounted) {
                  Navigator.pop(ctx);
                  setState(() {});
                }
              },
              child: const Text("Add"),
            ),
          ],
        );
      });
    });
  }
}
