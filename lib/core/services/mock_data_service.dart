import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/mock_models.dart';
import 'local_storage_service.dart';
import 'auth_service.dart';

// Local storage provider
final localStorageProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageService();
});

// Watch current authenticated user's UID and sync it to LocalStorageService
final userUidProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  final uid = authState.maybeWhen(
    data: (user) => user?.uid,
    orElse: () => null,
  );
  LocalStorageService().currentUid = uid;
  return uid;
});

// Asynchronously open user-specific Hive boxes
final userStorageInitProvider = FutureProvider.autoDispose.family<bool, String>((ref, uid) async {
  final storage = ref.read(localStorageProvider);
  await storage.initUserStorage(uid);
  return true;
});

// Selected medicine provider
final selectedMedicineProvider = StateProvider<Medicine?>((ref) => null);

// State management for App Settings
class AppSettingsNotifier extends StateNotifier<AppSettings> {
  final LocalStorageService _storage;

  AppSettingsNotifier(this._storage, AppSettings initial) : super(initial);

  void setLanguage(String lang) {
    state = state.copyWith(languageCode: lang);
    _storage.saveSettings(state);
  }

  void setRole(String role) {
    state = state.copyWith(userRole: role);
    _storage.saveSettings(state);
  }

  void setOnboardingCompleted(bool completed) {
    state = state.copyWith(onboardingCompleted: completed);
    _storage.saveSettings(state);
  }

  void updateToggles({
    bool? appNotifications,
    bool? smsReminders,
    bool? caregiverAlerts,
    bool? dailySummarySms,
  }) {
    state = state.copyWith(
      appNotificationsEnabled: appNotifications ?? state.appNotificationsEnabled,
      smsRemindersEnabled: smsReminders ?? state.smsRemindersEnabled,
      caregiverAlertsEnabled: caregiverAlerts ?? state.caregiverAlertsEnabled,
      dailySummaryEnabled: dailySummarySms ?? state.dailySummaryEnabled,
    );
    _storage.saveSettings(state);
  }

  void resetSettings() {
    state = AppSettings();
    _storage.saveSettings(state);
  }
}

final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  final storage = ref.read(localStorageProvider);
  final saved = storage.getSettings() ?? AppSettings();
  return AppSettingsNotifier(storage, saved);
});

// Patient profile details state
class PatientProfile {
  final String name;
  final String age;
  final String phone;
  final String chronicConditions;
  final String allergies;
  final String emergencyContact;

  PatientProfile({
    this.name = '',
    this.age = '',
    this.phone = '',
    this.chronicConditions = '',
    this.allergies = '',
    this.emergencyContact = '',
  });

  PatientProfile copyWith({
    String? name,
    String? age,
    String? phone,
    String? chronicConditions,
    String? allergies,
    String? emergencyContact,
  }) {
    return PatientProfile(
      name: name ?? this.name,
      age: age ?? this.age,
      phone: phone ?? this.phone,
      chronicConditions: chronicConditions ?? this.chronicConditions,
      allergies: allergies ?? this.allergies,
      emergencyContact: emergencyContact ?? this.emergencyContact,
    );
  }
}

class PatientProfileNotifier extends StateNotifier<PatientProfile> {
  final Ref ref;
  PatientProfileNotifier(this.ref, PatientProfile initial) : super(initial) {
    ref.listen<UserProfile>(userProfileProvider, (prev, next) {
      if (next.role == 'Patient') {
        state = PatientProfile(
          name: next.name,
          age: next.age,
          phone: next.phone,
          chronicConditions: next.chronicConditions,
          allergies: next.allergies,
          emergencyContact: next.emergencyContact,
        );
      }
    });
  }

  void updateProfile(PatientProfile profile) {
    state = profile;
    final current = ref.read(userProfileProvider);
    ref.read(userProfileProvider.notifier).updateProfile(current.copyWith(
      name: profile.name,
      age: profile.age,
      phone: profile.phone,
      chronicConditions: profile.chronicConditions,
      allergies: profile.allergies,
      emergencyContact: profile.emergencyContact,
      role: 'Patient',
      profileCompleted: true,
    ));
  }
  
  void reset() {
    state = PatientProfile();
  }
}

