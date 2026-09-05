import 'package:flutter_test/flutter_test.dart';
import 'package:osudsheba/core/models/mock_models.dart';

void main() {
  group('Medication Progress Calculation Tests', () {
    bool isToday(DateTime? dt) {
      if (dt == null) return false;
      final now = DateTime.now();
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    }

    Map<String, dynamic> calculateDailyProgress({
      required List<Medicine> medicines,
      required List<DoseLog> logs,
    }) {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final activeMeds = medicines.where((m) {
        if (m.status != 'active') return false;
        if (m.startDate != null && m.startDate!.isAfter(todayEnd)) return false;
        if (m.endDate != null && m.endDate!.isBefore(todayStart)) return false;
        return true;
      }).toList();

      int todayTotalScheduledDoses = 0;
      int todayTakenCount = 0;

      for (final med in activeMeds) {
        for (final time in med.times) {
          todayTotalScheduledDoses++;
          final isTaken = logs.any((l) =>
              l.medicineId == med.id &&
              l.scheduledTime == time &&
              l.actualTime != null &&
              isToday(l.actualTime) &&
              (l.status == 'taken' || l.status == 'late'));
          if (isTaken) {
            todayTakenCount++;
          }
        }
      }

      final double rate = todayTotalScheduledDoses > 0
          ? (todayTakenCount / todayTotalScheduledDoses)
          : 0.0;
      final int percentage = (rate * 100).toInt();

      return {
        'total': todayTotalScheduledDoses,
        'taken': todayTakenCount,
        'percentage': percentage,
      };
    }

    test('1 medicine / 1 scheduled dose / 1 taken -> 100%', () {
      final List<Medicine> meds = [
        Medicine(
          id: 'med-1',
          name: 'Napa',
          strength: '500mg',
          form: MedicineForm.tablet,
          dose: '1 tablet',
          times: ['08:00 AM'],
          mealRelation: 'After Meal',
          instruction: 'Take with water',
          status: 'active',
          startDate: DateTime.now().subtract(const Duration(days: 1)),
          endDate: DateTime.now().add(const Duration(days: 5)),
          createdAt: DateTime.now(),
        ),
      ];

      final List<DoseLog> logs = [
        DoseLog(
          id: 'log-1',
          medicineId: 'med-1',
          medicineName: 'Napa 500mg',
          scheduledTime: '08:00 AM',
          status: 'taken',
          actualTime: DateTime.now(),
        ),
      ];

      final result = calculateDailyProgress(medicines: meds, logs: logs);
      expect(result['total'], 1);
      expect(result['taken'], 1);
      expect(result['percentage'], 100);
    });

    test('2 scheduled doses / 1 taken -> 50%', () {
      final List<Medicine> meds = [
        Medicine(
          id: 'med-1',
          name: 'Napa',
          strength: '500mg',
          form: MedicineForm.tablet,
          dose: '1 tablet',
          times: ['08:00 AM', '08:00 PM'],
          mealRelation: 'After Meal',
          instruction: 'Take with water',
          status: 'active',
          startDate: DateTime.now().subtract(const Duration(days: 1)),
          endDate: DateTime.now().add(const Duration(days: 5)),
          createdAt: DateTime.now(),
        ),
      ];

      final List<DoseLog> logs = [
        DoseLog(
          id: 'log-1',
          medicineId: 'med-1',
          medicineName: 'Napa 500mg',
          scheduledTime: '08:00 AM',
          status: 'taken',
          actualTime: DateTime.now(),
        ),
      ];

      final result = calculateDailyProgress(medicines: meds, logs: logs);
      expect(result['total'], 2);
      expect(result['taken'], 1);
      expect(result['percentage'], 50);
    });

    test('5 scheduled doses / 1 taken -> 20% (NOT 33%)', () {
      final List<Medicine> meds = [
        Medicine(
          id: 'med-A',
          name: 'Medicine A',
          strength: '10mg',
          form: MedicineForm.tablet,
          dose: '1 tablet',
          times: ['08:00 AM', '08:00 PM'],
          mealRelation: 'After Meal',
          instruction: 'Take with water',
          status: 'active',
          startDate: DateTime.now().subtract(const Duration(days: 1)),
          endDate: DateTime.now().add(const Duration(days: 5)),
          createdAt: DateTime.now(),
        ),
        Medicine(
          id: 'med-B',
          name: 'Medicine B',
          strength: '20mg',
          form: MedicineForm.capsule,
          dose: '1 capsule',
          times: ['02:00 PM'],
          mealRelation: 'Before Meal',
          instruction: 'Take before lunch',
          status: 'active',
          startDate: DateTime.now().subtract(const Duration(days: 1)),
          endDate: DateTime.now().add(const Duration(days: 5)),
          createdAt: DateTime.now(),
        ),
        Medicine(
          id: 'med-C',
          name: 'Medicine C',
          strength: '5mg',
          form: MedicineForm.tablet,
          dose: '1 tablet',
          times: ['09:00 AM', '09:00 PM'],
          mealRelation: 'With Meal',
          instruction: 'Take with meal',
          status: 'active',
          startDate: DateTime.now().subtract(const Duration(days: 1)),
          endDate: DateTime.now().add(const Duration(days: 5)),
          createdAt: DateTime.now(),
        ),
      ];

      final List<DoseLog> logs = [
        DoseLog(
          id: 'log-1',
          medicineId: 'med-A',
          medicineName: 'Medicine A 10mg',
          scheduledTime: '08:00 AM',
          status: 'taken',
          actualTime: DateTime.now(),
        ),
      ];

      final result = calculateDailyProgress(medicines: meds, logs: logs);
      expect(result['total'], 5);
      expect(result['taken'], 1);
      expect(result['percentage'], 20);
    });

    test('5 scheduled doses / 3 taken -> 60%', () {
      final List<Medicine> meds = [
        Medicine(
          id: 'med-A',
          name: 'Medicine A',
          strength: '10mg',
          form: MedicineForm.tablet,
          dose: '1 tablet',
          times: ['08:00 AM', '08:00 PM'],
          mealRelation: 'After Meal',
          instruction: 'Take with water',
          status: 'active',
          startDate: DateTime.now().subtract(const Duration(days: 1)),
          endDate: DateTime.now().add(const Duration(days: 5)),
          createdAt: DateTime.now(),
        ),
        Medicine(
          id: 'med-B',
          name: 'Medicine B',
          strength: '20mg',
          form: MedicineForm.capsule,
          dose: '1 capsule',
          times: ['02:00 PM'],
          mealRelation: 'Before Meal',
          instruction: 'Take before lunch',
          status: 'active',
          startDate: DateTime.now().subtract(const Duration(days: 1)),
          endDate: DateTime.now().add(const Duration(days: 5)),
          createdAt: DateTime.now(),
        ),
        Medicine(
          id: 'med-C',
          name: 'Medicine C',
          strength: '5mg',
          form: MedicineForm.tablet,
          dose: '1 tablet',
          times: ['09:00 AM', '09:00 PM'],
          mealRelation: 'With Meal',
          instruction: 'Take with meal',
          status: 'active',
          startDate: DateTime.now().subtract(const Duration(days: 1)),
          endDate: DateTime.now().add(const Duration(days: 5)),
          createdAt: DateTime.now(),
        ),
      ];

      final List<DoseLog> logs = [
        DoseLog(
          id: 'log-1',
          medicineId: 'med-A',
          medicineName: 'Medicine A 10mg',
          scheduledTime: '08:00 AM',
          status: 'taken',
          actualTime: DateTime.now(),
        ),
        DoseLog(
          id: 'log-2',
          medicineId: 'med-B',
          medicineName: 'Medicine B 20mg',
          scheduledTime: '02:00 PM',
          status: 'taken',
          actualTime: DateTime.now(),
        ),
        DoseLog(
          id: 'log-3',
          medicineId: 'med-C',
          medicineName: 'Medicine C 5mg',
          scheduledTime: '09:00 AM',
          status: 'taken',
          actualTime: DateTime.now(),
        ),
      ];

      final result = calculateDailyProgress(medicines: meds, logs: logs);
      expect(result['total'], 5);
      expect(result['taken'], 3);
      expect(result['percentage'], 60);
    });

    test('Daily reset: logs from yesterday do not count as taken today -> 0%', () {
      final List<Medicine> meds = [
        Medicine(
          id: 'med-1',
          name: 'Napa',
          strength: '500mg',
          form: MedicineForm.tablet,
          dose: '1 tablet',
          times: ['08:00 AM', '08:00 PM'],
          mealRelation: 'After Meal',
          instruction: 'Take with water',
          status: 'active',
          startDate: DateTime.now().subtract(const Duration(days: 2)),
          endDate: DateTime.now().add(const Duration(days: 5)),
          createdAt: DateTime.now(),
        ),
      ];

      // Logs from yesterday
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final List<DoseLog> logs = [
        DoseLog(
          id: 'log-yesterday-1',
          medicineId: 'med-1',
          medicineName: 'Napa 500mg',
          scheduledTime: '08:00 AM',
          status: 'taken',
          actualTime: yesterday,
        ),
        DoseLog(
          id: 'log-yesterday-2',
          medicineId: 'med-1',
          medicineName: 'Napa 500mg',
          scheduledTime: '08:00 PM',
          status: 'taken',
          actualTime: yesterday,
        ),
      ];

      final result = calculateDailyProgress(medicines: meds, logs: logs);
      expect(result['total'], 2);
      expect(result['taken'], 0);
      expect(result['percentage'], 0);
    });
  });
}
