// Meal-time slots: morning / noon / night x before / after meal, one reminder per slot.
import 'package:flutter_test/flutter_test.dart';
import 'package:osudsheba/core/models/mock_models.dart';
import 'package:osudsheba/core/services/local_storage_service.dart';
import 'package:osudsheba/core/services/mock_data_service.dart';
import 'package:osudsheba/core/utils/dose_slots.dart';

Medicine med(String id, {List<String> slots = const [], List<String> times = const ['10:00 AM']}) => Medicine(
      id: id,
      name: id,
      strength: '',
      form: MedicineForm.tablet,
      dose: '1 Tablet',
      times: times,
      mealRelation: 'None',
      instruction: '',
      slots: slots,
    );

void main() {
  test('"1+0+1, after meal" gives the default morning and night after-meal times', () {
    expect(timesForSlots([DoseSlot.morningAfter, DoseSlot.nightAfter], const {}), ['08:30 AM', '09:30 PM']);
  });

  test("the person's own slot times are used, sorted, and shared times give one reminder", () {
    final times = timesForSlots(
      [DoseSlot.nightAfter, DoseSlot.morningBefore, DoseSlot.morningAfter],
      const {'morning_before': '07:00 AM', 'morning_after': '7:00 am', 'night_after': '22:00'},
    );
    expect(times, ['07:00 AM', '10:00 PM']);
  });

  test('meal note: all before, all after, or mixed', () {
    expect(mealRelationForSlots([DoseSlot.morningBefore, DoseSlot.nightBefore]), 'Before Meal');
    expect(mealRelationForSlots([DoseSlot.noonAfter]), 'After Meal');
    expect(mealRelationForSlots([DoseSlot.morningBefore, DoseSlot.nightAfter]), 'None');
  });

  test('a reminder time is recognised as its slot (for "Morning · after meal" labels)', () {
    expect(slotAtTime('08:30 AM', const {}), DoseSlot.morningAfter);
    expect(slotAtTime('8:30 am', const {}), DoseSlot.morningAfter);
    expect(slotAtTime('11:15 AM', const {}), isNull);
    expect(DoseSlot.nightBefore.label(false), 'Night · before meal');
    expect(DoseSlot.nightBefore.label(true), 'রাত · খাবারের আগে');
  });

  test('slots and slot times survive saving and loading; unknown keys are ignored', () {
    final m = med('a', slots: ['morning_after', 'night_after']);
    expect(Medicine.fromJson(m.toJson()).slots, ['morning_after', 'night_after']);
    expect(med('b').toJson().containsKey('slots'), isFalse, reason: 'custom medicines store no slots');
    expect(slotsFromKeys(['night_after', 'bogus', 'morning_before']), [DoseSlot.morningBefore, DoseSlot.nightAfter]);

    final s = AppSettings(slotTimes: const {'noon_after': '02:30 PM'});
    expect(AppSettings.fromJson(s.toJson()).slotTimes, {'noon_after': '02:30 PM'});
    expect(AppSettings.fromJson(const {}).slotTimes, isEmpty);
  });

  test('moving a slot time moves only the medicines in that slot', () {
    final notifier = MedicinesNotifier(LocalStorageService(), [
      med('slotMed', slots: ['morning_after'], times: ['08:30 AM']),
      med('customMed', times: ['08:30 AM']),
    ], null);
    final moved = notifier.applySlotTimes(const {'morning_after': '09:15 AM'});
    expect(moved, 1);
    expect(notifier.state.firstWhere((m) => m.id == 'slotMed').times, ['09:15 AM']);
    expect(notifier.state.firstWhere((m) => m.id == 'customMed').times, ['08:30 AM']);
    expect(notifier.applySlotTimes(const {'morning_after': '09:15 AM'}), 0, reason: 'nothing to move twice');
  });
}
