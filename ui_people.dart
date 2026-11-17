import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';

import 'models.dart';
import 'store.dart';
import 'ui_common.dart';

// ======================= People list + search =======================

class PeoplePage extends StatefulWidget {
  final String? groupId;
  final bool standalone;
  const PeoplePage({super.key, this.groupId, this.standalone = false});
  @override
  State<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends State<PeoplePage> {
  final _q = TextEditingController();
  String? _group;

  @override
  void initState() {
    super.initState();
    _group = widget.groupId;
  }

  bool _match(Person p, String q) {
    if (q.isEmpty) return true;
    final s = q.toLowerCase();
    final fields = [
      p.id,
      p.v('fullName'),
      p.v('fatherName'),
      p.v('cnic'),
      p.v('mobile'),
      p.v('mobile2'),
      p.v('city'),
      p.v('district'),
      store.groupName(p.groupId),
    ];
    if (fields.any((x) => x.toLowerCase().contains(s))) return true;
    final sd = s.replaceAll('-', '');
    return sd.isNotEmpty && p.v('cnic').replaceAll('-', '').contains(sd);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final list = store.active
            .where((p) => (_group == null || p.groupId == _group) && _match(p, _q.text.trim()))
            .toList();
        return Scaffold(
          appBar: AppBar(title: Text(tr('people')), automaticallyImplyLeading: widget.standalone),
          floatingActionButton: store.canEdit
              ? FloatingActionButton(
                  onPressed: () => go(context, PersonFormPage(groupId: _group)),
                  child: const Icon(Icons.person_add),
                )
              : null,
          body: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: TextField(
                controller: _q,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: tr('search_hint'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: groupDropdown(_group, (v) => setState(() => _group = v)),
            ),
            Expanded(
              child: list.isEmpty
                  ? Center(child: Text(tr('no_data')))
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final p = list[i];
                        final sub = [
                          if (p.v('relation').isNotEmpty) p.v('relation'),
                          p.id,
                          store.groupName(p.groupId),
                        ].join(' • ');
                        return ListTile(
                          leading: avatar(p),
                          title: Text(p.deceased ? '${p.name} (${tr('deceased_tag')})' : p.name),
                          subtitle: Text(sub),
                          onTap: () => go(context, ProfilePage(id: p.id)),
                        );
                      },
                    ),
            ),
          ]),
        );
      },
    );
  }
}

// ======================= Profile =======================

class ProfilePage extends StatefulWidget {
  final String id;
  const ProfilePage({super.key, required this.id});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Future<void> _addDoc(Person p) async {
    final r = await FilePicker.platform.pickFiles();
    final file = r?.files.single;
    if (file == null || file.path == null) return;
    final stored = await store.saveMedia(file.path!);
    p.docs.add('$stored::${file.name}');
    await store.savePerson(p);
  }

  Widget _row(String label, String value) => ListTile(
        dense: true,
        title: Text(label, style: Theme.of(context).textTheme.bodySmall),
        subtitle: SelectableText(value, style: Theme.of(context).textTheme.bodyLarge),
      );

