import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vault/data/models/vault_item.dart';

/// Abstract interface contract defining Cloud Backup and Recovery operations.
abstract class BackupService {
  /// Initializes backup service dependencies and states.
  Future<void> init();

  /// Indicates whether automatic background sync is enabled.
  bool get isAutoBackupEnabled;

  /// Enables or disables automatic cloud backup.
  Future<void> setAutoBackup(bool enabled);

  /// Uploads an encrypted file and its metadata index to the cloud server.
  Future<bool> uploadBackup(VaultItem item, File encryptedFile);

  /// Permanently removes a backup entry from the cloud storage and database.
  Future<bool> deleteBackup(String itemId);

  /// Fetches all backup metadata items belonging to the current session.
  Future<List<VaultItem>> fetchBackupMetadataList();

  /// Downloads an encrypted backup file from cloud storage to local vault storage.
  Future<File?> downloadBackup(String itemId, String targetPath);

  /// Checks if a specific item is backed up in cloud storage.
  bool isBackedUp(String itemId);
}

/// Local simulated cloud backup implementation used during offline or development modes.
class MockBackupService implements BackupService {
  static final MockBackupService _instance = MockBackupService._internal();
  factory MockBackupService() => _instance;
  MockBackupService._internal();

  late SharedPreferences _prefs;
  late Directory _cloudDir;
  late File _cloudMetadataFile;
  final List<VaultItem> _cloudItems = [];
  bool _autoBackup = true;

  @override
  bool get isAutoBackupEnabled => _autoBackup;

  @override
  Future<void> setAutoBackup(bool enabled) async {
    _autoBackup = enabled;
    await _prefs.setBool('vault_auto_backup', enabled);
  }

  @override
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _autoBackup = _prefs.getBool('vault_auto_backup') ?? true;

    final appDocsDir = await getApplicationDocumentsDirectory();
    _cloudDir = Directory(path.join(appDocsDir.path, 'vault_cloud_backup'));
    if (!await _cloudDir.exists()) {
      await _cloudDir.create(recursive: true);
    }

