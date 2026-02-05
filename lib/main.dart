// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironvault/core/navigation/global_nav.dart';
import 'core/autolock/auto_lock_provider.dart';
import 'core/theme/theme_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/encryption_util.dart';
import 'core/providers.dart';
import 'core/theme/app_tokens.dart';
import 'features/auth/screens/auth_choice_screen.dart';
import 'features/auth/screens/setup_pin_screen.dart';
import 'features/onboarding/screens/intro_carousel_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final autoLock = ref.read(autoLockProvider.notifier);

    if (state == AppLifecycleState.paused) {
      // App moved to background --> start timer
      autoLock.markPaused();
    }

    if (state == AppLifecycleState.resumed) {
      Future.microtask(() async {
        await autoLock.evaluateLockOnResume();
        final locked = ref.read(autoLockProvider);

        if (locked) {
          navKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AuthChoiceScreen()),
            (route) => false,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      navigatorKey: navKey,

      title: 'IronVault',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,

      // ---------- Light theme ----------
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),

      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final style = SystemUiOverlayStyle(
          statusBarColor: isDark ? AppColorsDark.bg : AppColorsLight.bg,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        );
        SystemChrome.setSystemUIOverlayStyle(style);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: style,
          child: SafeArea(
            top: false,
            bottom: true,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: const SplashScreen(),
    );
  }
}

/// Small splash flow that decides: Onboarding → Setup PIN → Login.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final storage = ref.read(secureStorageProvider);

    await Future.delayed(const Duration(milliseconds: 500));

    // Onboarding
    final onboardingDone =
        (await storage.readValue("onboarding_complete") ?? "false") == "true";

    if (!onboardingDone) {
      navKey.currentState?.pushReplacement(
        MaterialPageRoute(builder: (_) => const IntroCarouselScreen()),
      );
      return;
    }

    // Check master key + PIN
    final masterKey = await storage.readMasterKey();
    final pinHash = await storage.readPinHash();

    if (masterKey == null || pinHash == null) {
      final newKey = EncryptionUtil.generateKeyBase64();
      if (masterKey == null) {
        await storage.writeMasterKey(newKey);
      }

      navKey.currentState?.pushReplacement(
        MaterialPageRoute(builder: (_) => const SetupMasterPinScreen()),
      );
      return;
    }

    // User already set everything → go to auth choice
    navKey.currentState?.pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthChoiceScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B132B), Color(0xFF1C2541)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: 1.0,
                duration: const Duration(milliseconds: 600),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Image.asset(
                    "assets/icon/app_icon.png",
                    width: 96,
                    height: 96,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                "IronVault",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Secure vault",
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