  Widget _link(String label, Person? q, String fallback) {
    if (q != null) {
      return ListTile(
        leading: avatar(q, r: 18),
        title: Text(q.name),
        subtitle: Text(label),
        onTap: () => go(context, ProfilePage(id: q.id)),
      );
    }
    if (fallback.isNotEmpty) return _row(label, fallback);
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = store.person(widget.id);
        if (p == null || p.deleted) {
          return Scaffold(appBar: AppBar(), body: Center(child: Text(tr('no_data'))));
        }
        final father = store.person(p.fatherId);
        final mother = store.person(p.motherId);
        final spouse = store.person(p.spouseId);
        final kids = store.childrenOf(p.id);
        final hide = !store.canEdit;
        return Scaffold(
          appBar: AppBar(
            title: Text(tr('profile')),
            actions: [
              if (store.canEdit)
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => go(context, PersonFormPage(id: p.id)),
                ),
              if (store.canEdit)
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    if (await askConfirm(context, tr('confirm_delete'))) {
                      await store.softDelete(p.id);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                ),
            ],
          ),
          body: ListView(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                avatar(p, r: 56),
                const SizedBox(height: 8),
                Text(p.name, style: Theme.of(context).textTheme.headlineSmall),
                Text('${tr('member_id')}: ${p.id}'),
                if (p.deceased)
                  Chip(label: Text(tr('deceased_tag')), avatar: const Icon(Icons.local_florist, size: 16)),
              ]),
            ),
            const Divider(),
            _row(tr('group'), store.groupName(p.groupId)),
            if (p.age != null) _row(tr('age'), '${p.age}'),
            for (final fd in personFields.skip(1))
              if (p.v(fd.key).isNotEmpty)
                _row(
                  fd.label,
                  hide && sensitiveKeys.contains(fd.key)
                      ? maskValue(p.v(fd.key))
                      : displayValue(fd, p.v(fd.key)),
                ),
            if (hide)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(tr('sensitive_hidden'), style: Theme.of(context).textTheme.bodySmall),
              ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(tr('family_links'), style: Theme.of(context).textTheme.titleMedium),
            ),
            _link(tr('father'), father, p.v('fatherName')),
            _link(tr('mother'), mother, p.v('motherName')),
            _link(tr('spouse'), spouse, p.v('spouseName')),
            for (final k in kids) _link(tr('kids'), k, ''),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(tr('documents'), style: Theme.of(context).textTheme.titleMedium),
            ),
            if (p.docs.isEmpty)
              Padding(padding: const EdgeInsets.all(16), child: Text(tr('no_docs'))),
            for (final d in p.docs)
              ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: Text(d.contains('::') ? d.split('::').last : d),
                onTap: () => OpenFilex.open(store.mediaPath(d.split('::').first)),
                trailing: store.canEdit
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () async {
                          p.docs.remove(d);
                          await store.savePerson(p);
                        },
                      )
                    : null,
              ),
            if (store.canEdit)
              Padding(
                padding: const EdgeInsets.all(12),
                child: OutlinedButton.icon(
                  onPressed: () => _addDoc(p),
                  icon: const Icon(Icons.attach_file),
                  label: Text(tr('add_document')),
                ),
              ),
            const SizedBox(height: 24),
          ]),
        );
      },
    );
  }
}

// ======================= Add / Edit form =======================

class PersonFormPage extends StatefulWidget {
  final String? id;
  final String? groupId;
  const PersonFormPage({super.key, this.id, this.groupId});
  @override
  State<PersonFormPage> createState() => _PersonFormPageState();
}

class _PersonFormPageState extends State<PersonFormPage> {
  late Person _p;
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _c = {};
  final Map<String, String> _vals = {};
  String? _photo, _fatherId, _motherId, _spouseId;
  String _groupId = '';

  bool get _isNew => widget.id == null;
  static const _choiceTypes = {'gender', 'marital', 'date'};

  @override
  void initState() {
    super.initState();
    final ex = store.person(widget.id);
    _p = ex ??
        Person(
          id: '',
          groupId: widget.groupId ?? (store.groups.isNotEmpty ? store.groups.first.id : ''),
        );
    _groupId = _p.groupId;
    _photo = _p.photo;
    _fatherId = _p.fatherId;
    _motherId = _p.motherId;
    _spouseId = _p.spouseId;
    for (final fd in personFields) {
      if (_choiceTypes.contains(fd.type)) {
        _vals[fd.key] = _p.v(fd.key);
      } else {
        _c[fd.key] = TextEditingController(text: _p.v(fd.key));
      }
    }
  }

  Future<void> _pickPhoto(ImageSource s) async {
    final x = await ImagePicker().pickImage(source: s, maxWidth: 1024, imageQuality: 80);
    if (x == null) return;
    final name = await store.saveMedia(x.path);
    setState(() => _photo = name);
  }

  Future<void> _pickLink(String title, String nameKey, void Function(String?) setId) async {
    final res = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PickerSheet(title: title, exclude: _p.id),
    );
    if (res is Person) {
      setState(() {
        setId(res.id);
        _c[nameKey]!.text = res.name;
        if (nameKey == 'spouseName' && (_vals['maritalStatus'] ?? '').isEmpty) {
          _vals['maritalStatus'] = 'married';
        }
      });
    } else if (res == 'clear') {
      setState(() => setId(null));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final p = _p;
    for (final fd in personFields) {
      p.f[fd.key] = (_c[fd.key]?.text ?? _vals[fd.key] ?? '').trim();
    }
    p.groupId = _groupId;
    p.photo = _photo;
    p.fatherId = _fatherId;
    p.motherId = _motherId;
    p.spouseId = _spouseId;
    if (_isNew) p.id = store.newId();
    await store.savePerson(p);
    if (mounted) {
      snack(context, tr('saved_ok'));
      Navigator.pop(context);
    }
  }

  Widget _gap(Widget w) => Padding(padding: const EdgeInsets.only(bottom: 12), child: w);

