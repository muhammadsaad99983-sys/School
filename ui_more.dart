import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'io_tools.dart';
import 'models.dart';
import 'store.dart';
import 'ui_common.dart';
import 'ui_people.dart';

// ======================= Groups / branches =======================

class GroupsPage extends StatelessWidget {
  const GroupsPage({super.key});

  Future<void> _edit(BuildContext context, {Group? g}) async {
    final ctrl = TextEditingController(text: g?.name ?? '');
    String? parent = g?.parentId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(g == null ? tr('add_group') : tr('rename')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: InputDecoration(labelText: tr('group_name')),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: parent,
              isExpanded: true,
              decoration: InputDecoration(labelText: tr('parent_branch')),
              items: [
                DropdownMenuItem<String?>(value: null, child: Text(tr('main_group'))),
                for (final x in store.groups.where((x) => x.id != g?.id))
                  DropdownMenuItem<String?>(value: x.id, child: Text(store.groupName(x.id))),
              ],
              onChanged: (v) => setS(() => parent = v),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('ok'))),
          ],
        ),
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty) return;
    if (g == null) {
      await store.addGroup(ctrl.text, parentId: parent);
    } else {
      g.name = ctrl.text.trim();
      g.parentId = parent;
      await store.save();
    }
  }

  Future<void> _delete(BuildContext context, Group g) async {
    if (store.groups.length <= 1) {
      snack(context, tr('last_group'));
      return;
    }
    final used = store.people.any((p) => p.groupId == g.id) ||
        store.groups.any((x) => x.parentId == g.id);
    if (used) {
      snack(context, tr('group_not_empty'));
      return;
    }
    if (await askConfirm(context, tr('confirm_delete'))) {
      store.groups.remove(g);
      await store.save();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(tr('groups'))),
        floatingActionButton: store.canEdit
            ? FloatingActionButton(
                onPressed: () => _edit(context),
                child: const Icon(Icons.create_new_folder),
              )
            : null,
        body: ListView(children: [
          for (final g in store.groups)
            ListTile(
              leading: Icon(g.parentId == null ? Icons.folder_shared : Icons.subdirectory_arrow_right),
              title: Text(store.groupName(g.id)),
              subtitle: Text(
                  '${store.active.where((p) => p.groupId == g.id).length} ${tr('members')}'),
              onTap: () => go(context, PeoplePage(groupId: g.id, standalone: true)),
              trailing: store.canEdit
                  ? PopupMenuButton<String>(
                      onSelected: (v) =>
                          v == 'edit' ? _edit(context, g: g) : _delete(context, g),
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'edit', child: Text(tr('rename'))),
                        PopupMenuItem(value: 'del', child: Text(tr('delete'))),
                      ],
                    )
                  : null,
            ),
        ]),
      ),
    );
  }
}

// ======================= Reminders / events =======================

class RemindersPage extends StatelessWidget {
  const RemindersPage({super.key});

  Widget _list(BuildContext context, List<Ev> evs, String Function(Ev) sub) {
    if (evs.isEmpty) return Center(child: Text(tr('no_data')));
    return ListView(children: [
      for (final e in evs)
        ListTile(
          leading: avatar(e.p, r: 18),
          title: Text(e.p.name),
          subtitle: Text(sub(e)),
          trailing: Text(daysText(e.days)),
          onTap: () => go(context, ProfilePage(id: e.p.id)),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final deaths = store.active.where((p) => p.deceased).toList()
          ..sort((a, b) => b.v('deathDate').compareTo(a.v('deathDate')));
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text(tr('reminders')),
              bottom: TabBar(tabs: [
                Tab(text: tr('birthdays')),
                Tab(text: tr('marriages')),
                Tab(text: tr('deaths')),
              ]),
            ),
            body: TabBarView(children: [
              _list(context, store.upcoming('birthDate'),
                  (e) => '${p0(e.p, 'birthDate')} • ${tr('age')} ${e.years}'),
              _list(
                  context,
                  store.upcoming('marriageDate'),
                  (e) =>
                      '${p0(e.p, 'marriageDate')} • ${e.p.v('marriagePlace')} • ${e.years}'),
              deaths.isEmpty
                  ? Center(child: Text(tr('no_data')))
                  : ListView(children: [
                      for (final p in deaths)
                        ListTile(
                          leading: avatar(p, r: 18),
                          title: Text(p.name),
                          subtitle: Text('${p.v('deathDate')} • ${p.v('deathPlace')}'),
                          onTap: () => go(context, ProfilePage(id: p.id)),
                        ),
                    ]),
            ]),
          ),
        );
      },
    );
  }

  String p0(Person p, String k) => p.v(k);
}

