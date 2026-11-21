import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:munim_mobile/theme.dart';
import 'package:munim_mobile/services/config_service.dart';
import 'package:munim_mobile/screens/home_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _pickConfig() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Select MUNIM config file',
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _loading = false);
        return;
      }
      final path = result.files.single.path!;
      final content = await File(path).readAsString();
      final config = await ConfigService.importFromString(content);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(config: config)),
      );
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MunimTheme.navy,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              // Logo
              Row(children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: MunimTheme.gold,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('म',
                      style: TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold,
                        color: Color(0xFF071B49),
                      )),
                  ),
                ),
                const SizedBox(width: 14),
                const Text('MUNIM',
                  style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold,
                    color: Colors.white, letterSpacing: 1,
                  )),
              ]),
              const SizedBox(height: 16),
              Text('Mobile Invoice App',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withOpacity(0.6),
                )),
              const SizedBox(height: 60),
              // Setup card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Welcome to MUNIM Mobile',
                      style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold,
                        color: MunimTheme.text,
                      )),
                    const SizedBox(height: 8),
                    const Text(
                      'To get started, import your company config file '
                      'exported from MUNIM on your PC.',
                      style: TextStyle(
                        fontSize: 13, color: MunimTheme.muted, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    // Steps
                    _step('1', 'Open MUNIM on your PC'),
                    _step('2', 'Go to Utilities → Export Mobile Config'),
                    _step('3', 'Send the JSON file to this phone'),
                    _step('4', 'Tap the button below and select it'),
                    const SizedBox(height: 28),
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline,
                            color: MunimTheme.danger, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!,
                            style: const TextStyle(
                              color: MunimTheme.danger, fontSize: 13))),
                        ]),
                      ),
                      const SizedBox(height: 16),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _pickConfig,
                        icon: _loading
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.upload_file),
                        label: Text(
                          _loading ? 'Importing…' : 'Select Config File'),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Center(
                child: Text(
                  'Built for Indian traders · MUNIM v0.17',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _step(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          width: 24, height: 24,
          decoration: const BoxDecoration(
            color: MunimTheme.accent,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(num,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              )),
          ),
        ),
        const SizedBox(width: 10),
        Text(text,
          style: const TextStyle(
            fontSize: 13, color: MunimTheme.text)),
      ]),
    );
  }
}
