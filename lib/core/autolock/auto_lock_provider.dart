import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironvault/core/providers.dart';

final autoLockProvider = NotifierProvider<AutoLockController, bool>(
  AutoLockController.new,
);

class AutoLockController extends Notifier<bool> {
  DateTime? _pausedAt;
  bool _suspended = false;
  bool _lockOnSwitch = true;
  bool _loadedPref = false;
  static const int _minBackgroundSeconds = 2;

  @override
  bool build() {
    _loadPreference();
    return false; // unlocked by default
  }

  /// Called when app goes inactive OR paused
  void markPaused() {
    if (_suspended || !_lockOnSwitch) return;
    _pausedAt = DateTime.now();
  }

  /// Decide if app should lock when resumed
  Future<void> evaluateLockOnResume() async {
    if (_suspended) {
      _resetPauseState();
      return;
    }
    final storage = ref.read(secureStorageProvider);
    final timer = await storage.readValue("auto_lock_timer") ?? "immediately";

    if (_pausedAt == null) return;
    final elapsed = DateTime.now().difference(_pausedAt!).inSeconds;
    if (elapsed < _minBackgroundSeconds) {
      _resetPauseState();
      return;
    }

    if (timer == "immediately") {
      state = true;
      _resetPauseState();
      return;
    }

    final seconds = int.tryParse(timer);
    if (seconds == null || _pausedAt == null) {
      _resetPauseState();
      return;
    }

    if (elapsed >= seconds) {
      state = true;
    }

    _resetPauseState();
  }

  /// Manual unlock
  void unlock() {
    state = false;
  }

  Future<void> setLockOnSwitch(bool enabled) async {
    _lockOnSwitch = enabled;
    final storage = ref.read(secureStorageProvider);
    await storage.writeValue('auto_lock_on_switch', enabled ? 'true' : 'false');
  }

  Future<void> _loadPreference() async {
    if (_loadedPref) return;
    _loadedPref = true;
    final storage = ref.read(secureStorageProvider);
    final value = await storage.readValue('auto_lock_on_switch');
    if (value == null) return;
    _lockOnSwitch = value == 'true';
  }

  /// Temporarily suspend auto-lock (e.g., while launching external scanner)
  void suspendAutoLock() {
    _suspended = true;
  }

  /// Resume auto-lock and clear any pause state
  void resumeAutoLock() {
    _suspended = false;
    _resetPauseState();
  }

  void _resetPauseState() {
    _pausedAt = null;
  }
}
