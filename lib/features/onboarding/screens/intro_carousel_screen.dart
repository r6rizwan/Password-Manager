import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironvault/core/navigation/global_nav.dart';
import 'package:ironvault/core/providers.dart';
import 'package:ironvault/features/auth/screens/setup_pin_screen.dart';
import 'package:ironvault/core/theme/app_tokens.dart';

class IntroCarouselScreen extends ConsumerStatefulWidget {
  const IntroCarouselScreen({super.key});

  @override
  ConsumerState<IntroCarouselScreen> createState() =>
      _IntroCarouselScreenState();
}

class _IntroCarouselScreenState extends ConsumerState<IntroCarouselScreen> {
  final PageController _controller = PageController();
  int _pageIndex = 0;

  final List<_IntroSlide> slides = const [
    _IntroSlide(
      title: "Secure by Design",
      description:
          "Everything is encrypted locally with AES‑256 on your device.",
      icon: Icons.verified_user_outlined,
    ),
    _IntroSlide(
      title: "Unlock Your Way",
      description: "Use PIN or biometrics for quick, private access.",
      icon: Icons.lock_outline,
    ),
    _IntroSlide(
      title: "Recovery Ready",
      description:
          "Create a recovery key to reset your PIN without losing data.",
      icon: Icons.vpn_key_outlined,
    ),
    _IntroSlide(
      title: "Scan & Store",
      description: "Scan documents and keep them safe in your vault.",
      icon: Icons.document_scanner_outlined,
    ),
    _IntroSlide(
      title: "Stay Updated",
      description: "Get update prompts from GitHub Releases.",
      icon: Icons.system_update_alt,
    ),
  ];

  Future<void> _completeOnboarding() async {
    final storage = ref.read(secureStorageProvider);
    await storage.writeValue("onboarding_complete", "true");

    navKey.currentState?.pushReplacement(
      MaterialPageRoute(builder: (_) => const SetupMasterPinScreen()),
    );
  }

  void _nextPage() {
    if (_pageIndex == slides.length - 1) {
      _completeOnboarding();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _skip() => _completeOnboarding();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: TextButton(onPressed: _skip, child: const Text("Skip")),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: slides.length,
                  onPageChanged: (i) => setState(() => _pageIndex = i),
                  itemBuilder: (_, i) {
                    final slide = slides[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: theme.colorScheme.primary
                                  .withValues(alpha: 0.12),
                              child: Icon(
                                slide.icon,
                                size: 44,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              slide.title,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              slide.description,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: textMuted,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  slides.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _pageIndex == i ? 18 : 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _pageIndex == i
                          ? theme.colorScheme.primary
                          : Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _nextPage,
                    child: Text(
                      _pageIndex == slides.length - 1
                          ? "Set Master PIN"
                          : "Next",
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroSlide {
  final String title;
  final String description;
  final IconData icon;

  const _IntroSlide({
    required this.title,
    required this.description,
    required this.icon,
  });
}