final patientProfileProvider = StateNotifierProvider<PatientProfileNotifier, PatientProfile>((ref) {
  final user = ref.watch(userProfileProvider);
  final initial = PatientProfile(
    name: user.name,
    age: user.age,
    phone: user.phone,
    chronicConditions: user.chronicConditions,
    allergies: user.allergies,
    emergencyContact: user.emergencyContact,
  );
  return PatientProfileNotifier(ref, initial);
});

// Caregiver profile details state
class CaregiverProfile {
  final String name;
  final String relationship;
  final String phone;
  final String patientPhone;

  CaregiverProfile({
    this.name = '',
    this.relationship = '',
    this.phone = '',
    this.patientPhone = '',
  });

  CaregiverProfile copyWith({
    String? name,
    String? relationship,
    String? phone,
    String? patientPhone,
  }) {
    return CaregiverProfile(
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      phone: phone ?? this.phone,
      patientPhone: patientPhone ?? this.patientPhone,
    );
  }
}

class CaregiverProfileNotifier extends StateNotifier<CaregiverProfile> {
  final Ref ref;
  CaregiverProfileNotifier(this.ref, CaregiverProfile initial) : super(initial) {
    ref.listen<UserProfile>(userProfileProvider, (prev, next) {
      if (next.role == 'Caregiver') {
        state = CaregiverProfile(
          name: next.name,
          relationship: next.relationship,
          phone: next.phone,
          patientPhone: next.patientPhone,
        );
      }
    });
  }

  void updateProfile(CaregiverProfile profile) {
    state = profile;
    final current = ref.read(userProfileProvider);
    ref.read(userProfileProvider.notifier).updateProfile(current.copyWith(
      name: profile.name,
      relationship: profile.relationship,
      phone: profile.phone,
      patientPhone: profile.patientPhone,
      role: 'Caregiver',
      profileCompleted: true,
    ));
  }

  void reset() {
    state = CaregiverProfile();
  }
}

final caregiverProfileProvider = StateNotifierProvider<CaregiverProfileNotifier, CaregiverProfile>((ref) {
  final user = ref.watch(userProfileProvider);
  final initial = CaregiverProfile(
    name: user.name,
    relationship: user.relationship,
    phone: user.phone,
    patientPhone: user.patientPhone,
  );
  return CaregiverProfileNotifier(ref, initial);
});

// Central user profile provider
class UserProfileNotifier extends StateNotifier<UserProfile> {
  final LocalStorageService _storage;
  final String? uid;

  UserProfileNotifier(this._storage, UserProfile initial, this.uid) : super(initial);

  void updateProfile(UserProfile profile) {
    state = profile;
    _storage.saveUserProfile(state, uid);
  }

  void saveProfile(UserProfile profile) {
    updateProfile(profile);
  }

  UserProfile getProfile() => state;

  void setLoggedIn(bool loggedIn) {
    state = state.copyWith(isLoggedIn: loggedIn);
    _storage.saveUserProfile(state, uid);
  }

  void setProfileCompleted(bool completed) {
    state = state.copyWith(profileCompleted: completed);
    _storage.saveUserProfile(state, uid);
  }

  void clearSessionOnly() {
    state = state.copyWith(isLoggedIn: false);
    _storage.saveUserProfile(state, uid);
  }

  void resetProfile() {
    state = UserProfile(id: uid ?? '1');
    _storage.saveUserProfile(state, uid);
  }
}

final userProfileProvider = StateNotifierProvider<UserProfileNotifier, UserProfile>((ref) {
  final uid = ref.watch(userUidProvider);
  if (uid == null) {
    return UserProfileNotifier(ref.read(localStorageProvider), UserProfile(id: '1'), null);
  }

  final initAsync = ref.watch(userStorageInitProvider(uid));
  return initAsync.maybeWhen(
    data: (initialized) {
      final storage = ref.read(localStorageProvider);
      final saved = storage.getUserProfile(uid) ?? UserProfile(id: uid);
      return UserProfileNotifier(storage, saved, uid);
    },
    orElse: () {
      return UserProfileNotifier(ref.read(localStorageProvider), UserProfile(id: uid), uid);
    },
  );
});

// Medicines state notifier
class MedicinesNotifier extends StateNotifier<List<Medicine>> {
  final LocalStorageService _storage;
  final String? uid;

