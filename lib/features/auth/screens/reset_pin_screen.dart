// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironvault/core/providers.dart';
import 'package:ironvault/core/utils/pin_kdf.dart';
import 'package:ironvault/features/auth/screens/auth_choice_screen.dart';
import 'package:ironvault/core/theme/app_tokens.dart';

class ResetPinScreen extends ConsumerStatefulWidget {
  const ResetPinScreen({super.key});

  @override
  ConsumerState<ResetPinScreen> createState() => _ResetPinScreenState();
}

class _ResetPinScreenState extends ConsumerState<ResetPinScreen> {
  final int pinLength = 4;

  final List<TextEditingController> _pin = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<TextEditingController> _confirm = List.generate(
    4,
    (_) => TextEditingController(),
  );

  final List<FocusNode> _pinNodes = List.generate(4, (_) => FocusNode());
  final List<FocusNode> _confirmNodes = List.generate(4, (_) => FocusNode());

  bool _loading = false;

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _collect(List<TextEditingController> list) {
    return list.map((c) => c.text).join();
  }

  Future<void> _savePin() async {
    final pin = _collect(_pin);
    final confirm = _collect(_confirm);

    if (pin.length < 4 || confirm.length < 4) {
      _showMsg("Please enter all 4 digits");
      return;
    }

    if (pin != confirm) {
      _showMsg("PINs do not match");
      return;
    }

    setState(() => _loading = true);

    final storage = ref.read(secureStorageProvider);
    await storage.writePinHash(PinKdf.hashPin(pin));

    setState(() => _loading = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AuthChoiceScreen()),
    );
  }

  Widget _otpBox({
    required TextEditingController controller,
    required FocusNode node,
    required VoidCallback onNext,
    required VoidCallback onBack,
  }) {
    return SizedBox(
      width: 60,
      child: TextField(
        controller: controller,
        focusNode: node,
        maxLength: 1,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: "",
          filled: true,
          fillColor: Theme.of(context).inputDecorationTheme.fillColor,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.grey.shade400,
              width: 1.4,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 1.8,
            ),
          ),
        ),
        cursorColor: Theme.of(context).colorScheme.primary,
        onChanged: (value) {
          if (value.isEmpty) {
            onBack();
          } else {
            onNext();
          }
        },
      ),
    );
  }

  Widget _otpRow(
    List<TextEditingController> controllers,
    List<FocusNode> nodes,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pinLength, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: _otpBox(
            controller: controllers[i],
            node: nodes[i],
            onNext: () {
              if (i < pinLength - 1) {
                nodes[i + 1].requestFocus();
              }
            },
            onBack: () {
              if (i > 0) {
                controllers[i - 1].clear();
                nodes[i - 1].requestFocus();
              }
            },
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = AppThemeColors.text(context);
    final textMuted = AppThemeColors.textMuted(context);
    final bgGradient = LinearGradient(
      colors: isDark
          ? [const Color(0xFF0B0F1A), const Color(0xFF121826)]
          : [const Color(0xFFF7FAFF), const Color(0xFFEAF2FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Scaffold(
      appBar: AppBar(title: const Text("Reset PIN")),
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      "Set a new PIN",
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: textColor),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Confirm to regain access.",
                      style: TextStyle(
                        fontSize: 12,
                        color: textMuted,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Enter PIN",
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _otpRow(_pin, _pinNodes),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Confirm PIN",
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _otpRow(_confirm, _confirmNodes),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _savePin,
                        child: _loading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text("Continue"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