    _cloudMetadataFile = File(path.join(_cloudDir.path, 'cloud_metadata.json'));
    await _loadCloudMetadata();
  }

  Future<void> _loadCloudMetadata() async {
    _cloudItems.clear();
    if (await _cloudMetadataFile.exists()) {
      try {
        final content = await _cloudMetadataFile.readAsString();
        if (content.isNotEmpty) {
          final List<dynamic> jsonList = json.decode(content) as List<dynamic>;
          for (var itemJson in jsonList) {
            _cloudItems.add(VaultItem.fromJson(itemJson as Map<String, dynamic>));
          }
        }
      } catch (e) {
        // Handle metadata parse errors gracefully
      }
    }
  }

  Future<void> _saveCloudMetadata() async {
    try {
      final jsonList = _cloudItems.map((item) => item.toJson()).toList();
      await _cloudMetadataFile.writeAsString(json.encode(jsonList));
    } catch (e) {
      // Handle metadata write errors gracefully
    }
  }

  @override
  Future<bool> uploadBackup(VaultItem item, File encryptedFile) async {
    try {
      await Future.delayed(const Duration(milliseconds: 800));

      if (!await encryptedFile.exists()) {
        return false;
      }

      final cloudFilePath = path.join(_cloudDir.path, '${item.id}.vault');
      final fileData = await encryptedFile.readAsBytes();
      await File(cloudFilePath).writeAsBytes(fileData);

      _cloudItems.removeWhere((x) => x.id == item.id);
      _cloudItems.add(item);
      await _saveCloudMetadata();

      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> deleteBackup(String itemId) async {
    try {
      await Future.delayed(const Duration(milliseconds: 400));

      final cloudFilePath = path.join(_cloudDir.path, '$itemId.vault');
      final cloudFile = File(cloudFilePath);
      if (await cloudFile.exists()) {
        await cloudFile.delete();
      }

      _cloudItems.removeWhere((x) => x.id == itemId);
      await _saveCloudMetadata();

      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<VaultItem>> fetchBackupMetadataList() async {
    await Future.delayed(const Duration(milliseconds: 600));
    await _loadCloudMetadata();
    return List.from(_cloudItems);
  }

  @override
  Future<File?> downloadBackup(String itemId, String targetPath) async {
    try {
      await Future.delayed(const Duration(milliseconds: 1000));

      final cloudFilePath = path.join(_cloudDir.path, '$itemId.vault');
      final cloudFile = File(cloudFilePath);
      if (!await cloudFile.exists()) {
        return null;
      }

      final fileData = await cloudFile.readAsBytes();
      final localFile = File(targetPath);
      await localFile.writeAsBytes(fileData);

      return localFile;
    } catch (e) {
      return null;
    }
  }

  @override
  bool isBackedUp(String itemId) {
    return _cloudItems.any((x) => x.id == itemId);
  }

  /// Helper tool for testing data recovery by clearing local files.
  Future<void> simulateLocalDataLoss(Directory vaultDir, File metadataFile) async {
    if (await metadataFile.exists()) {
      await metadataFile.delete();
    }

    if (await vaultDir.exists()) {
      final list = vaultDir.listSync();
      for (var file in list) {
        if (file is File && path.extension(file.path) == '.vault') {
          await file.delete();
        }
      }
    }
  }
}

/// Firebase Cloud Backup implementation utilizing Anonymous Authentication, Firestore & Cloud Storage.
class FirebaseBackupService implements BackupService {
  static final FirebaseBackupService _instance = FirebaseBackupService._internal();
  factory FirebaseBackupService() => _instance;
  FirebaseBackupService._internal();

  final MockBackupService _mockFallback = MockBackupService();
  bool _isFirebaseReady = false;
  late SharedPreferences _prefs;
  bool _autoBackup = true;

  @override
  bool get isAutoBackupEnabled => _autoBackup;

  @override
  Future<void> setAutoBackup(bool enabled) async {
    _autoBackup = enabled;
    await _prefs.setBool('vault_auto_backup', enabled);
    await _mockFallback.setAutoBackup(enabled);
  }

  @override
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _autoBackup = _prefs.getBool('vault_auto_backup') ?? true;

    await _mockFallback.init();

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _isFirebaseReady = true;
      await _signInAnonymously();
    } catch (e) {
      _isFirebaseReady = false;
    }
  }

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  Future<void> _signInAnonymously() async {
    if (!_isFirebaseReady) return;
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
    } catch (e) {
      // Graceful fallback to offline mock mode
    }
  }

  @override
  Future<bool> uploadBackup(VaultItem item, File encryptedFile) async {
    await _mockFallback.uploadBackup(item, encryptedFile);

    if (!_isFirebaseReady || _userId == null) {
      return true;
    }

    try {
      final fileRef = FirebaseStorage.instance.ref('users/$_userId/vault_items/${item.id}.vault');
      await fileRef.putFile(encryptedFile);

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('vault_items')
          .doc(item.id);
      await docRef.set(item.toJson());

      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> deleteBackup(String itemId) async {
    await _mockFallback.deleteBackup(itemId);

    if (!_isFirebaseReady || _userId == null) {
      return true;
    }

    try {
      final fileRef = FirebaseStorage.instance.ref('users/$_userId/vault_items/$itemId.vault');
      await fileRef.delete();

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('vault_items')
          .doc(itemId);
      await docRef.delete();

      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<VaultItem>> fetchBackupMetadataList() async {
    if (!_isFirebaseReady || _userId == null) {
      return _mockFallback.fetchBackupMetadataList();
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('vault_items')
          .get();

      final List<VaultItem> list = [];
      for (var doc in snapshot.docs) {
        list.add(VaultItem.fromJson(doc.data()));
      }
      return list;
    } catch (e) {
      return _mockFallback.fetchBackupMetadataList();
    }
  }

  @override
  Future<File?> downloadBackup(String itemId, String targetPath) async {
    if (!_isFirebaseReady || _userId == null) {
      return _mockFallback.downloadBackup(itemId, targetPath);
    }

    try {
      final fileRef = FirebaseStorage.instance.ref('users/$_userId/vault_items/$itemId.vault');
      final targetFile = File(targetPath);
      await fileRef.writeToFile(targetFile);
      return targetFile;
    } catch (e) {
      return _mockFallback.downloadBackup(itemId, targetPath);
    }
  }

  @override
  bool isBackedUp(String itemId) {
    return _mockFallback.isBackedUp(itemId);
  }
}