  MedicinesNotifier(this._storage, List<Medicine> initial, this.uid) : super(initial);

  void addMedicine(Medicine med) {
    state = [...state, med];
    _storage.saveMedicine(med, uid);
  }

  void updateMedicine(Medicine updatedMed) {
    state = [
      for (final med in state)
        if (med.id == updatedMed.id) updatedMed else med
    ];
    _storage.saveMedicine(updatedMed, uid);
  }

  void updateStatus(String id, String status) {
    final List<Medicine> updatedList = [];
    for (final med in state) {
      if (med.id == id) {
        final newStatus = (status == 'active' || status == 'completed' || status == 'paused') ? status : med.status;
        final updated = med.copyWith(status: newStatus);
        _storage.saveMedicine(updated, uid);
        updatedList.add(updated);
      } else {
        updatedList.add(med);
      }
    }
    state = updatedList;
  }

  void deleteMedicine(String id) {
    state = state.where((med) => med.id != id).toList();
    _storage.deleteMedicine(id, uid);
  }

  void reset() {
    state = [];
  }
}

// Medicine List Provider
final medicineListProvider = StateNotifierProvider<MedicinesNotifier, List<Medicine>>((ref) {
  final uid = ref.watch(userUidProvider);
  if (uid == null) {
    return MedicinesNotifier(ref.read(localStorageProvider), [], null);
  }

  final initAsync = ref.watch(userStorageInitProvider(uid));
  return initAsync.maybeWhen(
    data: (initialized) {
      final storage = ref.read(localStorageProvider);
      final saved = storage.getMedicines(uid);
      return MedicinesNotifier(storage, saved, uid);
    },
    orElse: () => MedicinesNotifier(ref.read(localStorageProvider), [], uid),
  );
});

// Alias for backwards compatibility
final medicinesProvider = medicineListProvider;

// Dose Logs notifier
class DoseLogsNotifier extends StateNotifier<List<DoseLog>> {
  final LocalStorageService _storage;
  final String? uid;

  DoseLogsNotifier(this._storage, List<DoseLog> initial, this.uid) : super(initial);

  bool _isSameDay(DateTime a, DateTime b) {
    return a.day == b.day && a.month == b.month && a.year == b.year;
  }

  void addLog(DoseLog log) {
    final logDate = log.actualTime ?? DateTime.now();
    final existingIndex = state.indexWhere((l) =>
        l.medicineId == log.medicineId &&
        l.scheduledTime == log.scheduledTime &&
        l.actualTime != null &&
        _isSameDay(l.actualTime!, logDate));

    if (existingIndex != -1) {
      final existingLog = state[existingIndex];
      final updatedLog = DoseLog(
        id: existingLog.id,
        medicineId: log.medicineId,
        medicineName: log.medicineName,
        scheduledTime: log.scheduledTime,
        actualTime: log.actualTime,
        status: log.status,
        note: log.note,
      );
      final updatedList = List<DoseLog>.from(state);
      updatedList[existingIndex] = updatedLog;
      state = updatedList;
      _storage.saveDoseLog(updatedLog, uid);
    } else {
      state = [log, ...state];
      _storage.saveDoseLog(log, uid);
    }
  }

  void reset() {
    state = [];
  }
}

// Dose Log Provider
final doseLogProvider = StateNotifierProvider<DoseLogsNotifier, List<DoseLog>>((ref) {
  final uid = ref.watch(userUidProvider);
  if (uid == null) {
    return DoseLogsNotifier(ref.read(localStorageProvider), [], null);
  }

  final initAsync = ref.watch(userStorageInitProvider(uid));
  return initAsync.maybeWhen(
    data: (initialized) {
      final storage = ref.read(localStorageProvider);
      final saved = storage.getDoseLogs(uid);
      return DoseLogsNotifier(storage, saved, uid);
    },
    orElse: () => DoseLogsNotifier(ref.read(localStorageProvider), [], uid),
  );
});

// Alias for backwards compatibility
final doseLogsProvider = doseLogProvider;

// Caregiver Alerts notifier
class CaregiverAlertsNotifier extends StateNotifier<List<CaregiverAlert>> {
  final LocalStorageService _storage;
  final String? uid;

