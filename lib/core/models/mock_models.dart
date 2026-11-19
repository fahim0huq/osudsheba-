import 'package:flutter/material.dart';

// Saved by name ('tablet', 'drops', ...): add new forms at the end, never rename.
enum MedicineForm { tablet, capsule, syrup, injection, drops }

extension MedicineFormExtension on MedicineForm {
  String get displayName {
    switch (this) {
      case MedicineForm.tablet:
        return 'Tablet';
      case MedicineForm.capsule:
        return 'Capsule';
      case MedicineForm.syrup:
        return 'Syrup';
      case MedicineForm.injection:
        return 'Injection';
      case MedicineForm.drops:
        return 'Drops';
    }
  }

  String get bnName {
    switch (this) {
      case MedicineForm.tablet:
        return 'ট্যাবলেট';
      case MedicineForm.capsule:
        return 'ক্যাপসুল';
      case MedicineForm.syrup:
        return 'সিরাপ';
      case MedicineForm.injection:
        return 'ইনজেকশন';
      case MedicineForm.drops:
        return 'ড্রপ';
    }
  }

  IconData get icon {
    switch (this) {
      case MedicineForm.tablet:
        return Icons.circle;
      case MedicineForm.capsule:
        return Icons.medication;
      case MedicineForm.syrup:
        return Icons.wine_bar;
      case MedicineForm.injection:
        return Icons.vaccines;
      case MedicineForm.drops:
        return Icons.water_drop_rounded;
    }
  }

  /// The usual single dose, pre-filled in the Dose field when this type is picked.
  String get defaultDose {
    switch (this) {
      case MedicineForm.tablet:
        return '1 Tablet';
      case MedicineForm.capsule:
        return '1 Capsule';
      case MedicineForm.syrup:
        return '5ml';
      case MedicineForm.injection:
        return '1 ml';
      case MedicineForm.drops:
        return '1 Drop';
    }
  }
}

/// Defaults used by earlier versions; still treated as "not typed by the user".
const _legacyDefaultDoses = ['1 injection'];

/// The Dose text after the medicine type changes from [from] to [to]: switches to the new
/// type's default only if the dose was empty or still a default, so a dose the user
/// typed ("½ Tablet", "2 drops") is never overwritten.
String doseAfterFormChange(String currentDose, MedicineForm from, MedicineForm to) {
  final dose = currentDose.trim().toLowerCase();
  final untouched = dose.isEmpty ||
      _legacyDefaultDoses.contains(dose) ||
      MedicineForm.values.any((f) => f.defaultDose.toLowerCase() == dose);
  return untouched ? to.defaultDose : currentDose;
}

final _mlAmount = RegExp(r'^\s*(\d+(?:[.,]\d+)?|[.,]\d+)\s*(?:ml|mL|ML|মিলি)?\s*$');

/// Injections are entered as a number of ml (the field shows "ml" after it, like the marks
/// on a syringe). Saved dose "2 ml" -> field text "2"; other types are shown as saved.
String doseFieldText(String savedDose, MedicineForm form) {
  if (form != MedicineForm.injection) return savedDose;
  final m = _mlAmount.firstMatch(savedDose);
  return m == null ? savedDose : m.group(1)!.replaceAll(',', '.');
}

/// Field text -> saved dose: an injection amount "2" is saved as "2 ml".
String doseForSave(String fieldText, MedicineForm form) {
  final text = fieldText.trim();
  if (form != MedicineForm.injection) return text;
  final m = _mlAmount.firstMatch(text);
  return m == null ? text : '${m.group(1)!.replaceAll(',', '.')} ml';
}

/// What the Dose field should show after switching type (see [doseAfterFormChange]).
String doseFieldAfterFormChange(String fieldText, MedicineForm from, MedicineForm to) =>
    doseFieldText(doseAfterFormChange(doseForSave(fieldText, from), from, to), to);

class Medicine {
  final String id;
  final String name;
  final String strength; // e.g. "500mg"
  final MedicineForm form;
  final String dose; // e.g. "1 tablet"
  final List<String> times; // e.g. ["08:00 AM", "08:00 PM"]
  final String mealRelation; // "Before Meal" | "After Meal" | "With Meal" | "None"
  final String instruction; // e.g. "Take with warm water"
  final DateTime? startDate;
  final DateTime? endDate;
  final String status; // "active" | "completed" | "paused"
  final DateTime? createdAt;

  Medicine({
    required this.id,
    required this.name,
    required this.strength,
    required this.form,
    required this.dose,
    required this.times,
    required this.mealRelation,
    required this.instruction,
    this.startDate,
    this.endDate,
    this.status = 'active',
    this.createdAt,
  });

