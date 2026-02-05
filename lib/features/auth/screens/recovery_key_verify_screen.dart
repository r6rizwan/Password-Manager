import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironvault/core/providers.dart';
import 'package:ironvault/core/utils/recovery_key.dart';
import 'package:ironvault/features/auth/screens/reset_pin_screen.dart';

class RecoveryKeyVerifyScreen extends ConsumerStatefulWidget {
  const RecoveryKeyVerifyScreen({super.key});

  @override
  ConsumerState<RecoveryKeyVerifyScreen> createState() =>
      _RecoveryKeyVerifyScreenState();
}

class _RecoveryKeyVerifyScreenState
    extends ConsumerState<RecoveryKeyVerifyScreen> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final input = _controller.text.trim().toUpperCase();
    final stored = await ref.read(secureStorageProvider).readRecoveryKeyHash();
    if (stored == null) {
      setState(() => _error = 'No recovery key found on this device.');
      return;
    }
    if (RecoveryKeyUtil.hash(input) != stored) {
      setState(() => _error = 'Invalid recovery key.');
      return;
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ResetPinScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Use Recovery Key')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your recovery key',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'XXXX-XXXX-XXXX-XXXX',
                errorText: _error,
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _verify,
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
