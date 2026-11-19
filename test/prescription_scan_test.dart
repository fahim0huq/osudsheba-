import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:osudsheba/core/models/mock_models.dart';
import 'package:osudsheba/core/services/scan/dose_parser.dart';
import 'package:osudsheba/core/services/scan/medicine_catalog.dart';
import 'package:osudsheba/core/services/scan/ocr_layout.dart';
import 'package:osudsheba/core/services/scan/prescription_text_parser.dart';

void main() {
  late MedicineCatalog catalog;
  final now = DateTime(2026, 11, 18, 10);

  setUpAll(() {
    catalog = MedicineCatalog.parse(File('assets/data/bd_medicines.tsv').readAsStringSync());
  });

  ScanDraft only(String text, String name) =>
      parsePrescription(text, catalog, now: now).singleWhere((d) => d.medicine.name == name);

  group('printed prescription', () {
    const text = '''
Dr. Abdul Karim
MBBS, FCPS (Medicine)
Name: Rahima Begum   Age: 65   Date: 12-05-2026
Rx
1. Tab. Napa 500 mg   1+0+1   7 days   after meal
2. Cap. Seclo 20 mg   1+0+1   before meal   1 month
3. Tab. Amdocal 5 mg   0+0+1   continue
4. Syp. Fexo 30 mg/5 ml   2 tsf twice daily   5 days
Advice: drink plenty of water
''';

    test('finds exactly the four medicines, not the header', () {
      final names = parsePrescription(text, catalog, now: now).map((d) => d.medicine.name);
      expect(names, ['Napa', 'Seclo', 'Amdocal', 'Fexo']);
    });

    test('Napa: tablet, strength, morning and night, 7 days, after meal', () {
      final m = only(text, 'Napa').medicine;
      expect(m.form, MedicineForm.tablet);
      expect(m.strength, '500 mg');
      expect(m.dose, '1 Tablet');
      expect(m.times, ['08:00 AM', '08:00 PM']);
      expect(m.mealRelation, 'After Meal');
      expect(m.endDate!.difference(m.startDate!).inDays + 1, 7);
      expect(only(text, 'Napa').generic, 'Paracetamol');
      expect(only(text, 'Napa').needsCheck, isFalse);
    });

    test('Seclo: capsule before meal for a month', () {
      final m = only(text, 'Seclo').medicine;
      expect(m.form, MedicineForm.capsule);
      expect(m.mealRelation, 'Before Meal');
      expect(m.endDate!.difference(m.startDate!).inDays + 1, 30);
    });

    test('Amdocal: night only, continuing has no end date', () {
      final d = only(text, 'Amdocal');
      expect(d.medicine.times, ['08:00 PM']);
      expect(d.medicine.endDate, isNull);
      expect(d.issues, isNot(contains(ScanIssue.durationMissing)));
    });

    test('Fexo syrup: 2 teaspoons is 10 ml, strength kept whole', () {
      final m = only(text, 'Fexo').medicine;
      expect(m.form, MedicineForm.syrup);
      expect(m.strength, '30 mg/5 ml');
      expect(m.dose, '10ml');
      expect(m.times, ['08:00 AM', '08:00 PM']);
    });
  });

  test('dose on the next line, written in Bangla', () {
    final m = only('Tab. Comet 500mg\n১+০+১ খাবারের পরে ১৫ দিন', 'Comet').medicine;
    expect(m.strength, '500 mg');
    expect(m.times, ['08:00 AM', '08:00 PM']);
    expect(m.mealRelation, 'After Meal');
    expect(m.endDate!.difference(m.startDate!).inDays + 1, 15);
  });

  test('a misread name is corrected and flagged for checking', () {
    final d = only('Tab. Rosuvo 10mg 0+0+1', 'Rosuva');
    expect(d.readAs, 'Rosuvo');
    expect(d.issues, contains(ScanIssue.nameGuessed));
    expect(d.needsCheck, isTrue);
  });

  test('digits read instead of letters are fixed', () {
    expect(only('Cap. Maxpr0 20 mg 1-0-1', 'Maxpro').medicine.times, ['08:00 AM', '08:00 PM']);
  });

  test('a generic name is kept as written', () {
    final d = only('Tab. Metformin 500 mg 1+0+1', 'Metformin');
    expect(d.generic, 'Metformin Hydrochloride');
  });

  test('half tablet at noon', () {
    final m = only('Tab. Ecosprin 75 mg 0+½+0', 'Ecosprin').medicine;
    expect(m.dose, '½ Tablet');
    expect(m.times, ['02:00 PM']);
  });

  test('eye drops: form from the prefix, number of drops', () {
    final m = only('Eye drop Hypersol 5%  2 drops TDS', 'Hypersol').medicine;
    expect(m.form, MedicineForm.drops);
    expect(m.dose, '2 Drops');
    expect(m.times, ['08:00 AM', '02:00 PM', '08:00 PM']);
  });

  test('no times written: default time, flagged', () {
    final d = only('Tab. Monas 10 mg', 'Monas');
    expect(d.medicine.times, ['08:00 AM']);
    expect(d.issues, contains(ScanIssue.timesMissing));
  });

  test('plain text without medicines gives nothing', () {
    expect(parsePrescription('Name: Abdul\nAge 60 years\nBP 130/80\nNext visit after 7 days', catalog), isEmpty);
  });

  group('dose parser', () {
    test('1 tab x 3 days', () {
      final d = parseDose('1 tab x 3 days', MedicineForm.tablet);
      expect(d.dose, '1 Tablet');
      expect(d.durationDays, 3);
      expect(d.times, isEmpty);
    });
    test('four times a day', () {
      expect(parseDose('1+1+1+1', MedicineForm.tablet).times.length, 4);
    });
    test('a date is not a dose', () {
      expect(parseDose('12-05-2026', MedicineForm.tablet).pattern, isNull);
    });
    test('Bangla before meal and weeks', () {
      final d = parseDose('খালি পেটে ২ সপ্তাহ', MedicineForm.tablet);
      expect(d.mealRelation, 'Before Meal');
      expect(d.durationDays, 14);
    });
    test('injection amount in ml', () {
      expect(parseDose('0.5 ml SC weekly', MedicineForm.injection).dose, '0.5 ml');
    });
  });

  test('edit distance', () {
    expect(editDistance('napa', 'napa', 2), 0);
    expect(editDistance('seclo', 'sceol', 2), 2);
    expect(editDistance('maxpro', 'maxrpo', 1), 1);
    expect(editDistance('abc', 'xyzabc', 1), 2);
  });

  test('OCR blocks are rebuilt into rows', () {
    final text = rowsFromLines(const [
      OcrLine('Tab. Napa 500 mg', 10, 100, 200, 120),
      OcrLine('Cap. Seclo 20 mg', 10, 140, 200, 160),
      OcrLine('1+0+1', 300, 102, 360, 121),
      OcrLine('0+0+1', 300, 141, 360, 159),
    ]);
    expect(text, 'Tab. Napa 500 mg   1+0+1\nCap. Seclo 20 mg   0+0+1');
  });

  group('medicine packets', () {
    const strip = '''
Napa
Paracetamol BP 500 mg
Tablet
Beximco Pharmaceuticals Ltd.
Each film coated tablet contains Paracetamol BP 500 mg
Store below 30°C. Keep out of reach of children.
''';

    test('reads the brand and strength, not the maker or the generic', () {
      final drafts = parsePrescription(strip, catalog, now: now, packets: true);
      expect(drafts.map((d) => d.medicine.name), ['Napa']);
      expect(drafts.single.medicine.strength, '500 mg');
      expect(drafts.single.medicine.form, MedicineForm.tablet);
    });

    test('packet drafts ask for times and ignore dose text on the box', () {
      const box = 'Seclo 20\nOmeprazole 20 mg capsule\nDosage: 1 capsule twice daily\nSquare Pharmaceuticals Ltd.';
      final d = parsePrescription(box, catalog, now: now, packets: true).single;
      expect(d.medicine.name, 'Seclo');
      expect(d.medicine.strength, '20 mg');
      expect(d.issues, contains(ScanIssue.timesMissing));
      expect(d.needsCheck, isTrue);
    });
  });

  group('typing suggestions', () {
    test('first letters suggest brands, shortest first', () {
      expect(catalog.search('nap').first.brand, 'Napa');
    });
    test('a generic name suggests its brands', () {
      expect(catalog.search('metformin').map((e) => e.generic), everyElement(contains('Metformin')));
    });
    test('a small spelling mistake still finds the brand', () {
      expect(catalog.search('Rosuvo').map((e) => e.brand), contains('Rosuva'));
    });
    test('one letter suggests nothing', () {
      expect(catalog.search('n'), isEmpty);
    });
  });
}
