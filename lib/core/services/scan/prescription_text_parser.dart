import 'package:uuid/uuid.dart';
import '../../models/mock_models.dart';
import 'dose_parser.dart';
import 'medicine_catalog.dart';
import 'scan_words.dart';

/// Things the person should look at before saving a scanned medicine.
enum ScanIssue { nameGuessed, timesMissing, strengthMissing, durationMissing, unusualForm }

/// One medicine suggested from a scan. Nothing is saved until the person confirms it.
class ScanDraft {
  final Medicine medicine;
  final String sourceText; // the prescription lines it was read from
  final String? generic;
  final String? readAs; // the OCR text when the name was corrected to a close match
  final Set<ScanIssue> issues;

  const ScanDraft({
    required this.medicine,
    required this.sourceText,
    this.generic,
    this.readAs,
    this.issues = const {},
  });

  bool get needsCheck => issues.contains(ScanIssue.nameGuessed) || issues.contains(ScanIssue.timesMissing);

  ScanDraft withMedicine(Medicine m, {bool checked = false}) => ScanDraft(
    medicine: m,
    sourceText: sourceText,
    generic: generic,
    readAs: readAs,
    issues: checked ? const {} : issues,
  );
}

final _tokenRe = RegExp(r"[A-Za-z0-9][A-Za-z0-9'\-]*");
final _strengthRe = RegExp(
  r'\d+(?:\.\d+)?\s*(?:mg|mcg|gm|g|ml|iu|%)(?:\s*/\s*\d*(?:\.\d+)?\s*(?:ml|gm|g|vial|sachet))?'
  r'(?:\s*\+\s*\d+(?:\.\d+)?\s*(?:mg|mcg|gm|g|ml|iu|%))*',
  caseSensitive: false,
);

String _strengthKey(String s) => s.toLowerCase().replaceAll(RegExp(r'\s'), '').replaceAll('gm', 'g');

/// Fixes letters OCR often reads as digits inside a word ("5ec1o" -> "seclo").
String _ocrLetters(String key) =>
    key.replaceAll('0', 'o').replaceAll('1', 'l').replaceAll('5', 's').replaceAll('8', 'b');

bool _wordish(String t, Set<String> skip) {
  final letters = t.replaceAll(RegExp(r'[^A-Za-z]'), '').length;
  final lower = t.toLowerCase();
  return letters >= 2 &&
      letters > t.length - letters &&
      !scanStopwords.contains(lower) &&
      !skip.contains(lower) &&
      !scanPrefixes.containsKey(lower);
}

bool _hasDose(String text) {
  final d = parseDose(text, MedicineForm.tablet);
  return d.pattern != null || d.durationDays != null || d.mealRelation != null;
}

/// Finds the medicine named on [line], if the line looks like a prescription item.
({CatalogMatch match, MedicineForm? prefix, String strength})? findMedicine(
  String line,
  MedicineCatalog catalog, {
  String nextLine = '',
  bool packets = false,
}) {
  final tokens = _tokenRe.allMatches(line).map((m) => m.group(0)!).toList();
  MedicineForm? prefix;
  var start = 0;
  for (var i = 0; i < tokens.length && i < 4; i++) {
    final f = scanPrefixes[tokens[i].toLowerCase()];
    if (f != null) {
      prefix = f;
      start = i + 1;
      break;
    }
  }
  final strength = _strengthRe.firstMatch(line)?.group(0)?.trim() ?? '';
  final hasDose = _hasDose(asciiDigits(line)) || _hasDose(asciiDigits(nextLine));
  // On a prescription, only lines that look like an item; a packet has no dose lines.
  if (!packets && prefix == null && strength.isEmpty && !hasDose) return null;

  final skip = packets ? {...packetWords, ...catalog.companyWords} : const <String>{};
  final words = <int>[
    for (var i = start; i < tokens.length; i++)
      if (_wordish(tokens[i], skip)) i,
  ];
  // Exact name: longest run of words first, earliest position first.
  for (final w in words.take(4)) {
    for (var n = 3; n >= 1; n--) {
      if (w + n > tokens.length) continue;
      final key = nameKey(tokens.sublist(w, w + n).join());
      if (key.length < 3 || (key.length < 4 && !(prefix != null && w == start))) continue;
      for (final k in {key, _ocrLetters(key)}) {
        final b = catalog.exactBrand(k);
        if (b != null) {
          return (match: CatalogMatch(b, tokens.sublist(w, w + n).join(' '), 0, false, w, n), prefix: prefix, strength: strength);
        }
        final g = catalog.exactGeneric(k);
        if (g != null) {
          return (match: CatalogMatch(g, tokens.sublist(w, w + n).join(' '), 0, true, w, n), prefix: prefix, strength: strength);
        }
      }
    }
  }
  // Close match (a misread name) only when the line clearly is a medicine line.
  if (prefix == null && strength.isEmpty) return null;
  ({String key, int distance})? best;
  var bestW = 0, bestN = 1;
  for (final w in words.take(2)) {
    for (var n = 1; n <= 2 && w + n <= tokens.length; n++) {
      final hit = catalog.nearestBrand(_ocrLetters(nameKey(tokens.sublist(w, w + n).join())));
      if (hit != null && (best == null || hit.distance < best.distance)) {
        best = hit;
        bestW = w;
        bestN = n;
      }
    }
  }
  if (best == null) return null;
  return (
    match: CatalogMatch(
      catalog.exactBrand(best.key)!,
      tokens.sublist(bestW, bestW + bestN).join(' '),
      best.distance,
      false,
      bestW,
      bestN,
    ),
    prefix: prefix,
    strength: strength,
  );
}

