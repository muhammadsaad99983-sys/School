import 'package:flutter/material.dart';

import 'models.dart';
import 'store.dart';
import 'ui_common.dart';
import 'ui_more.dart';
import 'ui_people.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const DashboardPage(),
      const PeoplePage(),
      const TreePage(),
      const GroupsPage(),
      const MorePage(),
    ];
    return Scaffold(
      body: pages[_i],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (v) => setState(() => _i = v),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.dashboard), label: tr('dashboard')),
          NavigationDestination(icon: const Icon(Icons.people), label: tr('people')),
          NavigationDestination(icon: const Icon(Icons.account_tree), label: tr('tree')),
          NavigationDestination(icon: const Icon(Icons.folder_shared), label: tr('groups')),
          NavigationDestination(icon: const Icon(Icons.menu), label: tr('more')),
        ],
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String? _group;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final list =
            store.active.where((p) => _group == null || p.groupId == _group).toList();
        int c(bool Function(Person) f) => list.where(f).length;
        final branches = _group == null
            ? store.groups.where((g) => g.parentId != null).length
            : store.groups.where((g) => g.parentId == _group).length;
        final stats = <List<dynamic>>[
          [tr('total'), list.length, Icons.groups, Colors.teal],
          [tr('males'), c((p) => p.isMale), Icons.male, Colors.blue],
          [tr('females'), c((p) => p.isFemale), Icons.female, Colors.pink],
          [tr('children'), c((p) => !p.deceased && (p.age ?? 99) < 18), Icons.child_care, Colors.orange],
          [tr('married_c'), c((p) => !p.deceased && p.v('maritalStatus') == 'married'), Icons.favorite, Colors.red],
          [tr('unmarried_c'), c((p) => !p.deceased && p.v('maritalStatus') == 'single'), Icons.person_outline, Colors.indigo],
          [tr('deceased_c'), c((p) => p.deceased), Icons.local_florist, Colors.grey],
          [tr('branches'), branches, Icons.account_tree, Colors.green],
        ];
        final ids = list.map((p) => p.id).toSet();
        final events = [
          ...store.upcoming('birthDate').where((e) => e.days <= 7 && ids.contains(e.p.id)).map((e) => [e, tr('birthdays')]),
          ...store.upcoming('marriageDate').where((e) => e.days <= 7 && ids.contains(e.p.id)).map((e) => [e, tr('marriages')]),
        ];

        return Scaffold(
          appBar: AppBar(title: Text(tr('dashboard'))),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              groupDropdown(_group, (v) => setState(() => _group = v)),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 1.8,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: [
                  for (final s in stats)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          Icon(s[2] as IconData, color: s[3] as Color, size: 32),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${s[1]}', style: Theme.of(context).textTheme.headlineSmall),
                                Text(s[0] as String, maxLines: 2, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ]),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(tr('upcoming'), style: Theme.of(context).textTheme.titleMedium),
              if (events.isEmpty)
                Padding(padding: const EdgeInsets.all(12), child: Text(tr('no_data'))),
              for (final e in events)
                Card(
                  child: ListTile(
                    leading: avatar((e[0] as Ev).p, r: 18),
                    title: Text((e[0] as Ev).p.name),
                    subtitle: Text('${e[1]} • ${daysText((e[0] as Ev).days)}'),
                    onTap: () => go(context, ProfilePage(id: (e[0] as Ev).p.id)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData i, String t, Widget page) => ListTile(
          leading: Icon(i),
          title: Text(t),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => go(context, page),
        );
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(tr('more')),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(child: Text(store.current?.username ?? '')),
            ),
          ],
        ),
        body: ListView(children: [
          tile(Icons.cake, tr('reminders'), const RemindersPage()),
          tile(Icons.campaign, tr('announcements'), const AnnouncementsPage()),
          tile(Icons.delete_outline, tr('trash'), const TrashPage()),
          tile(Icons.import_export, tr('export_import'), const ExportImportPage()),
          tile(Icons.backup, tr('backup'), const BackupPage()),
          if (store.isAdmin) tile(Icons.admin_panel_settings, tr('users'), const UsersPage()),
          tile(Icons.settings, tr('settings'), const SettingsPage()),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(tr('logout')),
            onTap: store.logout,
          ),
        ]),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(tr('settings'))),
        body: ListView(children: [
          ListTile(title: Text(tr('language'))),
          RadioListTile<String>(
            value: 'ur',
            groupValue: store.lang,
            title: const Text('اردو (RTL)'),
            onChanged: (v) => store.setLang(v!),
          ),
          RadioListTile<String>(
            value: 'en',
            groupValue: store.lang,
            title: const Text('English'),
            onChanged: (v) => store.setLang(v!),
          ),
          SwitchListTile(
            title: Text(tr('dark_mode')),
            value: store.dark,
            onChanged: store.setDark,
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: Text(tr('change_password')),
            onTap: () async {
              final pw = await askText(context, tr('new_password'), obscure: true);
              if (pw == null) return;
              if (pw.length < 4) {
                if (context.mounted) snack(context, tr('pw_short'));
                return;
              }
              await store.setPassword(store.current!, pw);
              if (context.mounted) snack(context, tr('pw_changed'));
            },
          ),
        ]),
      ),
    );
  }
}
