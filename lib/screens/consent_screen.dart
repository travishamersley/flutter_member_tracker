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
      body: Stack(
        children: [
          // Hidden camera
          if (_cameraController != null && _cameraController!.value.isInitialized)
            Positioned(
              top: -1000,
              child: SizedBox(
                width: 10,
                height: 10,
                child: CameraPreview(_cameraController!),
              ),
            ),
          
          Column(
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
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text("Sign Below:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    ),
                    Signature(
                      controller: _signatureController,
                      height: 150,
                      backgroundColor: Colors.white,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () => _signatureController.clear(),
                          child: const Text("Clear"),
                        ),
                        ElevatedButton(
                          onPressed: _isSaving ? null : _acceptAndSign,
                          child: _isSaving
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator())
                              : const Text("Accept & Sign"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