/// Turns OCR text of a prescription into medicine suggestions.
/// With [packets], [rawText] is read from medicine packets: no doses, and the strength
/// can be anywhere on the packet.
List<ScanDraft> parsePrescription(String rawText, MedicineCatalog catalog, {DateTime? now, bool packets = false}) {
  final lines = rawText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  final found = <int, ({CatalogMatch match, MedicineForm? prefix, String strength})>{};
  for (var i = 0; i < lines.length; i++) {
    final f = findMedicine(lines[i], catalog, nextLine: i + 1 < lines.length ? lines[i + 1] : '', packets: packets);
    if (f != null) found[i] = f;
  }
  // A packet also prints the generic name ("Paracetamol BP"): keep only the brand.
  if (packets && found.values.any((f) => !f.match.isGeneric)) {
    found.removeWhere((_, f) => f.match.isGeneric);
  }
  final starts = found.keys.toList();
  final drafts = <ScanDraft>[];
  final seen = <String>{};
  for (var k = 0; k < starts.length; k++) {
    final i = starts[k];
    final end = k + 1 < starts.length ? starts[k + 1] : lines.length;
    final block = lines.sublist(i, end.clamp(i + 1, i + 4)).join('\n');
    final d = packets
        ? _draft(_withPacketStrength(found[i]!, rawText), '', now ?? DateTime.now(), packets: true)
        : _draft(found[i]!, block, now ?? DateTime.now());
    if (seen.add('${nameKey(d.medicine.name)}|${_strengthKey(d.medicine.strength)}')) drafts.add(d);
  }
  return drafts;
}

typedef _Found = ({CatalogMatch match, MedicineForm? prefix, String strength});

/// On a packet the strength is often on another line: use the first strength on the
/// packet that this brand is sold in.
_Found _withPacketStrength(_Found f, String packetText) {
  bool sold(String s) =>
      f.match.entries.any((e) => e.forms.values.any((l) => l.any((x) => _strengthKey(x) == _strengthKey(s))));
  if (f.strength.isNotEmpty && sold(f.strength)) return f;
  for (final m in _strengthRe.allMatches(packetText)) {
    final s = m.group(0)!.trim();
    if (sold(s)) return (match: f.match, prefix: f.prefix, strength: s);
  }
  return f;
}

ScanDraft _draft(_Found f, String block, DateTime now, {bool packets = false}) {
  final issues = <ScanIssue>{};
  final sKey = _strengthKey(f.strength);
  bool hasStrength(CatalogEntry e) =>
      sKey.isNotEmpty && e.forms.values.any((l) => l.any((s) => _strengthKey(s) == sKey));
  final entry = f.match.entries.firstWhere(
    hasStrength,
    orElse: () => f.match.entries.firstWhere(
      (e) => f.prefix != null && e.forms.containsKey(codeForForm(f.prefix!)),
      orElse: () => f.match.entries.first,
    ),
  );

  var form = f.prefix;
  if (form == null && sKey.isNotEmpty) {
    for (final e in entry.forms.entries) {
      if (formForCode(e.key) != null && e.value.any((s) => _strengthKey(s) == sKey)) {
        form = formForCode(e.key);
        break;
      }
    }
  }
  form ??= entry.forms.keys.map(formForCode).whereType<MedicineForm>().firstOrNull;
  if (form == null) {
    form = MedicineForm.tablet;
    issues.add(ScanIssue.unusualForm);
  }

  final listed = entry.forms[codeForForm(form)] ?? const <String>[];
  var strength = f.strength;
  if (strength.isNotEmpty) {
    strength = listed.firstWhere((s) => _strengthKey(s) == sKey, orElse: () => strength);
  } else if (listed.length == 1) {
    strength = listed.first;
  } else {
    issues.add(ScanIssue.strengthMissing);
  }

  final info = packets ? const DoseInfo() : parseDose(block, form, strengthText: f.strength);
  if (info.times.isEmpty) issues.add(ScanIssue.timesMissing);
  if (info.durationDays == null && !info.continuing) issues.add(ScanIssue.durationMissing);
  if (f.match.distance > 0) issues.add(ScanIssue.nameGuessed);

  final name = f.match.isGeneric ? _titleCase(f.match.matchedText) : entry.brand;
  final start = DateTime(now.year, now.month, now.day);
  return ScanDraft(
    medicine: Medicine(
      id: const Uuid().v4(),
      name: name,
      strength: strength,
      form: form,
      dose: doseForSave(info.dose ?? form.defaultDose, form),
      times: info.times.isEmpty ? const ['08:00 AM'] : info.times,
      mealRelation: info.mealRelation ?? 'None',
      instruction: '',
      startDate: start,
      endDate: info.durationDays == null ? null : start.add(Duration(days: info.durationDays! - 1)),
      status: 'active',
      createdAt: now,
    ),
    sourceText: block,
    generic: entry.generic,
    readAs: f.match.distance > 0 ? f.match.matchedText : null,
    issues: issues,
  );
}

String _titleCase(String s) =>
    s.split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase()).join(' ');
