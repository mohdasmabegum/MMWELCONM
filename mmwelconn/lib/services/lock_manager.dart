// lib/services/lock_manager.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Simple manager to store per‑chat lock status (pin/pattern protection).
/// Uses [FlutterSecureStorage] to persist a map of chat IDs to a boolean
/// indicating whether the chat is locked. In a real app this could be
/// expanded to store the actual lock type and encrypted secret.
class LockManager {
  static final _storage = const FlutterSecureStorage();
  static const _keyPrefix = 'chat_lock_';

  /// Returns `true` if the given [chatId] is currently locked.
  static Future<bool> isLocked(String chatId) async {
    final value = await _storage.read(key: '$_keyPrefix$chatId');
    return value == 'true';
  }

  /// Sets the lock status for a chat.
  static Future<void> setLock(String chatId, bool locked) async {
    await _storage.write(key: '$_keyPrefix$chatId', value: locked.toString());
  }

  /// Clears the lock entry for a chat.
  static Future<void> clearLock(String chatId) async {
    await _storage.delete(key: '$_keyPrefix$chatId');
  }

  /// Clears all chat lock entries. Useful for a global "reset locks" action.
  static Future<void> clearAll() async {
    final allKeys = await _storage.readAll();
    for (final key in allKeys.keys) {
      if (key.startsWith(_keyPrefix)) {
        await _storage.delete(key: key);
      }
    }
  }
}
