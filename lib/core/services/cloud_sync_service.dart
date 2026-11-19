import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'local_storage_service.dart';

/// Cloud backup of medicines and dose history (Phase 1 of docs/FAMILY_SHARING_PLAN.md).
///
/// The phone stays the main copy and works offline. Each change is pushed to the user's
/// own space in Firestore (users/{uid}/medicines, users/{uid}/doseLogs); [syncNow] merges
/// both ways, newest change wins. Deletions are kept as markers ("tombstones") so they
/// reach other phones instead of the record coming back.

/// Local Hive box names -> Firestore collection names.
const Map<String, String> kSyncedCollections = {'medicines': 'medicines', 'dose_logs': 'doseLogs'};

const String kDeletedFlag = 'deleted';

int syncStamp(Map<String, dynamic>? record) => (record?[kSyncUpdatedAt] as num?)?.toInt() ?? 0;

/// Where synced records live: Firestore in the app, an in-memory fake in tests.
abstract class CloudBackend {
  Future<Map<String, Map<String, dynamic>>> fetchAll(String uid, String collection);
  Future<void> put(String uid, String collection, String id, Map<String, dynamic> data);
  /// Deletes the backup for [uid] (and, with [includeFamily], the family lists, reminders
  /// and device tokens too: account deletion). Completes only when the server confirmed it.
  Future<void> deleteAll(String uid, {bool includeFamily = false});
}

class FirestoreBackend implements CloudBackend {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid, String collection) =>
      _db.collection('users').doc(uid).collection(collection);

  @override
  Future<Map<String, Map<String, dynamic>>> fetchAll(String uid, String collection) async {
    // From the server: a merge against a stale offline cache could undo newer changes.
    final snap = await _col(uid, collection).get(const GetOptions(source: Source.server));
    return {for (final d in snap.docs) d.id: d.data()};
  }

  @override
  Future<void> put(String uid, String collection, String id, Map<String, dynamic> data) =>
      _col(uid, collection).doc(id).set(data);

  @override
  Future<void> deleteAll(String uid, {bool includeFamily = false}) async {
    final collections = [
      ...kSyncedCollections.values,
      if (includeFamily) ...const ['family', 'caring', 'nudges', 'devices'],
    ];
    for (final collection in collections) {
      final snap = await _col(uid, collection).get(const GetOptions(source: Source.server));
      for (var i = 0; i < snap.docs.length; i += 400) {
        final batch = _db.batch();
        for (final d in snap.docs.skip(i).take(400)) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    }
  }
}

/// Used when Firebase is not available (widget tests): stores nothing.
class NoCloudBackend implements CloudBackend {
  @override
  Future<Map<String, Map<String, dynamic>>> fetchAll(String uid, String collection) async => {};
  @override
  Future<void> put(String uid, String collection, String id, Map<String, dynamic> data) async {}
  @override
  Future<void> deleteAll(String uid, {bool includeFamily = false}) async {}
}

/// What a merge decided for one collection.
class MergePlan {
  final Map<String, Map<String, dynamic>> toLocal = {};
  final Set<String> deleteLocal = {};
  final Map<String, Map<String, dynamic>> toCloud = {};

  bool get changesLocal => toLocal.isNotEmpty || deleteLocal.isNotEmpty;
}

