// ignore_for_file: depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:ironvault/core/widgets/common_text_field.dart';
import 'package:ironvault/core/providers.dart';

class ChangePinScreen extends ConsumerStatefulWidget {
  const ChangePinScreen({super.key});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  final _oldPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  bool _loading = false;
  bool _showOld = false;
  bool _showNew = false;
  bool _showConfirm = false;

  String _hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _changePin() async {
    final oldPin = _oldPinController.text.trim();
    final newPin = _newPinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (newPin.length < 4) {
      _showMessage("New PIN must be at least 4 digits.");
      return;
    }

    if (newPin != confirmPin) {
      _showMessage("New PINs do not match.");
      return;
    }

    setState(() => _loading = true);

    final storage = ref.read(secureStorageProvider);
    final savedHash = await storage.readPinHash();

    // Validate old PIN
    if (_hashPin(oldPin) != savedHash) {
      setState(() => _loading = false);
      _showMessage("Incorrect old PIN.");
      return;
    }

    // Save new PIN hash
    await storage.writePinHash(_hashPin(newPin));

    setState(() => _loading = false);

    _showMessage("PIN updated successfully!");

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final spacing = const SizedBox(height: 16);

    return Scaffold(
      appBar: AppBar(title: const Text("Change Master PIN")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          children: [
            CommonTextField(
              label: "Old PIN",
              controller: _oldPinController,
              obscure: !_showOld,
              onToggle: () => setState(() => _showOld = !_showOld),
              keyboardType: TextInputType.number,
            ),

            spacing,

            CommonTextField(
              label: "New PIN",
              controller: _newPinController,
              obscure: !_showNew,
              onToggle: () => setState(() => _showNew = !_showNew),
              keyboardType: TextInputType.number,
            ),

            spacing,

            CommonTextField(
              label: "Confirm New PIN",
              controller: _confirmPinController,
              obscure: !_showConfirm,
              onToggle: () => setState(() => _showConfirm = !_showConfirm),
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _changePin,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text("Update PIN"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