  Medicine copyWith({
    String? id,
    String? name,
    String? strength,
    MedicineForm? form,
    String? dose,
    List<String>? times,
    String? mealRelation,
    String? instruction,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    DateTime? createdAt,
    bool clearEndDate = false,
  }) {
    return Medicine(
      id: id ?? this.id,
      name: name ?? this.name,
      strength: strength ?? this.strength,
      form: form ?? this.form,
      dose: dose ?? this.dose,
      times: times ?? this.times,
      mealRelation: mealRelation ?? this.mealRelation,
      instruction: instruction ?? this.instruction,
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'strength': strength,
      'form': form.name,
      'dose': dose,
      'times': times,
      'mealRelation': mealRelation,
      'instruction': instruction,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'status': status,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      strength: json['strength'] as String? ?? '',
      form: MedicineForm.values.firstWhere(
        (e) => e.name == json['form'],
        orElse: () => MedicineForm.tablet,
      ),
      dose: json['dose'] as String? ?? '',
      times: List<String>.from(json['times'] ?? []),
      mealRelation: json['mealRelation'] as String? ?? 'None',
      instruction: json['instruction'] as String? ?? '',
      startDate: json['startDate'] != null ? DateTime.tryParse(json['startDate'] as String) : null,
      endDate: json['endDate'] != null ? DateTime.tryParse(json['endDate'] as String) : null,
      status: json['status'] as String? ?? 'active',
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
    );
  }
}

class DoseLog {
  final String id;
  final String medicineId;
  final String medicineName;
  final String scheduledTime;
  final DateTime? actualTime;
  final String status; // "taken" | "missed" | "skipped" | "snoozed" | "late"
  final String? note;

  /// The day the dose was due, "yyyy-MM-dd". Older logs lack it: it is then taken from
  /// [actualTime] (see [effectiveScheduledDate]). Needed to tell which day a dose
  /// belongs to once logs are synced and read elsewhere (family view, server checks).
  final String? scheduledDate;

  /// [scheduledDate], or the date part of [actualTime] for older logs.
  String? get effectiveScheduledDate => scheduledDate ?? (actualTime == null ? null : dateKey(actualTime!));

  // Backwards compatibility getter/setter:
  DateTime? get takenTime => actualTime;

  DoseLog({
    required this.id,
    required this.medicineId,
    required this.medicineName,
    required this.scheduledTime,
    this.actualTime,
    required this.status,
    this.note,
    this.scheduledDate,
  });

  DoseLog copyWith({String? id, String? scheduledTime, DateTime? actualTime, String? status, String? scheduledDate}) {
    return DoseLog(
      id: id ?? this.id,
      medicineId: medicineId,
      medicineName: medicineName,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      actualTime: actualTime ?? this.actualTime,
      status: status ?? this.status,
      note: note,
      scheduledDate: scheduledDate ?? this.scheduledDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'medicineId': medicineId,
      'medicineName': medicineName,
      'scheduledTime': scheduledTime,
      'actualTime': actualTime?.toIso8601String(),
      'status': status,
      'note': note,
      'scheduledDate': scheduledDate,
    };
  }

  factory DoseLog.fromJson(Map<String, dynamic> json) {
    return DoseLog(
      id: json['id'] as String? ?? '',
      medicineId: json['medicineId'] as String? ?? '',
      medicineName: json['medicineName'] as String? ?? '',
      scheduledTime: json['scheduledTime'] as String? ?? '',
      actualTime: json['actualTime'] != null ? DateTime.tryParse(json['actualTime'] as String) : null,
      status: json['status'] as String? ?? 'taken',
      note: json['note'] as String?,
      scheduledDate: json['scheduledDate'] as String?,
    );
  }
}

/// "yyyy-MM-dd" for a local date.
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class CaregiverAlert {
  final String id;
  // English text, kept for older app versions and the cloud copy. Screens build the
  // shown text from the fields below instead (see core/utils/alert_text.dart).
  final String title;
  final String message;
  final String severity; // "High" | "Medium" | "Low"
  final String time;

  /// What happened: 'missed_dose' or 'no_medicines'. Null on alerts saved before this field.
  final String? kind;
  final String? medicineName;
  final String? scheduledTime; // canonical "hh:mm AM"
  final DateTime? occurredAt;

  CaregiverAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.time,
    this.kind,
    this.medicineName,
    this.scheduledTime,
    this.occurredAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'severity': severity,
      'time': time,
      if (kind != null) 'kind': kind,
      if (medicineName != null) 'medicineName': medicineName,
      if (scheduledTime != null) 'scheduledTime': scheduledTime,
      if (occurredAt != null) 'occurredAt': occurredAt!.toIso8601String(),
    };
  }

  factory CaregiverAlert.fromJson(Map<String, dynamic> json) {
    return CaregiverAlert(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      severity: json['severity'] as String? ?? 'Low',
      time: json['time'] as String? ?? '',
      kind: json['kind'] as String?,
      medicineName: json['medicineName'] as String?,
      scheduledTime: json['scheduledTime'] as String?,
      occurredAt: DateTime.tryParse(json['occurredAt'] as String? ?? ''),
    );
  }
}

