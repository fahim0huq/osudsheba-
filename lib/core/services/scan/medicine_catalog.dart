import '../../models/mock_models.dart';

/// One brand from the bundled Bangladesh medicine list (assets/data/bd_medicines.tsv).
class CatalogEntry {
  final String brand;
  final String generic;

  /// Form code (T tablet, C capsule, S syrup, I injection, D drops, X other) -> strengths.
  final Map<String, List<String>> forms;

  const CatalogEntry(this.brand, this.generic, this.forms);
}

MedicineForm? formForCode(String code) => const {
  'T': MedicineForm.tablet,
  'C': MedicineForm.capsule,
  'S': MedicineForm.syrup,
  'I': MedicineForm.injection,
  'D': MedicineForm.drops,
}[code];

String codeForForm(MedicineForm f) => const {
  MedicineForm.tablet: 'T',
  MedicineForm.capsule: 'C',
  MedicineForm.syrup: 'S',
  MedicineForm.injection: 'I',
  MedicineForm.drops: 'D',
}[f]!;

/// A name found in the list. [distance] 0 = exact; [isGeneric] = matched a generic name.
class CatalogMatch {
  final List<CatalogEntry> entries;
  final String matchedText;
  final int distance;
  final bool isGeneric;
  final int tokenStart, tokenCount;

  const CatalogMatch(this.entries, this.matchedText, this.distance, this.isGeneric, this.tokenStart, this.tokenCount);
}

/// Lowercase letters and digits only: "Napa Extra" -> "napaextra".
String nameKey(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Optimal string alignment distance (edits incl. swapping two letters), stopping early
/// once it is sure to exceed [max].
int editDistance(String a, String b, int max) {
  if ((a.length - b.length).abs() > max) return max + 1;
  var prev2 = List<int>.filled(b.length + 1, 0);
  var prev = List<int>.generate(b.length + 1, (i) => i);
  var cur = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    cur[0] = i;
    var rowMin = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      var v = prev[j - 1] + cost;
      if (prev[j] + 1 < v) v = prev[j] + 1;
      if (cur[j - 1] + 1 < v) v = cur[j - 1] + 1;
      if (i > 1 &&
          j > 1 &&
          a.codeUnitAt(i - 1) == b.codeUnitAt(j - 2) &&
          a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1) &&
          prev2[j - 2] + 1 < v) {
        v = prev2[j - 2] + 1;
      }
      cur[j] = v;
      if (v < rowMin) rowMin = v;
    }
    if (rowMin > max) return max + 1;
    final t = prev2;
    prev2 = prev;
    prev = cur;
    cur = t;
  }
  return prev[b.length];
}

/// Edits allowed when matching a misread name of [length] letters.
int allowedEdits(int length) => length < 5 ? 0 : (length < 8 ? 1 : 2);

/// The bundled medicine list with exact and typo-tolerant name lookup.
class MedicineCatalog {
  final List<CatalogEntry> entries;

  /// Words of company names ("square", "pharmaceuticals"): never a medicine on a packet.
  final Set<String> companyWords;
  final Map<String, List<CatalogEntry>> _brands = {};
  final Map<String, List<CatalogEntry>> _generics = {};
  final Map<int, List<String>> _brandKeysByLength = {};

  MedicineCatalog(this.entries, {this.companyWords = const {}}) {
    for (final e in entries) {
      _brands.putIfAbsent(nameKey(e.brand), () => []).add(e);
      // "Metformin Hydrochloride" is written "Metformin" on prescriptions.
      final first = e.generic.split(RegExp(r'[\s+]')).first;
      for (final g in {nameKey(e.generic), nameKey(first)}) {
        if (g.length >= 5) _generics.putIfAbsent(g, () => []).add(e);
      }
    }
    for (final k in _brands.keys) {
      _brandKeysByLength.putIfAbsent(k.length, () => []).add(k);
    }
  }

  /// Parses the TSV built by tools/build_medicine_list.py.
  static MedicineCatalog parse(String tsv) {
    final out = <CatalogEntry>[];
    var companies = <String>{};
    for (final line in tsv.split('\n')) {
      if (line.startsWith('#M ')) companies = line.substring(3).trim().split(' ').toSet();
      if (line.isEmpty || line.startsWith('#')) continue;
      final cols = line.split('\t');
      if (cols.length < 3) continue;
      final forms = <String, List<String>>{};
      for (final part in cols[2].split('|')) {
        final i = part.indexOf(':');
        if (i < 1) continue;
        final s = part.substring(i + 1);
        forms[part.substring(0, i)] = s.isEmpty ? const [] : s.split(';');
      }
      out.add(CatalogEntry(cols[0], cols[1], forms));
    }
    return MedicineCatalog(out, companyWords: companies);
  }

  List<CatalogEntry>? exactBrand(String key) => _brands[key];
  List<CatalogEntry>? exactGeneric(String key) => _generics[key];

  /// Closest brand to [key] within [allowedEdits]; ties go to the brand with most products.
  ({String key, int distance})? nearestBrand(String key) {
    final max = allowedEdits(key.length);
    if (max == 0) return null;
    String? best;
    var bestD = max + 1;
    for (var len = key.length - max; len <= key.length + max; len++) {
      for (final k in _brandKeysByLength[len] ?? const <String>[]) {
        final d = editDistance(key, k, bestD < max + 1 ? bestD : max);
        if (d < bestD || (d == bestD && best != null && _size(k) > _size(best))) {
          best = k;
          bestD = d;
        }
      }
    }
    return best == null || bestD > max ? null : (key: best, distance: bestD);
  }

  int _size(String key) => _brands[key]!.fold(0, (n, e) => n + e.forms.length);

  /// Suggestions while typing a name: brands starting with [query] (shortest first), then
  /// generics starting with it, then close spellings.
  List<CatalogEntry> search(String query, {int limit = 8}) {
    final key = nameKey(query);
    if (key.length < 2) return const [];
    final out = <CatalogEntry>[];
    void addAll(Iterable<CatalogEntry> es) {
      for (final e in es) {
        if (out.length >= limit) return;
        if (!out.contains(e)) out.add(e);
      }
    }

    final brandKeys = _brands.keys.where((k) => k.startsWith(key)).toList()
      ..sort((a, b) => a.length != b.length ? a.length.compareTo(b.length) : _size(b).compareTo(_size(a)));
    for (final k in brandKeys) {
      addAll(_brands[k]!);
    }
    if (out.length < limit && key.length >= 3) {
      final genericKeys = _generics.keys.where((k) => k.startsWith(key)).toList()..sort();
      for (final k in genericKeys) {
        addAll(_generics[k]!);
      }
    }
    if (out.length < limit) {
      final near = nearestBrand(key);
      if (near != null) addAll(_brands[near.key]!);
    }
    return out;
  }
}
