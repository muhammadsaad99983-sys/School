import 'dart:io';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xl;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'models.dart';
import 'store.dart';

List<String> _header() =>
    ['memberId', 'group', ...personFields.map((f) => f.key)];

List<String> _row(Person p) => [
      p.id,
      store.groupName(p.groupId),
      ...personFields.map((f) => p.v(f.key))
    ];

Future<File> _tmp(String name) async =>
    File('${(await getTemporaryDirectory()).path}/$name');

Future<File> exportCsv({bool templateOnly = false}) async {
  final rows = <List<String>>[
    _header(),
    if (!templateOnly) ...store.active.map(_row),
  ];
  final text = '\uFEFF${const ListToCsvConverter().convert(rows)}';
  final f = await _tmp(templateOnly ? 'family_template.csv' : 'family_data.csv');
  await f.writeAsString(text);
  return f;
}

Future<File> exportExcel() async {
  final ex = xl.Excel.createExcel();
  final sh = ex['Sheet1'];
  sh.appendRow(_header().map((e) => xl.TextCellValue(e)).toList());
  for (final p in store.active) {
    sh.appendRow(_row(p).map((e) => xl.TextCellValue(e)).toList());
  }
  final bytes = ex.save();
  final f = await _tmp('family_data.xlsx');
  await f.writeAsBytes(bytes!);
  return f;
}

Future<File> exportPdf() async {
  pw.Font? font;
  try {
    font = await PdfGoogleFonts.notoNaskhArabicRegular();
  } catch (_) {}
  final doc = pw.Document(
      theme: font != null ? pw.ThemeData.withFont(base: font, bold: font) : null);
  final dir = appLang == 'ur' ? pw.TextDirection.rtl : pw.TextDirection.ltr;
  final people = store.active;
  doc.addPage(pw.MultiPage(
    textDirection: dir,
    build: (c) => [
      pw.Header(level: 0, child: pw.Text(tr('app'))),
      for (final p in people)
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 10),
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('${p.name}  (${p.id})  -  ${store.groupName(p.groupId)}',
                  style: const pw.TextStyle(fontSize: 14)),
              for (final fd in personFields.skip(1))
                if (p.v(fd.key).isNotEmpty)
                  pw.Text('${fd.label}: ${displayValue(fd, p.v(fd.key))}'),
            ],
          ),
        ),
    ],
  ));
  final f = await _tmp('family_data.pdf');
  await f.writeAsBytes(await doc.save());
  return f;
}

/// Imports many people at once. Returns how many were added.
Future<int> importFile(String path, String defaultGroupId) async {
  List<List<dynamic>> rows;
  if (path.toLowerCase().endsWith('.csv')) {
    var text = File(path).readAsStringSync();
    if (text.startsWith('\uFEFF')) text = text.substring(1);
    rows = const CsvToListConverter(eol: '\n')
        .convert(text.replaceAll('\r\n', '\n').replaceAll('\r', '\n'));
  } else {
    final ex = xl.Excel.decodeBytes(File(path).readAsBytesSync());
    final sh = ex.tables.values.first;
    rows = sh.rows
        .map((r) => r.map((c) => c?.value?.toString() ?? '').toList())
        .toList();
  }
  if (rows.length < 2) return 0;

  final keys = <String?>[];
  for (final h in rows.first.map((e) => e.toString().trim())) {
    String? k;
    if (h == 'group') {
      k = 'group';
    } else {
      for (final fd in personFields) {
        if (fd.key == h || fd.ur == h || fd.en == h) k = fd.key;
      }
    }
    keys.add(k);
  }

  var n = 0;
  for (final r in rows.skip(1)) {
    final f = <String, String>{};
    var gid = defaultGroupId;
    for (var i = 0; i < keys.length && i < r.length; i++) {
      final k = keys[i];
      if (k == null) continue;
      final val = r[i].toString().trim();
      if (k == 'group') {
        final gs = store.groups
            .where((g) => g.name == val || store.groupName(g.id) == val);
        if (val.isNotEmpty && gs.isNotEmpty) gid = gs.first.id;
        continue;
      }
      f[k] = normalizeValue(k, val);
    }
    if ((f['fullName'] ?? '').isEmpty) continue;
    store.people.add(Person(id: store.newId(), groupId: gid, f: f));
    n++;
  }
  await store.save();
  return n;
}
