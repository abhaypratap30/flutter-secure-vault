import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vault/data/models/vault_item.dart';
import 'package:vault/data/models/vault_note.dart';
import 'package:vault/data/services/backup_service.dart';

/// Core Vault Service responsible for AES-256 encryption, session isolation (Master vs Decoy),
/// biometric storage, and local filesystem database management.
class VaultService {
  static final VaultService _instance = VaultService._internal();
  factory VaultService() => _instance;
  VaultService._internal();

  /// Cloud Backup Service instance (Firebase with Mock fallback).
  final BackupService backupService = FirebaseBackupService();

  late SharedPreferences _prefs;

  // Storage directories
  late Directory _masterVaultDir;
  late Directory _decoyVaultDir;

  // Metadata database files
  late File _masterMetadataFile;
  late File _decoyMetadataFile;

  // Active session-bound variables
  late Directory _activeVaultDir;
  late File _activeMetadataFile;
  late File _activeNotesFile;

  final List<VaultItem> _items = [];
  final List<VaultNote> _notes = [];
  enc.Key? _currentKey;
  bool _isDecoySession = false;

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  /// Active list of encrypted media items.
  List<VaultItem> get items => _items;

  /// Active list of encrypted notes.
  List<VaultNote> get notes => _notes;

  /// True if current session is authenticated with Decoy PIN.
  bool get isDecoySession => _isDecoySession;

  /// Active session AES encryption key in memory.
  enc.Key? get currentKey => _currentKey;

  /// Initializes directories, Shared Preferences, and loads vault metadata.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await backupService.init();

    final appDocsDir = await getApplicationDocumentsDirectory();

    _masterVaultDir = Directory(path.join(appDocsDir.path, 'vault_storage'));
    _decoyVaultDir = Directory(path.join(appDocsDir.path, 'decoy_vault_storage'));

    if (!await _masterVaultDir.exists()) {
      await _masterVaultDir.create(recursive: true);
    }
    if (!await _decoyVaultDir.exists()) {
      await _decoyVaultDir.create(recursive: true);
    }

    _masterMetadataFile = File(path.join(_masterVaultDir.path, 'metadata.json'));
    _decoyMetadataFile = File(path.join(_decoyVaultDir.path, 'metadata.json'));

    // Default context is master
    _activeVaultDir = _masterVaultDir;
    _activeMetadataFile = _masterMetadataFile;
    _activeNotesFile = File(path.join(_activeVaultDir.path, 'notes.json.vault'));