class AppSettings {
  final String languageCode; // "en" | "bn"
  final String userRole; // "Patient" | "Caregiver" | "None"
  final bool appNotificationsEnabled;
  final bool caregiverAlertsEnabled;
  final bool onboardingCompleted;
  /// In-app text size multiplier (1.0 normal, 1.1 default, 1.25 large, 1.4 extra large).
  /// Applied on top of the phone's own font-size setting.
  final double textScale;
  /// Back up medicines and dose history to the user's account (Firestore). Off until the
  /// user turns it on: it sends health data to the cloud.
  final bool cloudBackupEnabled;

  // Backwards compatibility getters:
  String get language => languageCode;
  bool get appNotifications => appNotificationsEnabled;
  bool get caregiverAlerts => caregiverAlertsEnabled;

  AppSettings({
    this.languageCode = 'en',
    this.userRole = 'None',
    this.appNotificationsEnabled = true,
    this.caregiverAlertsEnabled = true,
    this.onboardingCompleted = false,
    this.textScale = 1.1,
    this.cloudBackupEnabled = false,
  });

  AppSettings copyWith({
    String? languageCode,
    String? language, // old alias
    String? userRole,
    bool? appNotificationsEnabled,
    bool? appNotifications, // old alias
    bool? caregiverAlertsEnabled,
    bool? caregiverAlerts, // old alias
    bool? onboardingCompleted,
    double? textScale,
    bool? cloudBackupEnabled,
  }) {
    return AppSettings(
      languageCode: languageCode ?? language ?? this.languageCode,
      userRole: userRole ?? this.userRole,
      appNotificationsEnabled: appNotificationsEnabled ?? appNotifications ?? this.appNotificationsEnabled,
      caregiverAlertsEnabled: caregiverAlertsEnabled ?? caregiverAlerts ?? this.caregiverAlertsEnabled,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      textScale: textScale ?? this.textScale,
      cloudBackupEnabled: cloudBackupEnabled ?? this.cloudBackupEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'languageCode': languageCode,
      'userRole': userRole,
      'appNotificationsEnabled': appNotificationsEnabled,
      'caregiverAlertsEnabled': caregiverAlertsEnabled,
      'onboardingCompleted': onboardingCompleted,
      'textScale': textScale,
      'cloudBackupEnabled': cloudBackupEnabled,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      languageCode: json['languageCode'] as String? ?? json['language'] as String? ?? 'en',
      userRole: json['userRole'] as String? ?? 'None',
      appNotificationsEnabled: json['appNotificationsEnabled'] as bool? ?? json['appNotifications'] as bool? ?? true,
      caregiverAlertsEnabled: json['caregiverAlertsEnabled'] as bool? ?? json['caregiverAlerts'] as bool? ?? true,
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      textScale: ((json['textScale'] as num?)?.toDouble() ?? 1.1).clamp(1.0, 1.5).toDouble(),
      cloudBackupEnabled: json['cloudBackupEnabled'] as bool? ?? false,
    );
  }
}

class UserProfile {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String age;
  final String role; // "Patient" | "Caregiver" | "None"
  final String chronicConditions;
  final String allergies;
  final String emergencyContact;
  // Caregiver fields:
  final String relationship;
  final String patientPhone;
  final bool isLoggedIn;
  final bool profileCompleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserProfile({
    this.id = '',
    this.name = '',
    this.email = '',
    this.phone = '',
    this.age = '',
    this.role = 'None',
    this.chronicConditions = '',
    this.allergies = '',
    this.emergencyContact = '',
    this.relationship = '',
    this.patientPhone = '',
    this.isLoggedIn = false,
    this.profileCompleted = false,
    this.createdAt,
    this.updatedAt,
  });

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? age,
    String? role,
    String? chronicConditions,
    String? allergies,
    String? emergencyContact,
    String? relationship,
    String? patientPhone,
    bool? isLoggedIn,
    bool? profileCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      age: age ?? this.age,
      role: role ?? this.role,
      chronicConditions: chronicConditions ?? this.chronicConditions,
      allergies: allergies ?? this.allergies,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      relationship: relationship ?? this.relationship,
      patientPhone: patientPhone ?? this.patientPhone,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'age': age,
      'role': role,
      'chronicConditions': chronicConditions,
      'allergies': allergies,
      'emergencyContact': emergencyContact,
      'relationship': relationship,
      'patientPhone': patientPhone,
      'isLoggedIn': isLoggedIn,
      'profileCompleted': profileCompleted,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      age: json['age'] as String? ?? '',
      role: json['role'] as String? ?? 'None',
      chronicConditions: json['chronicConditions'] as String? ?? '',
      allergies: json['allergies'] as String? ?? '',
      emergencyContact: json['emergencyContact'] as String? ?? '',
      relationship: json['relationship'] as String? ?? '',
      patientPhone: json['patientPhone'] as String? ?? '',
      isLoggedIn: json['isLoggedIn'] as bool? ?? false,
      profileCompleted: json['profileCompleted'] as bool? ?? false,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) : null,
    );
  }
}
