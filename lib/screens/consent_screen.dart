import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:signature/signature.dart';
import 'package:path_provider/path_provider.dart';

class ConsentScreen extends StatefulWidget {
  final String documentText;

  const ConsentScreen({super.key, required this.documentText});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  CameraController? _cameraController;
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Camera init failed: $e");
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _acceptAndSign() async {
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please provide a signature")),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final tempDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // 1. Take photo
      String? photoPath;
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        final xFile = await _cameraController!.takePicture();
        final savedPhoto = File('${tempDir.path}/photo_$timestamp.jpg');
        await File(xFile.path).copy(savedPhoto.path);
        photoPath = savedPhoto.path;
      }

      // 2. Save signature
      final sigBytes = await _signatureController.toPngBytes();
      final savedSig = File('${tempDir.path}/sig_$timestamp.png');
      await savedSig.writeAsBytes(sigBytes!);

      if (mounted) {
        Navigator.pop(context, {
          "signaturePath": savedSig.path,
          "photoPath": photoPath,
          "date": DateTime.now(),
          "docText": widget.documentText,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sign Consent")),
      body: SafeArea(
        child: Column(
          children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Text(
                widget.documentText,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          Container(
            color: Colors.grey.shade200,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Sign Below:",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueAccent),
                      ),
                      if (_cameraController != null && _cameraController!.value.isInitialized)
                        Row(
                          children: [
                            const Text("Capturing face... ", style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: SizedBox(
                                width: 40,
                                height: 40,
                                child: CameraPreview(_cameraController!),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Signature(
                  controller: _signatureController,
                  height: 150,
                  backgroundColor: Colors.white,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.clear, color: Colors.red),
                        label: const Text("Clear Signature", style: TextStyle(color: Colors.red)),
                        onPressed: () => _signatureController.clear(),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        icon: const Icon(Icons.check),
                        label: _isSaving 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                          : const Text("Save & Continue", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        onPressed: _isSaving ? null : _acceptAndSign,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
