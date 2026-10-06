import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

class LocalDbService {
  static final LocalDbService _instance = LocalDbService._internal();
  factory LocalDbService() => _instance;
  LocalDbService._internal();

  static const String _boxName = 'offline_entries';
  static const String _deletedMastersBox = 'deleted_masters';
  static const String _settingsBox = 'app_settings';
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    await Hive.initFlutter();
    await Hive.openBox(_boxName);
    await Hive.openBox(_deletedMastersBox);
    await Hive.openBox(_settingsBox);
    _isInitialized = true;
  }

  void saveActiveTab(int index) {
    try {
      Hive.box(_settingsBox).put('active_tab', index);
    } catch (_) {}
  }

  int? getActiveTab() {
    try {
      return Hive.box(_settingsBox).get('active_tab');
    } catch (_) {
      return null;
    }
  }

  void saveDeletedMaster(String type, String name) {
    try {
      final box = Hive.box(_deletedMastersBox);
      List<String> list = box.get(type, defaultValue: <String>[])?.cast<String>() ?? [];
      if (!list.contains(name)) {
        list.add(name);
        box.put(type, list);
      }
    } catch (_) {}
  }

  List<String> getDeletedMasters(String type) {
    try {
      final box = Hive.box(_deletedMastersBox);
      return box.get(type, defaultValue: <String>[])?.cast<String>() ?? [];
    } catch (_) {
      return [];
    }
  }

  void removeDeletedMaster(String type, String name) {
    try {
      final box = Hive.box(_deletedMastersBox);
      List<String> list = box.get(type, defaultValue: <String>[])?.cast<String>() ?? [];
      if (list.contains(name)) {
        list.remove(name);
        box.put(type, list);
      }
    } catch (_) {}
  }

  Future<void> insertEntry(String collectionName, Map<String, dynamic> data, {String operation = 'ADD', String? docId}) async {
    final box = Hive.box(_boxName);
    const uuid = Uuid();
    final id = uuid.v4();

    final sanitizedData = Map<String, dynamic>.from(data);
    sanitizedData.removeWhere((key, value) => value.toString() == 'FieldValue(serverTimestamp)');

    await box.put(id, {
      'id': id,
      'collectionName': collectionName,
      'operation': operation,
      'docId': docId,
      'data': jsonEncode(sanitizedData, toEncodable: (Object? nonEncodable) {
        if (nonEncodable is DateTime) return nonEncodable.toIso8601String();
        // Fallback for FieldValue or any other custom classes
        return nonEncodable.toString();
      }),
      'isSynced': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getUnsyncedEntries() async {
    final box = Hive.box(_boxName);
    final List<Map<String, dynamic>> unsynced = [];
    
    for (var key in box.keys) {
      final entry = box.get(key);
      if (entry != null && entry['isSynced'] == 0) {
        // Convert from dynamic map to Map<String, dynamic>
        unsynced.add(Map<String, dynamic>.from(entry));
      }
    }
    return unsynced;
  }

  Future<void> markAsSynced(String id) async {
    final box = Hive.box(_boxName);
    final entry = box.get(id);
    if (entry != null) {
      entry['isSynced'] = 1;
      await box.put(id, entry);
    }
  }

  Future<void> deleteSyncedEntries() async {
    final box = Hive.box(_boxName);
    final keysToDelete = [];
    for (var key in box.keys) {
      final entry = box.get(key);
      if (entry != null && entry['isSynced'] == 1) {
        keysToDelete.add(key);
      }
    }
    await box.deleteAll(keysToDelete);
  }

  Future<void> deleteUnsyncedEntryByDocId(String docId) async {
    final box = Hive.box(_boxName);
    final keysToDelete = [];
    for (var key in box.keys) {
      final entry = box.get(key);
      if (entry != null && entry['docId'] == docId) {
        keysToDelete.add(key);
      }
    }
    if (keysToDelete.isNotEmpty) {
      await box.deleteAll(keysToDelete);
    }
  }
}

