// Cloud backup (Phase 1): merge rules, pushing changes, restoring on a new phone.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:osudsheba/core/models/mock_models.dart';
import 'package:osudsheba/core/services/cloud_sync_service.dart';
import 'package:osudsheba/core/services/local_storage_service.dart';
import 'package:osudsheba/core/services/mock_data_service.dart';

/// In-memory stand-in for Firestore.
class FakeBackend implements CloudBackend {
  final Map<String, Map<String, Map<String, dynamic>>> data = {};
  bool offline = false;

  Map<String, Map<String, dynamic>> col(String uid, String c) => data.putIfAbsent('$uid/$c', () => {});

  @override
  Future<Map<String, Map<String, dynamic>>> fetchAll(String uid, String collection) async {
    if (offline) throw Exception('offline');
    return {for (final e in col(uid, collection).entries) e.key: Map.of(e.value)};
  }

  @override
  Future<void> put(String uid, String collection, String id, Map<String, dynamic> d) async {
    col(uid, collection)[id] = Map.of(d);
  }

  @override
  Future<void> deleteAll(String uid, {bool includeFamily = false}) async =>
      data.removeWhere((k, _) => k.startsWith('$uid/'));
}

Map<String, dynamic> rec(String id, int stamp, {bool deleted = false, String name = 'x'}) =>
    {'id': id, 'name': name, kSyncUpdatedAt: stamp, if (deleted) kDeletedFlag: true};

Medicine med(String id, {String name = 'Napa'}) => Medicine(
      id: id,
      name: name,
      strength: '500mg',
      form: MedicineForm.tablet,
      dose: '1 Tablet',
      times: const ['08:00 AM'],
      mealRelation: 'After Meal',
      instruction: '',
    );

