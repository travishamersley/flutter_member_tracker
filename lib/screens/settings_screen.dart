import 'package:flutter/material.dart';
import 'package:membership_tracker/controllers/club_controller.dart';

class SettingsScreen extends StatefulWidget {
  final ClubController controller;

  const SettingsScreen({super.key, required this.controller});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _classPriceController = TextEditingController();
  final _consentDocController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _classPriceController.text = widget.controller.classPrice.toString();
    _consentDocController.text = widget.controller.consentDocumentText;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("App Settings")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Default Class Cost",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blueAccent),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _classPriceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                prefixText: "\$",
                border: OutlineInputBorder(),
              ),
            ),
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
                  final newPrice = double.tryParse(_classPriceController.text) ?? widget.controller.classPrice;
                  await widget.controller.updateSettings(newPrice, _consentDocController.text);
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
          ],
        ),
      ),
    );
  }
}