    await _loadMetadata();
  }

  /// Check if Master PIN is configured.
  bool get isPinSet => _prefs.containsKey('vault_pin_hash');

  /// Check if Decoy PIN is configured.
  bool get isDecoyPinSet => _prefs.containsKey('vault_decoy_pin_hash');

  /// Check if vault is currently unlocked (encryption key in memory).
  bool get isUnlocked => _currentKey != null;

  // Touch Rhythm Lock Settings
  bool get isRhythmLockEnabled => _prefs.getBool('vault_rhythm_enabled') ?? false;
  Future<void> setRhythmLockEnabled(bool enabled) async => await _prefs.setBool('vault_rhythm_enabled', enabled);
  String get rhythmPattern => _prefs.getString('vault_rhythm_pattern') ?? '';
  Future<void> setRhythmPattern(String pattern) async => await _prefs.setString('vault_rhythm_pattern', pattern);

  // Biometric Gesture Decoy Settings
  bool get isBiometricGestureDecoyEnabled => _prefs.getBool('vault_bio_gesture_decoy') ?? false;
  Future<void> setBiometricGestureDecoyEnabled(bool enabled) async => await _prefs.setBool('vault_bio_gesture_decoy', enabled);

  // Flip-to-Hide Settings
  bool get isFlipToHideEnabled => _prefs.getBool('vault_flip_hide') ?? false;
  Future<void> setFlipToHideEnabled(bool enabled) async => await _prefs.setBool('vault_flip_hide', enabled);

  // Bluetooth Smart Key Settings
  bool get isBluetoothKeyEnabled => _prefs.getBool('vault_bt_key_enabled') ?? false;
  Future<void> setBluetoothKeyEnabled(bool enabled) async => await _prefs.setBool('vault_bt_key_enabled', enabled);
  String get bluetoothKeyDeviceName => _prefs.getString('vault_bt_device_name') ?? '';
  Future<void> setBluetoothKeyDeviceName(String name) async => await _prefs.setString('vault_bt_device_name', name);

  // Google Camouflage Mode Settings
  bool get isCamouflageEnabled => _prefs.getBool('vault_camouflage_enabled') ?? false;
  Future<void> setCamouflageEnabled(bool enabled) async => await _prefs.setBool('vault_camouflage_enabled', enabled);

  // Fake Crash PIN Settings
  String get fakeCrashPin => _prefs.getString('vault_fake_crash_pin') ?? '';
  Future<void> setFakeCrashPin(String pin) async => await _prefs.setString('vault_fake_crash_pin', pin);

  /// Configure Master PIN and derive AES encryption key.
  Future<bool> setPin(String pin) async {
    final hashedPin = _hashPin(pin);
    final success = await _prefs.setString('vault_pin_hash', hashedPin);
    if (success) {
      _isDecoySession = false;
      _activeVaultDir = _masterVaultDir;
      _activeMetadataFile = _masterMetadataFile;
      _activeNotesFile = File(path.join(_activeVaultDir.path, 'notes.json.vault'));
      _currentKey = _deriveKey(pin);

      if (isBiometricsEnabled) {
        await _secureStorage.write(key: 'vault_master_pin', value: pin);
      }
    }
    return success;
  }

  /// Configure Decoy PIN for alternate vault session.
  Future<bool> setDecoyPin(String pin) async {
    final hashedPin = _hashPin(pin);
    final success = await _prefs.setString('vault_decoy_pin_hash', hashedPin);
    if (success) {
      await _secureStorage.write(key: 'vault_decoy_pin', value: pin);
    }
    return success;
  }

  /// Remove configured Decoy PIN.
  Future<void> removeDecoyPin() async {
    await _prefs.remove('vault_decoy_pin_hash');
    await _secureStorage.delete(key: 'vault_decoy_pin');
  }

  /// Verifies PIN and opens corresponding vault session (Master or Decoy).
  Future<bool> verifyAndUnlock(String pin) async {
    final hashedPin = _hashPin(pin);

    // Check decoy first
    if (isDecoyPinSet) {
      final decoyHash = _prefs.getString('vault_decoy_pin_hash');
      if (hashedPin == decoyHash) {
        _isDecoySession = true;
        _activeVaultDir = _decoyVaultDir;
        _activeMetadataFile = _decoyMetadataFile;
        _activeNotesFile = File(path.join(_activeVaultDir.path, 'notes.json.vault'));
        _currentKey = _deriveKey(pin);

        await _loadMetadata();
        await loadNotes();
        return true;
      }
    }

    // Check master
    final masterHash = _prefs.getString('vault_pin_hash');
    if (hashedPin == masterHash) {
      _isDecoySession = false;
      _activeVaultDir = _masterVaultDir;
      _activeMetadataFile = _masterMetadataFile;
      _activeNotesFile = File(path.join(_activeVaultDir.path, 'notes.json.vault'));
      _currentKey = _deriveKey(pin);

      await _loadMetadata();
      await loadNotes();
      return true;
    }

    return false;
  }

  /// Locks vault, purges key and sensitive data from memory.
  void lock() {
    _currentKey = null;
    _items.clear();
    _notes.clear();
    _isDecoySession = false;
    _activeVaultDir = _masterVaultDir;
    _activeMetadataFile = _masterMetadataFile;
    _activeNotesFile = File(path.join(_activeVaultDir.path, 'notes.json.vault'));
  }

  String _hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }

  enc.Key _deriveKey(String pin) {
    final digest = sha256.convert(utf8.encode(pin));
    return enc.Key(Uint8List.fromList(digest.bytes));
  }

  Future<void> _loadMetadata() async {
    _items.clear();
    if (await _activeMetadataFile.exists()) {
      try {
        final content = await _activeMetadataFile.readAsString();
        if (content.isNotEmpty) {
          final List<dynamic> jsonList = json.decode(content) as List<dynamic>;
          for (var itemJson in jsonList) {
            _items.add(VaultItem.fromJson(itemJson as Map<String, dynamic>));
          }
        }
      } catch (e) {
        // Handle metadata read errors gracefully
      }
    }
  }

  Future<void> _saveMetadata() async {
    try {
      final jsonList = _items.map((item) => item.toJson()).toList();
      await _activeMetadataFile.writeAsString(json.encode(jsonList));
    } catch (e) {
      // Handle metadata write errors gracefully
    }
  }

  Uint8List _encryptBytes(Uint8List plainBytes) {
    if (_currentKey == null) throw Exception('Vault is locked');

    final iv = enc.IV.fromLength(16);
    final encrypter = enc.Encrypter(enc.AES(_currentKey!, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(plainBytes, iv: iv);

    final combined = Uint8List(iv.bytes.length + encrypted.bytes.length);
    combined.setAll(0, iv.bytes);
    combined.setAll(iv.bytes.length, encrypted.bytes);
    return combined;
  }

  Uint8List _decryptBytes(Uint8List cipherBytes) {
    if (_currentKey == null) throw Exception('Vault is locked');
    if (cipherBytes.length < 16) throw Exception('Invalid cipher bytes');

    final ivBytes = cipherBytes.sublist(0, 16);
    final encryptedBytes = cipherBytes.sublist(16);

    final iv = enc.IV(ivBytes);
    final encrypter = enc.Encrypter(enc.AES(_currentKey!, mode: enc.AESMode.cbc));
    final decrypted = encrypter.decryptBytes(enc.Encrypted(encryptedBytes), iv: iv);
    return Uint8List.fromList(decrypted);
  }

  /// Imports and encrypts gallery photo/video asset into vault storage.
  Future<bool> importAsset(AssetEntity asset) async {
    if (!_isUnlocked()) return false;

    try {
      final file = await asset.file;
      if (file == null) return false;

      final plainBytes = await file.readAsBytes();
      final encryptedBytes = _encryptBytes(plainBytes);

      final id = DateTime.now().microsecondsSinceEpoch.toString();
      final ext = path.extension(file.path);
      final filename = path.basename(file.path);
      final vaultFilePath = path.join(_activeVaultDir.path, '$id.vault');

      await File(vaultFilePath).writeAsBytes(encryptedBytes);

      final type = asset.type == AssetType.video ? 'video' : 'photo';
      final vaultItem = VaultItem(
        id: id,
        originalName: filename,
        fileExtension: ext,
        type: type,
        dateAdded: DateTime.now(),
        duration: asset.duration > 0 ? asset.duration : null,
        size: plainBytes.length,
      );

      final List<String> deletedIds = await PhotoManager.editor.deleteWithIds([asset.id]);
      if (deletedIds.isEmpty) {
        final localFile = File(vaultFilePath);
        if (await localFile.exists()) {
          await localFile.delete();
        }
        return false;
      }

      _items.add(vaultItem);
      await _saveMetadata();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Decrypts item bytes into memory.
  Future<Uint8List> decryptItemBytes(VaultItem item) async {
    if (!_isUnlocked()) throw Exception('Vault is locked');

    final vaultFilePath = path.join(_activeVaultDir.path, '${item.id}.vault');
    final file = File(vaultFilePath);
    if (!await file.exists()) {
      throw Exception('Vault item file not found');
    }

    final cipherBytes = await file.readAsBytes();
    return _decryptBytes(cipherBytes);
  }

  /// Writes decrypted media file into temporary cache for viewing.
  Future<File> getDecryptedTempFile(VaultItem item) async {
    if (!_isUnlocked()) throw Exception('Vault is locked');

    final decryptedBytes = await decryptItemBytes(item);
    final tempDir = await getTemporaryDirectory();
    final tempFile = File(path.join(tempDir.path, 'temp_${item.id}${item.fileExtension}'));

    await tempFile.writeAsBytes(decryptedBytes);
    return tempFile;
  }

  /// Restores item back to device public gallery.
  Future<bool> restoreItem(VaultItem item) async {
    if (!_isUnlocked()) return false;

    try {
      final decryptedBytes = await decryptItemBytes(item);

      if (item.type == 'video') {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(path.join(tempDir.path, 'restore_${item.id}${item.fileExtension}'));
        await tempFile.writeAsBytes(decryptedBytes);

        await PhotoManager.editor.saveVideo(
          tempFile,
          title: item.originalName,
        );

        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } else {
        await PhotoManager.editor.saveImage(
          decryptedBytes,
          filename: item.originalName,
        );
      }

      final vaultFilePath = path.join(_activeVaultDir.path, '${item.id}.vault');
      final localFile = File(vaultFilePath);
      if (await localFile.exists()) {
        await localFile.delete();
      }

      _items.removeWhere((x) => x.id == item.id);
      await _saveMetadata();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Permanently deletes vault item and encrypted file on disk.
  Future<bool> deleteItem(VaultItem item) async {
    try {
      final vaultFilePath = path.join(_activeVaultDir.path, '${item.id}.vault');
      final localFile = File(vaultFilePath);
      if (await localFile.exists()) {
        await localFile.delete();
      }

      _items.removeWhere((x) => x.id == item.id);
      await _saveMetadata();
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- Secure Notes ---

  Future<void> loadNotes() async {
    _notes.clear();
    if (await _activeNotesFile.exists()) {
      try {
        final cipherBytes = await _activeNotesFile.readAsBytes();
        final decryptedBytes = _decryptBytes(cipherBytes);
        final jsonStr = utf8.decode(decryptedBytes);
        final List<dynamic> jsonList = json.decode(jsonStr) as List<dynamic>;
        for (var noteJson in jsonList) {
          _notes.add(VaultNote.fromJson(noteJson as Map<String, dynamic>));
        }
      } catch (e) {
        // Handle note parse errors gracefully
      }
    }
  }

  Future<void> saveNotes() async {
    try {
      final jsonList = _notes.map((note) => note.toJson()).toList();
      final jsonStr = json.encode(jsonList);
      final plainBytes = Uint8List.fromList(utf8.encode(jsonStr));
      final encryptedBytes = _encryptBytes(plainBytes);
      await _activeNotesFile.writeAsBytes(encryptedBytes);
    } catch (e) {
      // Handle note save errors gracefully
    }
  }

  Future<void> addNote(String title, String content) async {
    if (!_isUnlocked()) return;
    final note = VaultNote(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      content: content,
      dateCreated: DateTime.now(),
      dateModified: DateTime.now(),
    );
    _notes.add(note);
    await saveNotes();
  }

  Future<void> updateNote(String id, String title, String content) async {
    if (!_isUnlocked()) return;
    final index = _notes.indexWhere((x) => x.id == id);
    if (index != -1) {
      _notes[index] = _notes[index].copyWith(
        title: title,
        content: content,
        dateModified: DateTime.now(),
      );
      await saveNotes();
    }
  }

  Future<void> deleteNote(String id) async {
    if (!_isUnlocked()) return;
    _notes.removeWhere((x) => x.id == id);
    await saveNotes();
  }

  // --- Biometric Authentication ---

  bool get isBiometricsEnabled => _prefs.getBool('vault_biometrics_enabled') ?? false;

  Future<bool> canUseBiometrics() async {
    try {
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      return false;
    }
  }

  Future<bool> enableBiometrics(String pin) async {
    if (await verifyAndUnlock(pin)) {
      await _secureStorage.write(key: 'vault_master_pin', value: pin);
      await _prefs.setBool('vault_biometrics_enabled', true);
      return true;
    }
    return false;
  }

  Future<void> disableBiometrics() async {
    await _secureStorage.delete(key: 'vault_master_pin');
    await _prefs.setBool('vault_biometrics_enabled', false);
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Scan fingerprint or Face ID to unlock your secure vault',
        biometricOnly: true,
      );

      if (didAuthenticate) {
        final pin = await _secureStorage.read(key: 'vault_master_pin');
        if (pin != null) {
          return await verifyAndUnlock(pin);
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> authenticateDecoyWithBiometrics() async {
    try {
      final pin = await _secureStorage.read(key: 'vault_decoy_pin');
      if (pin != null) {
        return await verifyAndUnlock(pin);
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // --- Cloud Sync / Backup ---

  Future<void> syncLocalToCloud() async {
    if (!_isUnlocked()) throw Exception('Vault is locked');
    for (var item in _items) {
      if (!backupService.isBackedUp(item.id)) {
        final vaultFilePath = path.join(_activeVaultDir.path, '${item.id}.vault');
        final file = File(vaultFilePath);
        if (await file.exists()) {
          await backupService.uploadBackup(item, file);
        }
      }
    }
  }

  Future<int> recoverFromCloud() async {
    if (!_isUnlocked()) throw Exception('Vault is locked');

    final cloudItems = await backupService.fetchBackupMetadataList();
    int recoveredCount = 0;

    for (var cloudItem in cloudItems) {
      final existsLocally = _items.any((x) => x.id == cloudItem.id);
      if (!existsLocally) {
        final targetPath = path.join(_activeVaultDir.path, '${cloudItem.id}.vault');
        final file = await backupService.downloadBackup(cloudItem.id, targetPath);
        if (file != null) {
          _items.add(cloudItem);
          recoveredCount++;
        }
      }
    }

    if (recoveredCount > 0) {
      await _saveMetadata();
    }

    return recoveredCount;
  }

  Future<void> simulateDeviceLoss() async {
    if (backupService is FirebaseBackupService) {
      await MockBackupService().simulateLocalDataLoss(_activeVaultDir, _activeMetadataFile);
    } else if (backupService is MockBackupService) {
      await (backupService as MockBackupService).simulateLocalDataLoss(_activeVaultDir, _activeMetadataFile);
    }
    _items.clear();
    _notes.clear();
    if (await _activeNotesFile.exists()) {
      await _activeNotesFile.delete();
    }
  }

  bool _isUnlocked() {
    return _currentKey != null;
  }
}