/// Merges one collection. [localDeleted] maps ids deleted on this phone (while the backup
/// was off or offline) to when they were deleted. Newest change wins; ties change nothing.
MergePlan planMerge({
  required Map<String, Map<String, dynamic>> local,
  required Map<String, Map<String, dynamic>> cloud,
  Map<String, int> localDeleted = const {},
  required int now,
}) {
  final plan = MergePlan();
  Map<String, dynamic> tombstone(String id, int at) => {'id': id, kDeletedFlag: true, kSyncUpdatedAt: at};

  for (final entry in cloud.entries) {
    final id = entry.key;
    final remote = entry.value;
    final mine = local[id];
    final remoteStamp = syncStamp(remote);
    final deletedHereAt = localDeleted[id];

    if (deletedHereAt != null && mine == null) {
      // Deleted on this phone: keep it deleted unless the cloud copy changed afterwards.
      if (remote[kDeletedFlag] != true && remoteStamp > deletedHereAt) {
        plan.toLocal[id] = remote;
      } else if (remote[kDeletedFlag] != true) {
        plan.toCloud[id] = tombstone(id, deletedHereAt);
      }
      continue;
    }
    if (remote[kDeletedFlag] == true) {
      if (mine != null) {
        if (syncStamp(mine) > remoteStamp) {
          plan.toCloud[id] = mine;
        } else {
          plan.deleteLocal.add(id);
        }
      }
      continue;
    }
    if (mine == null || remoteStamp > syncStamp(mine)) {
      plan.toLocal[id] = Map<String, dynamic>.from(remote)..remove(kDeletedFlag);
    } else if (syncStamp(mine) > remoteStamp) {
      plan.toCloud[id] = mine;
    }
  }

  for (final entry in local.entries) {
    if (cloud.containsKey(entry.key)) continue;
    // Records saved before the backup existed have no stamp: give them one now.
    plan.toCloud[entry.key] = syncStamp(entry.value) == 0 ? {...entry.value, kSyncUpdatedAt: now} : entry.value;
  }
  for (final entry in localDeleted.entries) {
    if (!cloud.containsKey(entry.key) && !local.containsKey(entry.key)) {
      plan.toCloud[entry.key] = tombstone(entry.key, entry.value);
    }
  }
  return plan;
}

/// Deletions made on this phone that the cloud has not heard about yet, kept across restarts.
abstract class PendingDeletes {
  Future<Map<String, int>> read(String uid, String collection);
  Future<void> add(String uid, String collection, String id, int at);
  Future<void> clear(String uid, String collection);
  Future<int?> lastSync(String uid);
  Future<void> setLastSync(String uid, int at);
}

class HivePendingDeletes implements PendingDeletes {
  Future<Box<Map>> _box(String uid) async {
    final name = 'sync_state_$uid';
    return Hive.isBoxOpen(name) ? Hive.box<Map>(name) : Hive.openBox<Map>(name);
  }

  @override
  Future<Map<String, int>> read(String uid, String collection) async {
    final raw = (await _box(uid)).get('deleted_$collection');
    return raw == null ? {} : raw.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
  }

  @override
  Future<void> add(String uid, String collection, String id, int at) async {
    final box = await _box(uid);
    final current = Map<String, int>.from(await read(uid, collection))..[id] = at;
    await box.put('deleted_$collection', current);
  }

  @override
  Future<void> clear(String uid, String collection) async => (await _box(uid)).delete('deleted_$collection');

  @override
  Future<int?> lastSync(String uid) async => ((await _box(uid)).get('meta')?['lastSync'] as num?)?.toInt();

  @override
  Future<void> setLastSync(String uid, int at) async => (await _box(uid)).put('meta', {'lastSync': at});
}

class InMemoryPendingDeletes implements PendingDeletes {
  final Map<String, Map<String, int>> _deleted = {};
  final Map<String, int> _lastSync = {};
  @override
  Future<Map<String, int>> read(String uid, String collection) async => {...?_deleted['$uid/$collection']};
  @override
  Future<void> add(String uid, String collection, String id, int at) async =>
      (_deleted['$uid/$collection'] ??= {})[id] = at;
  @override
  Future<void> clear(String uid, String collection) async => _deleted.remove('$uid/$collection');
  @override
  Future<int?> lastSync(String uid) async => _lastSync[uid];
  @override
  Future<void> setLastSync(String uid, int at) async => _lastSync[uid] = at;
}

/// Shown in Settings.
class SyncStatus {
  const SyncStatus({this.lastSync, this.syncing = false, this.error});
  final DateTime? lastSync;
  final bool syncing;
  final String? error;
}