  Widget _dateField(FieldDef fd) {
    final v = _vals[fd.key] ?? '';
    return _gap(InkWell(
      onTap: () async {
        var init = DateTime.tryParse(v) ?? DateTime.now();
        if (init.year < 1800 || init.year > 2100) init = DateTime.now();
        final d = await showDatePicker(
          context: context,
          initialDate: init,
          firstDate: DateTime(1800),
          lastDate: DateTime(2100),
        );
        if (d != null) setState(() => _vals[fd.key] = fmtDate(d));
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: fd.label,
          border: const OutlineInputBorder(),
          suffixIcon: v.isEmpty
              ? const Icon(Icons.calendar_today)
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _vals[fd.key] = ''),
                ),
        ),
        child: Text(v.isEmpty ? ' ' : v),
      ),
    ));
  }

  Widget _choiceField(FieldDef fd) {
    final opts = fd.type == 'gender'
        ? ['', 'male', 'female']
        : ['', 'single', 'married', 'widowed', 'divorced'];
    final cur = opts.contains(_vals[fd.key]) ? _vals[fd.key]! : '';
    return _gap(DropdownButtonFormField<String>(
      value: cur,
      decoration: InputDecoration(labelText: fd.label, border: const OutlineInputBorder()),
      items: [
        for (final o in opts)
          DropdownMenuItem(value: o, child: Text(o.isEmpty ? '—' : tr(o))),
      ],
      onChanged: (x) => setState(() => _vals[fd.key] = x ?? ''),
    ));
  }

  Widget _textField(FieldDef fd) {
    TextInputType kt = TextInputType.text;
    if (fd.type == 'phone') kt = TextInputType.phone;
    if (fd.type == 'email') kt = TextInputType.emailAddress;
    if (fd.type == 'cnic') kt = TextInputType.number;
    return _gap(TextFormField(
      controller: _c[fd.key],
      keyboardType: fd.type == 'multiline' ? TextInputType.multiline : kt,
      maxLines: fd.type == 'multiline' ? 3 : 1,
      decoration: InputDecoration(labelText: fd.label, border: const OutlineInputBorder()),
      validator: (v) {
        final t = (v ?? '').trim();
        if (fd.key == 'fullName' && t.isEmpty) return tr('required');
        if (fd.type == 'cnic' && t.isNotEmpty) {
          final d = t.replaceAll('-', '');
          if (d.length != 13 || int.tryParse(d) == null) return tr('invalid_cnic');
        }
        if (fd.type == 'email' && t.isNotEmpty && (!t.contains('@') || !t.contains('.'))) {
          return tr('invalid_email');
        }
        return null;
      },
    ));
  }

  Widget _linkTile(String label, String? id, VoidCallback onTap) {
    final q = store.person(id);
    return Card(
      child: ListTile(
        leading: q != null ? avatar(q, r: 16) : const Icon(Icons.link),
        title: Text(label),
        subtitle: Text(q?.name ?? '—'),
        trailing: const Icon(Icons.arrow_drop_down),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photoPath = _photo == null ? '' : store.mediaPath(_photo!);
    final hasPhoto = photoPath.isNotEmpty && File(photoPath).existsSync();
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? tr('add_person') : tr('edit_person')),
        actions: [IconButton(icon: const Icon(Icons.check), onPressed: _save)],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Center(
              child: Column(children: [
                CircleAvatar(
                  radius: 52,
                  backgroundImage: hasPhoto ? FileImage(File(photoPath)) : null,
                  child: hasPhoto ? null : const Icon(Icons.person, size: 52),
                ),
                Wrap(spacing: 8, children: [
                  TextButton.icon(
                      onPressed: () => _pickPhoto(ImageSource.gallery),
                      icon: const Icon(Icons.photo),
                      label: Text(tr('gallery'))),
                  TextButton.icon(
                      onPressed: () => _pickPhoto(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: Text(tr('camera'))),
                  if (_photo != null)
                    TextButton.icon(
                        onPressed: () => setState(() => _photo = null),
                        icon: const Icon(Icons.delete),
                        label: Text(tr('remove'))),
                ]),
              ]),
            ),
            const SizedBox(height: 8),
            _gap(DropdownButtonFormField<String>(
              value: store.group(_groupId) != null ? _groupId : null,
              isExpanded: true,
              decoration: InputDecoration(labelText: tr('group'), border: const OutlineInputBorder()),
              items: [
                for (final g in store.groups)
                  DropdownMenuItem(value: g.id, child: Text(store.groupName(g.id))),
              ],
              onChanged: (v) => setState(() => _groupId = v ?? _groupId),
              validator: (v) => v == null ? tr('required') : null,
            )),
            for (final fd in personFields)
              fd.type == 'date'
                  ? _dateField(fd)
                  : (fd.type == 'gender' || fd.type == 'marital')
                      ? _choiceField(fd)
                      : _textField(fd),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(tr('family_links'), style: Theme.of(context).textTheme.titleMedium),
            ),
            _linkTile(tr('father'), _fatherId,
                () => _pickLink(tr('father'), 'fatherName', (id) => _fatherId = id)),
            _linkTile(tr('mother'), _motherId,
                () => _pickLink(tr('mother'), 'motherName', (id) => _motherId = id)),
            _linkTile(tr('spouse'), _spouseId,
                () => _pickLink(tr('spouse'), 'spouseName', (id) => _spouseId = id)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(tr('save')),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _PickerSheet extends StatefulWidget {
  final String title, exclude;
  const _PickerSheet({required this.title, required this.exclude});
  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final s = q.toLowerCase();
    final list = store.active
        .where((p) =>
            p.id != widget.exclude &&
            (s.isEmpty || p.name.toLowerCase().contains(s) || p.id.toLowerCase().contains(s)))
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(child: Text(widget.title, style: Theme.of(context).textTheme.titleMedium)),
              TextButton(onPressed: () => Navigator.pop(context, 'clear'), child: Text(tr('clear'))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: tr('search_hint'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => q = v),
            ),
          ),
          Expanded(
            child: ListView(children: [
              for (final p in list)
                ListTile(
                  leading: avatar(p, r: 18),
                  title: Text(p.name),
                  subtitle: Text(p.id),
                  onTap: () => Navigator.pop(context, p),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ======================= Family tree =======================

class TreePage extends StatefulWidget {
  const TreePage({super.key});
  @override
  State<TreePage> createState() => _TreePageState();
}

class _TreePageState extends State<TreePage> {
  String? _group;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final scope =
            store.active.where((p) => _group == null || p.groupId == _group).toList();
        final ids = scope.map((p) => p.id).toSet();

        bool hasParent(Person p) =>
            (p.fatherId != null && ids.contains(p.fatherId)) ||
            (p.motherId != null && ids.contains(p.motherId));

        Person? spouseOf(Person p) {
          final s = store.person(p.spouseId);
          return (s != null && !s.deleted && ids.contains(s.id)) ? s : null;
        }

        bool primary(Person p, Person s) {
          if (p.isMale && !s.isMale) return true;
          if (s.isMale && !p.isMale) return false;
          return p.id.compareTo(s.id) < 0;
        }

        final roots = scope.where((p) {
          if (hasParent(p)) return false;
          final s = spouseOf(p);
          if (s == null) return true;
          if (hasParent(s)) return false; // shown with the spouse who has parents
          return primary(p, s);
        }).toList();

        Widget node(Person p, int depth, Set<String> path) {
          if (path.contains(p.id) || depth > 15) return const SizedBox.shrink();
          final nextPath = {...path, p.id};
          final s = spouseOf(p);
          final showKids = s == null || primary(p, s) || !hasParent(s);
          final kids = !showKids
              ? <Person>[]
              : (scope
                  .where((k) =>
                      k.id != p.id &&
                      (k.fatherId == p.id ||
                          k.motherId == p.id ||
                          (s != null && (k.fatherId == s.id || k.motherId == s.id))))
                  .toList()
                ..sort((a, b) => (a.v('birthDate')).compareTo(b.v('birthDate'))));
          final label = s != null ? '${p.name}  ❤  ${s.name}' : p.name;
          final sub = [
            if (p.v('relation').isNotEmpty) p.v('relation'),
            if (p.birth != null) '${p.birth!.year}',
            if (p.deceased) tr('deceased_tag'),
          ].join(' • ');
          void open() => go(context, ProfilePage(id: p.id));
          if (kids.isEmpty) {
            return ListTile(
              dense: true,
              leading: avatar(p, r: 18),
              title: Text(label),
              subtitle: sub.isEmpty ? null : Text(sub),
              onTap: open,
            );
          }
          return ExpansionTile(
            key: ValueKey('${p.id}-$_group'),
            initiallyExpanded: depth < 2,
            leading: avatar(p, r: 18),
            title: InkWell(
              onTap: open,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            subtitle: sub.isEmpty ? null : Text(sub),
            childrenPadding: const EdgeInsetsDirectional.only(start: 16),
            children: [for (final k in kids) node(k, depth + 1, nextPath)],
          );
        }

        return Scaffold(
          appBar: AppBar(title: Text(tr('tree'))),
          body: Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: groupDropdown(_group, (v) => setState(() => _group = v)),
            ),
            Expanded(
              child: roots.isEmpty
                  ? Center(child: Text(tr('no_data')))
                  : ListView(children: [for (final r in roots) node(r, 0, {})]),
            ),
          ]),
        );
      },
    );
  }
}