void main() {
  group('merge rules', () {
    test('a record only on the phone is uploaded, stamped if it was never stamped', () {
      final plan = planMerge(local: {'a': {'id': 'a'}}, cloud: {}, now: 500);
      expect(plan.toCloud['a']![kSyncUpdatedAt], 500);
      expect(plan.changesLocal, isFalse);
    });

    test('a record only in the cloud comes down to the phone (new phone)', () {
      final plan = planMerge(local: {}, cloud: {'a': rec('a', 10)}, now: 500);
      expect(plan.toLocal.keys, ['a']);
    });

    test('the newer copy wins, both ways; equal copies change nothing', () {
      final cloudNewer = planMerge(local: {'a': rec('a', 1, name: 'old')}, cloud: {'a': rec('a', 2, name: 'new')}, now: 9);
      expect(cloudNewer.toLocal['a']!['name'], 'new');
      final phoneNewer = planMerge(local: {'a': rec('a', 3, name: 'new')}, cloud: {'a': rec('a', 2, name: 'old')}, now: 9);
      expect(phoneNewer.toCloud['a']!['name'], 'new');
      final same = planMerge(local: {'a': rec('a', 2)}, cloud: {'a': rec('a', 2)}, now: 9);
      expect(same.toCloud, isEmpty);
      expect(same.changesLocal, isFalse);
    });

    test('a deletion on another phone removes the older copy here', () {
      final plan = planMerge(local: {'a': rec('a', 1)}, cloud: {'a': rec('a', 2, deleted: true)}, now: 9);
      expect(plan.deleteLocal, {'a'});
    });

    test('a change here made after the deletion elsewhere is kept and uploaded', () {
      final plan = planMerge(local: {'a': rec('a', 5)}, cloud: {'a': rec('a', 2, deleted: true)}, now: 9);
      expect(plan.deleteLocal, isEmpty);
      expect(plan.toCloud.keys, ['a']);
    });

    test('a deletion made here while the backup was off is not undone by an old cloud copy', () {
      final plan = planMerge(local: {}, cloud: {'a': rec('a', 2)}, localDeleted: {'a': 7}, now: 9);
      expect(plan.toLocal, isEmpty, reason: 'a deleted medicine must not come back and ring alarms');
      expect(plan.toCloud['a']![kDeletedFlag], isTrue);
    });

    test('...unless the cloud copy was changed after that deletion', () {
      final plan = planMerge(local: {}, cloud: {'a': rec('a', 8)}, localDeleted: {'a': 7}, now: 9);
      expect(plan.toLocal.keys, ['a']);
    });

    test('tombstones are never written onto the phone', () {
      final plan = planMerge(local: {}, cloud: {'a': rec('a', 2, deleted: true)}, now: 9);
      expect(plan.toLocal, isEmpty);
      expect(plan.deleteLocal, isEmpty);
    });
  });

  group('sync service with phone storage', () {
    late LocalStorageService storage;
    late FakeBackend cloud;
    late bool enabled;
    late CloudSyncService sync;
    var clock = 1000;

    setUpAll(() async {
      Hive.init(Directory.systemTemp.createTempSync('cloud_sync_test').path);
      await Hive.openBox<Map>('app_settings');
    });

    setUp(() async {
      storage = LocalStorageService();
      await storage.initUserStorage('u1');
      await Hive.box<Map>('medicines_u1').clear();
      await Hive.box<Map>('dose_logs_u1').clear();
      cloud = FakeBackend();
      enabled = true;
      sync = CloudSyncService(
        backend: cloud,
        storage: storage,
        isEnabled: () => enabled,
        pending: InMemoryPendingDeletes(),
        clock: () => clock += 10,
      );
      storage.changeListener = sync;
    });

    tearDown(() => storage.changeListener = null);

    test('saving and deleting a medicine is sent to the cloud', () async {
      await storage.saveMedicine(med('m1'), 'u1');
      await Future<void>.delayed(Duration.zero);
      expect(cloud.col('u1', 'medicines')['m1']!['name'], 'Napa');

      await storage.deleteMedicine('m1', 'u1');
      await Future<void>.delayed(Duration.zero);
      expect(cloud.col('u1', 'medicines')['m1']![kDeletedFlag], isTrue);
    });

    test('nothing is sent while the backup is off', () async {
      enabled = false;
      await storage.saveMedicine(med('m1'), 'u1');
      await Future<void>.delayed(Duration.zero);
      expect(cloud.data, isEmpty);
    });

    test('a new phone gets medicines and dose history back', () async {
      await storage.saveMedicine(med('m1'), 'u1');
      await storage.saveDoseLog(
          DoseLog(id: 'l1', medicineId: 'm1', medicineName: 'Napa', scheduledTime: '08:00 AM', status: 'taken', scheduledDate: '2026-11-18'),
          'u1');
      await Future<void>.delayed(Duration.zero);

      // "New phone": same account, empty storage.
      await Hive.box<Map>('medicines_u1').clear();
      await Hive.box<Map>('dose_logs_u1').clear();
      final changed = await sync.syncNow('u1');

      expect(changed, isTrue);
      expect(storage.getMedicines('u1').single.name, 'Napa');
      expect(storage.getDoseLogs('u1').single.scheduledDate, '2026-11-18');
      expect(sync.status.value.lastSync, isNotNull);
    });

    test('data saved before the backup was turned on is uploaded by the first sync', () async {
      enabled = false;
      await storage.saveMedicine(med('m1'), 'u1');
      enabled = true;
      await sync.syncNow('u1');
      expect(cloud.col('u1', 'medicines').keys, ['m1']);
    });

    test('a failed sync (offline) keeps the phone data and reports an error', () async {
      await storage.saveMedicine(med('m1'), 'u1');
      cloud.offline = true;
      final changed = await sync.syncNow('u1');
      expect(changed, isFalse);
      expect(storage.getMedicines('u1').length, 1);
      expect(sync.status.value.error, isNotNull);
    });
  });

  group('dose logs record the day they were due', () {
    test('a new log gets scheduledDate from when it was logged', () {
      final notifier = DoseLogsNotifier(LocalStorageService(), [], null);
      notifier.addLog(DoseLog(
        id: 'l1', medicineId: 'm1', medicineName: 'Napa', scheduledTime: '08:00 AM', status: 'taken',
        actualTime: DateTime(2026, 11, 18, 8, 5),
      ));
      expect(notifier.state.single.scheduledDate, '2026-11-18');
    });

    test('older logs without it get it filled in on load', () {
      final old = DoseLog(
        id: 'l1', medicineId: 'm1', medicineName: 'Napa', scheduledTime: '08:00 AM', status: 'taken',
        actualTime: DateTime(2026, 3, 2, 21, 0),
      );
      final notifier = DoseLogsNotifier(LocalStorageService(), [old], null);
      expect(notifier.state.single.scheduledDate, '2026-03-02');
    });

    test('scheduledDate survives saving and loading', () {
      final log = DoseLog(id: 'l', medicineId: 'm', medicineName: 'n', scheduledTime: '08:00 AM', status: 'missed', scheduledDate: '2026-11-18');
      expect(DoseLog.fromJson(log.toJson()).scheduledDate, '2026-11-18');
    });
  });
}
