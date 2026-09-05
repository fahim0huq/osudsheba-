import 'package:hive_flutter/hive_flutter.dart';
import '../models/mock_models.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  String? currentUid;

  String _boxName(String baseName, String? uid) {
    final activeUid = uid ?? currentUid;
    return activeUid != null ? '${baseName}_$activeUid' : baseName;
  }

  Future<void> init() async {
    await Hive.initFlutter();
    // Keep global app settings
    await Hive.openBox<Map>('app_settings');
    
    // Open legacy global boxes to safely preserve legacy data
    await Hive.openBox<Map>('medicines');
    await Hive.openBox<Map>('dose_logs');
    await Hive.openBox<Map>('caregiver_alerts');
    await Hive.openBox<Map>('user_profile');
  }

  Future<void> initUserStorage(String uid) async {
    if (!Hive.isBoxOpen('medicines_$uid')) {
      await Hive.openBox<Map>('medicines_$uid');
    }
    if (!Hive.isBoxOpen('dose_logs_$uid')) {
      await Hive.openBox<Map>('dose_logs_$uid');
    }
    if (!Hive.isBoxOpen('caregiver_alerts_$uid')) {
      await Hive.openBox<Map>('caregiver_alerts_$uid');
    }
    if (!Hive.isBoxOpen('user_profile_$uid')) {
      await Hive.openBox<Map>('user_profile_$uid');
    }
  }

  // Medicines
  List<Medicine> getMedicines([String? uid]) {
    final boxName = _boxName('medicines', uid);
    if (!Hive.isBoxOpen(boxName)) return [];
    final box = Hive.box<Map>(boxName);
    return box.values
        .map((e) => Medicine.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveMedicine(Medicine medicine, [String? uid]) async {
    final boxName = _boxName('medicines', uid);
    if (!Hive.isBoxOpen(boxName)) return;
    final box = Hive.box<Map>(boxName);
    await box.put(medicine.id, medicine.toJson());
  }

  Future<void> updateMedicine(Medicine medicine, [String? uid]) async {
    await saveMedicine(medicine, uid);
  }

  Future<void> deleteMedicine(String id, [String? uid]) async {
    final boxName = _boxName('medicines', uid);
    if (!Hive.isBoxOpen(boxName)) return;
    final box = Hive.box<Map>(boxName);
    await box.delete(id);
  }

  // Dose Logs
  List<DoseLog> getDoseLogs([String? uid]) {
    final boxName = _boxName('dose_logs', uid);
    if (!Hive.isBoxOpen(boxName)) return [];
    final box = Hive.box<Map>(boxName);
    return box.values
        .map((e) => DoseLog.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveDoseLog(DoseLog log, [String? uid]) async {
    final boxName = _boxName('dose_logs', uid);
    if (!Hive.isBoxOpen(boxName)) return;
    final box = Hive.box<Map>(boxName);
    await box.put(log.id, log.toJson());
  }

  // Caregiver Alerts
  List<CaregiverAlert> getCaregiverAlerts([String? uid]) {
    final boxName = _boxName('caregiver_alerts', uid);
    if (!Hive.isBoxOpen(boxName)) return [];
    final box = Hive.box<Map>(boxName);
    return box.values
        .map((e) => CaregiverAlert.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveCaregiverAlert(CaregiverAlert alert, [String? uid]) async {
    final boxName = _boxName('caregiver_alerts', uid);
    if (!Hive.isBoxOpen(boxName)) return;
    final box = Hive.box<Map>(boxName);
    await box.put(alert.id, alert.toJson());
  }

  Future<void> deleteCaregiverAlert(String id, [String? uid]) async {
    final boxName = _boxName('caregiver_alerts', uid);
    if (!Hive.isBoxOpen(boxName)) return;
    final box = Hive.box<Map>(boxName);
    await box.delete(id);
  }

  // App Settings (Kept Global/Separate from User Data)
  AppSettings? getSettings() {
    if (!Hive.isBoxOpen('app_settings')) return null;
    final box = Hive.box<Map>('app_settings');
    final data = box.get('settings');
    if (data == null) return null;
    return AppSettings.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> saveSettings(AppSettings settings) async {
    if (!Hive.isBoxOpen('app_settings')) return;
    final box = Hive.box<Map>('app_settings');
    await box.put('settings', settings.toJson());
  }

  // User Profile
  UserProfile? getUserProfile([String? uid]) {
    final boxName = _boxName('user_profile', uid);
    if (!Hive.isBoxOpen(boxName)) return null;
    final box = Hive.box<Map>(boxName);
    final data = box.get('profile');
    if (data == null) return null;
    return UserProfile.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> saveUserProfile(UserProfile profile, [String? uid]) async {
    final boxName = _boxName('user_profile', uid);
    if (!Hive.isBoxOpen(boxName)) return;
    final box = Hive.box<Map>(boxName);
    await box.put('profile', profile.toJson());
  }

  Future<void> closeUserStorage(String uid) async {
    if (Hive.isBoxOpen('medicines_$uid')) {
      await Hive.box<Map>('medicines_$uid').close();
    }
    if (Hive.isBoxOpen('dose_logs_$uid')) {
      await Hive.box<Map>('dose_logs_$uid').close();
    }
    if (Hive.isBoxOpen('caregiver_alerts_$uid')) {
      await Hive.box<Map>('caregiver_alerts_$uid').close();
    }
    if (Hive.isBoxOpen('user_profile_$uid')) {
      await Hive.box<Map>('user_profile_$uid').close();
    }
  }

  Future<void> clearAllData([String? uid]) async {
    // Only clear global box if explicitly resetting everything
    if (Hive.isBoxOpen('app_settings')) {
      await Hive.box<Map>('app_settings').clear();
    }
    
    final activeUid = uid ?? currentUid;
    if (activeUid != null) {
      if (Hive.isBoxOpen('medicines_$activeUid')) await Hive.box<Map>('medicines_$activeUid').clear();
      if (Hive.isBoxOpen('dose_logs_$activeUid')) await Hive.box<Map>('dose_logs_$activeUid').clear();
      if (Hive.isBoxOpen('caregiver_alerts_$activeUid')) await Hive.box<Map>('caregiver_alerts_$activeUid').clear();
      if (Hive.isBoxOpen('user_profile_$activeUid')) await Hive.box<Map>('user_profile_$activeUid').clear();
    }
  }
}