class CloudSyncService implements StorageChangeListener {
  CloudSyncService({
    required this.backend,
    required this.storage,
    required this.isEnabled,
    PendingDeletes? pending,
    int Function()? clock,
  })  : pending = pending ?? HivePendingDeletes(),
        _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch);

  final CloudBackend backend;
  final LocalStorageService storage;
  final bool Function() isEnabled;
  final PendingDeletes pending;
  final int Function() _clock;

  final ValueNotifier<SyncStatus> status = ValueNotifier(const SyncStatus());
  Future<bool>? _running;

  // Changes made on this phone: sent straight away (Firestore queues them while offline).

  @override
  void medicineSaved(String uid, Map<String, dynamic> data) => _push(uid, 'medicines', data);
  @override
  void doseLogSaved(String uid, Map<String, dynamic> data) => _push(uid, 'dose_logs', data);
  @override
  void medicineDeleted(String uid, String id) => _deleted(uid, 'medicines', id);
  @override
  void doseLogDeleted(String uid, String id) => _deleted(uid, 'dose_logs', id);

  void _push(String uid, String collection, Map<String, dynamic> data) {
    if (!isEnabled()) return;
    final id = data['id']?.toString();
    if (id == null || id.isEmpty) return;
    _guard(backend.put(uid, kSyncedCollections[collection]!, id, data));
  }

  void _deleted(String uid, String collection, String id) {
    final at = _clock();
    // Remembered either way, so a deletion made while the backup is off is not undone
    // later by an old cloud copy (a deleted medicine coming back would ring alarms).
    _guard(pending.add(uid, collection, id, at));
    if (isEnabled()) {
      _guard(backend.put(uid, kSyncedCollections[collection]!, id, {'id': id, kDeletedFlag: true, kSyncUpdatedAt: at}));
    }
  }

  void _guard(Future<void> f) {
    f.catchError((Object e) {
      debugPrint('[CloudSync] $e');
      status.value = SyncStatus(lastSync: status.value.lastSync, error: e.toString());
    });
  }

  /// Merges this phone and the cloud both ways. Returns true if data on the phone changed
  /// (the caller then reloads medicines and logs). Only one sync runs at a time.
  Future<bool> syncNow(String uid) {
    if (!isEnabled()) return Future.value(false);
    return _running ??= _sync(uid).whenComplete(() => _running = null);
  }

  Future<bool> _sync(String uid) async {
    status.value = SyncStatus(lastSync: status.value.lastSync, syncing: true);
    try {
      var changed = false;
      for (final entry in kSyncedCollections.entries) {
        final localName = entry.key;
        final cloudName = entry.value;
        final cloud = await backend.fetchAll(uid, cloudName);
        final plan = planMerge(
          local: storage.rawRecords(localName, uid),
          cloud: cloud,
          localDeleted: await pending.read(uid, localName),
          now: _clock(),
        );
        for (final e in plan.toLocal.entries) {
          await storage.putRecordFromCloud(localName, uid, e.key, e.value);
        }
        for (final id in plan.deleteLocal) {
          await storage.deleteRecordFromCloud(localName, uid, id);
        }
        for (final e in plan.toCloud.entries) {
          await backend.put(uid, cloudName, e.key, e.value);
        }
        await pending.clear(uid, localName);
        changed = changed || plan.changesLocal;
      }
      final now = _clock();
      await pending.setLastSync(uid, now);
      status.value = SyncStatus(lastSync: DateTime.fromMillisecondsSinceEpoch(now));
      return changed;
    } catch (e) {
      debugPrint('[CloudSync] sync failed: $e');
      final last = await pending.lastSync(uid);
      status.value = SyncStatus(
        lastSync: last == null ? null : DateTime.fromMillisecondsSinceEpoch(last),
        error: e.toString(),
      );
      return false;
    }
  }

  /// Loads the last successful sync time for Settings.
  Future<void> loadStatus(String uid) async {
    final last = await pending.lastSync(uid);
    if (last != null && status.value.lastSync == null) {
      status.value = SyncStatus(lastSync: DateTime.fromMillisecondsSinceEpoch(last));
    }
  }

  /// Deletes the user's backup (turning the backup off), or with [includeFamily] everything
  /// the account stored in the cloud (account deletion).
  Future<void> deleteCloudData(String uid, {bool includeFamily = false}) =>
      backend.deleteAll(uid, includeFamily: includeFamily);
}
