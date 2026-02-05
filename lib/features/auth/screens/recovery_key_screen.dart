import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ironvault/features/vault/screens/enable_biometrics_screen.dart';
import 'package:ironvault/core/theme/app_tokens.dart';

class RecoveryKeyScreen extends StatelessWidget {
  final String recoveryKey;
  final VoidCallback? onDone;
  final String doneLabel;

  const RecoveryKeyScreen({
    super.key,
    required this.recoveryKey,
    this.onDone,
    this.doneLabel = 'I have saved it',
  });

  @override
  Widget build(BuildContext context) {
    final textMuted = AppThemeColors.textMuted(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Recovery Key')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Save this key somewhere safe.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'You can use it to reset your PIN without losing data.',
              style: TextStyle(fontSize: 12, color: textMuted),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      recoveryKey,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: recoveryKey),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied to clipboard')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (onDone != null) {
                    onDone!();
                    return;
                  }
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EnableBiometricsScreen(),
                    ),
                  );
                },
                child: Text(doneLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
