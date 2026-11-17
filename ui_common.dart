import 'dart:io';

import 'package:flutter/material.dart';

import 'models.dart';
import 'store.dart';

Widget avatar(Person p, {double r = 24}) {
  final path = p.photo == null ? null : store.mediaPath(p.photo!);
  if (path != null && File(path).existsSync()) {
    return CircleAvatar(radius: r, backgroundImage: FileImage(File(path)));
  }
  return CircleAvatar(
    radius: r,
    backgroundColor: p.isFemale ? Colors.pink.shade100 : Colors.blue.shade100,
    child: Icon(Icons.person, size: r, color: Colors.black54),
  );
}

void snack(BuildContext c, String m) {
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));
}

void go(BuildContext c, Widget w) =>
    Navigator.of(c).push(MaterialPageRoute(builder: (_) => w));

Future<bool> askConfirm(BuildContext c, String msg) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (ctx) => AlertDialog(
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('no'))),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('yes'))),
      ],
    ),
  );
  return r ?? false;
}

Future<String?> askText(BuildContext c, String title,
    {String initial = '', bool obscure = false, bool multiline = false}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: c,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        obscureText: obscure,
        autofocus: true,
        maxLines: obscure ? 1 : (multiline ? 4 : 1),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('cancel'))),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: Text(tr('ok'))),
      ],
    ),
  );
}

Widget groupDropdown(String? value, void Function(String?) onChanged,
    {bool allowAll = true}) {
  return DropdownButtonFormField<String?>(
    value: value,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: tr('group'),
      border: const OutlineInputBorder(),
      isDense: true,
    ),
    items: [
      if (allowAll)
        DropdownMenuItem<String?>(value: null, child: Text(tr('all_groups'))),
      for (final g in store.groups)
        DropdownMenuItem<String?>(value: g.id, child: Text(store.groupName(g.id))),
    ],
    onChanged: onChanged,
  );
}

String daysText(int d) => d == 0 ? tr('today') : '$d ${tr('days')}';