// ======================= Announcements =======================

class AnnouncementsPage extends StatelessWidget {
  const AnnouncementsPage({super.key});

  Future<void> _add(BuildContext context) async {
    final t = TextEditingController();
    final b = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('add_announcement')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: t, decoration: InputDecoration(labelText: tr('title'))),
          TextField(
              controller: b,
              maxLines: 4,
              decoration: InputDecoration(labelText: tr('text'))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('ok'))),
        ],
      ),
    );
    if (ok == true && t.text.trim().isNotEmpty) {
      await store.addAnnouncement(t.text.trim(), b.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(tr('announcements'))),
        floatingActionButton: store.canEdit
            ? FloatingActionButton(onPressed: () => _add(context), child: const Icon(Icons.add))
            : null,
        body: store.announcements.isEmpty
            ? Center(child: Text(tr('no_announcements')))
            : ListView(children: [
                for (final a in store.announcements)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.campaign),
                      title: Text(a.title),
                      subtitle: Text('${a.date}\n${a.body}'),
                      isThreeLine: true,
                      trailing: store.canEdit
                          ? IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () async {
                                if (await askConfirm(context, tr('confirm_delete'))) {
                                  await store.deleteAnnouncement(a);
                                }
                              },
                            )
                          : null,
                    ),
                  ),
              ]),
      ),
    );
  }
}

// ======================= Trash =======================

class TrashPage extends StatelessWidget {
  const TrashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final list = store.trashed;
        return Scaffold(
          appBar: AppBar(title: Text(tr('trash'))),
          body: list.isEmpty
              ? Center(child: Text(tr('no_data')))
              : ListView(children: [
                  for (final p in list)
                    ListTile(
                      leading: avatar(p, r: 18),
                      title: Text(p.name),
                      subtitle: Text(p.id),
                      trailing: store.canEdit
                          ? Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(
                                tooltip: tr('restore'),
                                icon: const Icon(Icons.restore),
                                onPressed: () => store.restorePerson(p.id),
                              ),
                              if (store.isAdmin)
                                IconButton(
                                  tooltip: tr('delete_forever'),
                                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                                  onPressed: () async {
                                    if (await askConfirm(context, tr('confirm_purge'))) {
                                      await store.purge(p.id);
                                    }
                                  },
                                ),
                            ])
                          : null,
                    ),
                ]),
        );
      },
    );
  }
}

// ======================= Backup / restore =======================

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});
  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _busy = false;

  Future<void> _create() async {
    final pass = await askText(context, tr('backup_pw'), obscure: true);
    if (pass == null) return;
    if (pass.length < 4) {
      if (mounted) snack(context, tr('pw_short'));
      return;
    }
    setState(() => _busy = true);
    try {
      final f = await store.createBackup(pass);
      await Share.shareXFiles([XFile(f.path)]);
    } catch (e) {
      if (mounted) snack(context, '$e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _restore() async {
    final r = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['zip']);
    final path = r?.files.single.path;
    if (path == null || !mounted) return;
    final pass = await askText(context, tr('backup_pw'), obscure: true);
    if (pass == null || !mounted) return;
    if (!await askConfirm(context, tr('restore_confirm'))) return;
    setState(() => _busy = true);
    final ok = await store.restoreBackup(path, pass);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      snack(context, tr('restore_fail'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('backup'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(tr('backup_hint')),
        const SizedBox(height: 16),
        if (_busy) const LinearProgressIndicator(),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _busy || !store.isAdmin ? null : _create,
          icon: const Icon(Icons.backup),
          label: Text(tr('create_backup')),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy || !store.isAdmin ? null : _restore,
          icon: const Icon(Icons.restore_page),
          label: Text(tr('restore_backup')),
        ),
        if (!store.isAdmin)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(tr('admin')),
          ),
      ]),
    );
  }
}

// ======================= Export / import =======================

class ExportImportPage extends StatefulWidget {
  const ExportImportPage({super.key});
  @override
  State<ExportImportPage> createState() => _ExportImportPageState();
}

class _ExportImportPageState extends State<ExportImportPage> {
  bool _busy = false;
  String? _group;

