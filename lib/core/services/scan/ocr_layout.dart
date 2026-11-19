/// A line of text found by OCR, with its box on the photo.
class OcrLine {
  final String text;
  final double left, top, right, bottom;

  const OcrLine(this.text, this.left, this.top, this.right, this.bottom);

  double get height => bottom - top;
}

/// Rebuilds the rows of the page. OCR returns text in blocks, so on a printed prescription
/// all the names can come first and all the "1+0+1" doses later. Joining the lines that sit
/// at the same height keeps each medicine with its dose: "Napa 500 mg   1+0+1   7 days".
String rowsFromLines(List<OcrLine> lines) {
  final sorted = [...lines]..sort((a, b) => a.top.compareTo(b.top));
  final rows = <List<OcrLine>>[];
  for (final l in sorted) {
    List<OcrLine>? row;
    for (final r in rows.reversed.take(3)) {
      final top = r.map((x) => x.top).reduce((a, b) => a > b ? a : b);
      final bottom = r.map((x) => x.bottom).reduce((a, b) => a < b ? a : b);
      final overlap = (bottom < l.bottom ? bottom : l.bottom) - (top > l.top ? top : l.top);
      final minH = r.first.height < l.height ? r.first.height : l.height;
      if (minH > 0 && overlap >= minH * 0.5) {
        row = r;
        break;
      }
    }
    row == null ? rows.add([l]) : row.add(l);
  }
  return rows
      .map((r) {
        r.sort((a, b) => a.left.compareTo(b.left));
        return r.map((x) => x.text.trim()).join('   ');
      })
      .join('\n');
}
