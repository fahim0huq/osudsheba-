import 'package:flutter/material.dart';

enum MedicineForm { tablet, capsule, syrup, injection }

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
    }
  }
}

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
      endDate: endDate ?? this.endDate,
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
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'medicineId': medicineId,
      'medicineName': medicineName,
      'scheduledTime': scheduledTime,
      'actualTime': actualTime?.toIso8601String(),
      'status': status,
      'note': note,
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
    );
  }
}

class CaregiverAlert {
  final String id;
  final String title;
  final String message;
  final String severity; // "High" | "Medium" | "Low"
  final String time;

  CaregiverAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.time,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'severity': severity,
      'time': time,
    };
  }

  factory CaregiverAlert.fromJson(Map<String, dynamic> json) {
    return CaregiverAlert(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      severity: json['severity'] as String? ?? 'Low',
      time: json['time'] as String? ?? '',
    );
  }
}

class AppSettings {
  final String languageCode; // "en" | "bn"
  final String userRole; // "Patient" | "Caregiver" | "None"
  final bool appNotificationsEnabled;
  final bool smsRemindersEnabled;
  final bool caregiverAlertsEnabled;
  final bool dailySummaryEnabled;
  final bool onboardingCompleted;

  // Backwards compatibility getters:
  String get language => languageCode;
  bool get appNotifications => appNotificationsEnabled;
  bool get smsReminders => smsRemindersEnabled;
  bool get caregiverAlerts => caregiverAlertsEnabled;
  bool get dailySummarySms => dailySummaryEnabled;

  AppSettings({
    this.languageCode = 'en',
    this.userRole = 'None',
    this.appNotificationsEnabled = true,
    this.smsRemindersEnabled = false,
    this.caregiverAlertsEnabled = true,
    this.dailySummaryEnabled = false,
    this.onboardingCompleted = false,
  });

  AppSettings copyWith({
    String? languageCode,
    String? language, // old alias
    String? userRole,
    bool? appNotificationsEnabled,
    bool? appNotifications, // old alias
    bool? smsRemindersEnabled,
    bool? smsReminders, // old alias
    bool? caregiverAlertsEnabled,
    bool? caregiverAlerts, // old alias
    bool? dailySummaryEnabled,
    bool? dailySummarySms, // old alias
    bool? onboardingCompleted,
  }) {
    return AppSettings(
      languageCode: languageCode ?? language ?? this.languageCode,
      userRole: userRole ?? this.userRole,
      appNotificationsEnabled: appNotificationsEnabled ?? appNotifications ?? this.appNotificationsEnabled,
      smsRemindersEnabled: smsRemindersEnabled ?? smsReminders ?? this.smsRemindersEnabled,
      caregiverAlertsEnabled: caregiverAlertsEnabled ?? caregiverAlerts ?? this.caregiverAlertsEnabled,
      dailySummaryEnabled: dailySummaryEnabled ?? dailySummarySms ?? this.dailySummaryEnabled,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'languageCode': languageCode,
      'userRole': userRole,
      'appNotificationsEnabled': appNotificationsEnabled,
      'smsRemindersEnabled': smsRemindersEnabled,
      'caregiverAlertsEnabled': caregiverAlertsEnabled,
      'dailySummaryEnabled': dailySummaryEnabled,
      'onboardingCompleted': onboardingCompleted,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      languageCode: json['languageCode'] as String? ?? json['language'] as String? ?? 'en',
      userRole: json['userRole'] as String? ?? 'None',
      appNotificationsEnabled: json['appNotificationsEnabled'] as bool? ?? json['appNotifications'] as bool? ?? true,
      smsRemindersEnabled: json['smsRemindersEnabled'] as bool? ?? json['smsReminders'] as bool? ?? false,
      caregiverAlertsEnabled: json['caregiverAlertsEnabled'] as bool? ?? json['caregiverAlerts'] as bool? ?? true,
      dailySummaryEnabled: json['dailySummaryEnabled'] as bool? ?? json['dailySummarySms'] as bool? ?? false,
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
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