  Future<void> _export(Future<File> Function() fn) async {
    setState(() => _busy = true);
    try {
      final f = await fn();
      await Share.shareXFiles([XFile(f.path)]);
    } catch (e) {
      if (mounted) snack(context, '$e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _import() async {
    final gid = _group ?? (store.groups.isNotEmpty ? store.groups.first.id : '');
    final r = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'xlsx']);
    final path = r?.files.single.path;
    if (path == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final n = await importFile(path, gid);
      if (mounted) snack(context, '$n ${tr('import_done')}');
    } catch (e) {
      if (mounted) snack(context, '$e');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    _group ??= store.groups.isNotEmpty ? store.groups.first.id : null;
    return Scaffold(
      appBar: AppBar(title: Text(tr('export_import'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (_busy) ...[const LinearProgressIndicator(), Text(tr('working'))],
        const SizedBox(height: 8),
        FilledButton.icon(
            onPressed: _busy ? null : () => _export(exportCsv),
            icon: const Icon(Icons.table_chart),
            label: Text(tr('export_csv'))),
        const SizedBox(height: 8),
        FilledButton.icon(
            onPressed: _busy ? null : () => _export(exportExcel),
            icon: const Icon(Icons.grid_on),
            label: Text(tr('export_excel'))),
        const SizedBox(height: 8),
        FilledButton.icon(
            onPressed: _busy ? null : () => _export(exportPdf),
            icon: const Icon(Icons.picture_as_pdf),
            label: Text(tr('export_pdf'))),
        const Divider(height: 32),
        Text(tr('import_hint')),
        const SizedBox(height: 8),
        OutlinedButton.icon(
            onPressed: _busy ? null : () => _export(() => exportCsv(templateOnly: true)),
            icon: const Icon(Icons.description),
            label: Text(tr('import_template'))),
        const SizedBox(height: 12),
        if (store.canEdit) ...[
          groupDropdown(_group, (v) => setState(() => _group = v), allowAll: false),
          const SizedBox(height: 8),
          FilledButton.icon(
              onPressed: _busy ? null : _import,
              icon: const Icon(Icons.upload_file),
              label: Text(tr('import_data'))),
        ],
      ]),
    );
  }
}

// ======================= Users & permissions (admin) =======================

class UsersPage extends StatelessWidget {
  const UsersPage({super.key});

  Future<void> _add(BuildContext context) async {
    final u = TextEditingController();
    final p = TextEditingController();
    var role = 'viewer';
    String? err;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(tr('add_user')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: u, decoration: InputDecoration(labelText: tr('username'))),
            TextField(
                controller: p,
                obscureText: true,
                decoration: InputDecoration(labelText: tr('password'))),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: role,
              isExpanded: true,
              decoration: InputDecoration(labelText: tr('role')),
              items: [
                for (final r in ['admin', 'editor', 'viewer'])
                  DropdownMenuItem(value: r, child: Text(tr(r))),
              ],
              onChanged: (v) => setS(() => role = v ?? role),
            ),
            if (err != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(err!, style: const TextStyle(color: Colors.red)),
              ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
            FilledButton(
              onPressed: () async {
                if (u.text.trim().isEmpty) {
                  setS(() => err = tr('required'));
                  return;
                }
                if (p.text.length < 4) {
                  setS(() => err = tr('pw_short'));
                  return;
                }
                final added = await store.addUser(u.text, p.text, role);
                if (!added) {
                  setS(() => err = tr('user_exists'));
                  return;
                }
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: Text(tr('ok')),
            ),
          ],
        ),
      ),
    );
    if (ok == true && context.mounted) snack(context, tr('saved_ok'));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(tr('users'))),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _add(context),
          child: const Icon(Icons.person_add),
        ),
        body: ListView(children: [
          for (final u in store.users)
            ListTile(
              leading: const Icon(Icons.account_circle),
              title: Text(u.username),
              subtitle: Text(tr(u.role)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  tooltip: tr('reset_password'),
                  icon: const Icon(Icons.lock_reset),
                  onPressed: () async {
                    final pw = await askText(context, tr('new_password'), obscure: true);
                    if (pw == null) return;
                    if (pw.length < 4) {
                      if (context.mounted) snack(context, tr('pw_short'));
                      return;
                    }
                    await store.setPassword(u, pw);
                    if (context.mounted) snack(context, tr('pw_changed'));
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    if (u == store.current) {
                      snack(context, tr('cannot_delete_self'));
                      return;
                    }
                    if (await askConfirm(context, tr('confirm_delete'))) {
                      await store.deleteUser(u);
                    }
                  },
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}