  CaregiverAlertsNotifier(this._storage, List<CaregiverAlert> initial, this.uid) : super(initial);

  List<CaregiverAlert> get activeAlerts => state;

  void addAlert(CaregiverAlert alert) {
    state = [alert, ...state];
    _storage.saveCaregiverAlert(alert, uid);
  }

  void removeAlert(String id) {
    state = state.where((alert) => alert.id != id).toList();
    _storage.deleteCaregiverAlert(id, uid);
  }

  void reset() {
    state = [];
  }
}

final caregiverAlertsProvider = StateNotifierProvider<CaregiverAlertsNotifier, List<CaregiverAlert>>((ref) {
  final uid = ref.watch(userUidProvider);
  if (uid == null) {
    return CaregiverAlertsNotifier(ref.read(localStorageProvider), [], null);
  }

  final initAsync = ref.watch(userStorageInitProvider(uid));
  return initAsync.maybeWhen(
    data: (initialized) {
      final storage = ref.read(localStorageProvider);
      final saved = storage.getCaregiverAlerts(uid);
      final notifier = CaregiverAlertsNotifier(storage, saved, uid);

      // Sync missed doses to caregiver alerts
      ref.listen<List<DoseLog>>(doseLogProvider, (previous, next) {
        final prevIds = previous?.map((e) => e.id).toSet() ?? {};
        final newMissed = next.where((log) => log.status == 'missed' && !prevIds.contains(log.id));
        for (final log in newMissed) {
          final alertId = 'missed_${log.id}';
          if (!notifier.activeAlerts.any((a) => a.id == alertId)) {
            notifier.addAlert(CaregiverAlert(
              id: alertId,
              title: 'Missed Dose: ${log.medicineName}',
              message: 'The patient did not mark ${log.medicineName} scheduled at ${log.scheduledTime} as taken.',
              severity: 'High',
              time: 'Today, ${log.scheduledTime}',
            ));
          }
        }
      });

      // Sync empty medicine list to caregiver alerts
      ref.listen<List<Medicine>>(medicineListProvider, (previous, next) {
        final hasNoMedAlert = notifier.activeAlerts.any((a) => a.id == 'no_medicines_alert');
        if (next.isEmpty && !hasNoMedAlert) {
          notifier.addAlert(CaregiverAlert(
            id: 'no_medicines_alert',
            title: 'No Medicines Active',
            message: 'The patient has no active medicines listed in their schedule.',
            severity: 'Medium',
            time: 'Just now',
          ));
        } else if (next.isNotEmpty && hasNoMedAlert) {
          notifier.removeAlert('no_medicines_alert');
        }
      });

      return notifier;
    },
    orElse: () => CaregiverAlertsNotifier(ref.read(localStorageProvider), [], uid),
  );
});

class AdherenceStats {
  final int totalLogs;
  final int takenCount;
  final int missedCount;
  final int skippedCount;
  final int lateCount;
  final int snoozedCount;
  final int percentage;

  AdherenceStats({
    required this.totalLogs,
    required this.takenCount,
    required this.missedCount,
    required this.skippedCount,
    required this.lateCount,
    required this.snoozedCount,
    required this.percentage,
  });
}

final adherenceStatsProvider = Provider<AdherenceStats>((ref) {
  final logs = ref.watch(doseLogsProvider);
  final totalLogs = logs.length;
  final takenCount = logs.where((l) => l.status.toLowerCase() == 'taken').length;
  final missedCount = logs.where((l) => l.status.toLowerCase() == 'missed').length;
  final skippedCount = logs.where((l) => l.status.toLowerCase() == 'skipped').length;
  final lateCount = logs.where((l) => l.status.toLowerCase() == 'late').length;
  final snoozedCount = logs.where((l) => l.status.toLowerCase() == 'snoozed').length;

  final double adherenceRate = totalLogs > 0 ? (takenCount / totalLogs) : 1.0;
  final int adherencePercent = (adherenceRate * 100).toInt();

  return AdherenceStats(
    totalLogs: totalLogs,
    takenCount: takenCount,
    missedCount: missedCount,
    skippedCount: skippedCount,
    lateCount: lateCount,
    snoozedCount: snoozedCount,
    percentage: adherencePercent,
  );
});
