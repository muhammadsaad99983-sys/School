import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';

final store = Store();

class Ev {
  final Person p;
  final int days, years;
  Ev(this.p, this.days, this.years);
}

String hashPw(String pw, String salt) =>
    sha256.convert(utf8.encode('$salt:$pw')).toString();

String _two(int n) => n.toString().padLeft(2, '0');

String _encrypt(String plain, enc.Key key) {
  final iv = enc.IV.fromSecureRandom(16);
  final e = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
  final c = e.encryptBytes(utf8.encode(plain), iv: iv);
  return base64.encode([...iv.bytes, ...c.bytes]);
}

String _decrypt(String data, enc.Key key) {
  final all = base64.decode(data);
  final iv = enc.IV(Uint8List.fromList(all.sublist(0, 16)));
  final e = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
  final plain = e.decryptBytes(
      enc.Encrypted(Uint8List.fromList(all.sublist(16))),
      iv: iv);
  return utf8.decode(plain);
}

class Store extends ChangeNotifier {
  late Directory dir;
  enc.Key? _key;
  bool loaded = false;

  List<Person> people = [];
  List<Group> groups = [];
  List<Announcement> announcements = [];
  List<AppUser> users = [];
  AppUser? current;
  bool dark = false;
  String lang = 'ur';
  int counter = 0;

  File get _dbFile => File('${dir.path}/data.enc');
  String mediaPath(String name) => '${dir.path}/media/$name';

  bool get canEdit => current != null && current!.role != 'viewer';
  bool get isAdmin => current?.role == 'admin';

  List<Person> get active => people.where((p) => !p.deleted).toList();
  List<Person> get trashed => people.where((p) => p.deleted).toList();

  Future<void> init() async {
    dir = await getApplicationDocumentsDirectory();
    Directory('${dir.path}/media').createSync(recursive: true);
    const ss = FlutterSecureStorage();
    var k = await ss.read(key: 'dbkey');
    if (k == null) {
      k = base64.encode(enc.Key.fromSecureRandom(32).bytes);
      await ss.write(key: 'dbkey', value: k);
    }
    _key = enc.Key(base64.decode(k));
    if (_dbFile.existsSync()) {
      try {
        _fromJson(jsonDecode(_decrypt(_dbFile.readAsStringSync(), _key!))
            as Map<String, dynamic>);
      } catch (_) {
        // Keep the unreadable file instead of overwriting it.
        try {
          _dbFile.copySync('${dir.path}/data_unreadable.bak');
        } catch (_) {}
      }
    }
    appLang = lang;
    loaded = true;
    notifyListeners();
  }

  Map<String, dynamic> _toJson() => {
        'people': people.map((e) => e.toJson()).toList(),
        'groups': groups.map((e) => e.toJson()).toList(),
        'ann': announcements.map((e) => e.toJson()).toList(),
        'users': users.map((e) => e.toJson()).toList(),
        'dark': dark,
        'lang': lang,
        'counter': counter,
      };

  void _fromJson(Map<String, dynamic> j) {
    people = (j['people'] as List? ?? [])
        .map((e) => Person.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    groups = (j['groups'] as List? ?? [])
        .map((e) => Group.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    announcements = (j['ann'] as List? ?? [])
        .map((e) => Announcement.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    users = (j['users'] as List? ?? [])
        .map((e) => AppUser.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    dark = j['dark'] == true;
    lang = (j['lang'] ?? 'ur') as String;
    counter = (j['counter'] ?? 0) as int;
    appLang = lang;
  }

  Future<void> save() async {
    await _dbFile.writeAsString(_encrypt(jsonEncode(_toJson()), _key!));
    notifyListeners();
  }

  // ---------- settings ----------
  Future<void> setLang(String l) async {
    lang = l;
    appLang = l;
    await save();
  }

  Future<void> setDark(bool d) async {
    dark = d;
    await save();
  }

  // ---------- auth ----------
  String _rand() => base64.encode(enc.SecureRandom(16).bytes);

  bool login(String u, String p) {
    final m = users.where((x) => x.username == u.trim());
    if (m.isEmpty) return false;
    final user = m.first;
    if (user.hash != hashPw(p, user.salt)) return false;
    current = user;
    notifyListeners();
    return true;
  }

  void logout() {
    current = null;
    notifyListeners();
  }

  Future<bool> addUser(String u, String pw, String role) async {
    if (users.any((x) => x.username == u.trim())) return false;
    final salt = _rand();
    users.add(AppUser(
        username: u.trim(), salt: salt, hash: hashPw(pw, salt), role: role));
    await save();
    return true;
  }

  Future<void> setPassword(AppUser u, String pw) async {
    u.salt = _rand();
    u.hash = hashPw(pw, u.salt);
    await save();
  }

  Future<void> deleteUser(AppUser u) async {
    users.remove(u);
    await save();
  }

  // ---------- groups ----------
  Group? group(String? id) {
    for (final g in groups) {
      if (g.id == id) return g;
    }
    return null;
  }

  String groupName(String id) {
    final g = group(id);
    if (g == null) return '';
    final p = group(g.parentId);
    return p != null ? '${p.name} › ${g.name}' : g.name;
  }

  Future<void> addGroup(String name, {String? parentId}) async {
    groups.add(Group(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name.trim(),
        parentId: parentId));
    await save();
  }

  // ---------- people ----------
  Person? person(String? id) {
    if (id == null) return null;
    for (final p in people) {
      if (p.id == id) return p;
    }
    return null;
  }

  String newId() {
    counter++;
    return 'FM-${counter.toString().padLeft(4, '0')}';
  }

  List<Person> childrenOf(String id) => active
      .where((p) => p.fatherId == id || p.motherId == id)
      .toList();

  Future<void> savePerson(Person p) async {
    final i = people.indexWhere((e) => e.id == p.id);
    if (i >= 0) {
      final old = people[i];
      if (old.spouseId != null && old.spouseId != p.spouseId) {
        final o = person(old.spouseId);
        if (o != null && o.spouseId == p.id) o.spouseId = null;
      }
      people[i] = p;
    } else {
      people.add(p);
    }
    if (p.spouseId != null) {
      final o = person(p.spouseId);
      if (o != null) o.spouseId = p.id;
    }
    await save();
  }

  Future<void> softDelete(String id) async {
    final p = person(id);
    if (p == null) return;
    p.deleted = true;
    await save();
  }

  Future<void> restorePerson(String id) async {
    final p = person(id);
    if (p == null) return;
    p.deleted = false;
    await save();
  }

  Future<void> purge(String id) async {
    final p = person(id);
    if (p == null) return;
    for (final o in people) {
      if (o.fatherId == id) o.fatherId = null;
      if (o.motherId == id) o.motherId = null;
      if (o.spouseId == id) o.spouseId = null;
    }
    for (final d in p.docs) {
      try {
        File(mediaPath(d.split('::').first)).deleteSync();
      } catch (_) {}
    }
    if (p.photo != null) {
      try {
        File(mediaPath(p.photo!)).deleteSync();
      } catch (_) {}
    }
    people.removeWhere((e) => e.id == id);
    await save();
  }

  // ---------- announcements ----------
  Future<void> addAnnouncement(String title, String body) async {
    announcements.insert(
        0,
        Announcement(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            title: title,
            body: body,
            date: fmtDate(DateTime.now())));
    await save();
  }

  Future<void> deleteAnnouncement(Announcement a) async {
    announcements.remove(a);
    await save();
  }

  // ---------- media ----------
  Future<String> saveMedia(String srcPath) async {
    final name0 = srcPath.split(Platform.pathSeparator).last;
    final ext = name0.contains('.') ? name0.split('.').last : 'bin';
    final name = '${DateTime.now().microsecondsSinceEpoch}.$ext';
    await File(srcPath).copy(mediaPath(name));
    return name;
  }

  // ---------- events (birthdays / anniversaries) ----------
  List<Ev> upcoming(String key) {
    final out = <Ev>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final p in active) {
      if (p.deceased) continue;
      final d = DateTime.tryParse(p.v(key));
      if (d == null) continue;
      if (key == 'marriageDate' && p.spouseId != null) {
        final s = person(p.spouseId);
        if (s != null &&
            !s.deleted &&
            !s.deceased &&
            s.v('marriageDate').isNotEmpty &&
            p.id.compareTo(s.id) > 0) {
          continue; // show a couple only once
        }
      }
      var n = DateTime(today.year, d.month, d.day);
      if (n.isBefore(today)) n = DateTime(today.year + 1, d.month, d.day);
      out.add(Ev(p, n.difference(today).inDays, n.year - d.year));
    }
    out.sort((a, b) => a.days.compareTo(b.days));
    return out;
  }

  // ---------- backup / restore ----------
  enc.Key _pwKey(String pw) =>
      enc.Key(Uint8List.fromList(sha256.convert(utf8.encode(pw)).bytes));

  Future<File> createBackup(String password) async {
    final arc = Archive();
    final data = utf8.encode(_encrypt(jsonEncode(_toJson()), _pwKey(password)));
    arc.addFile(ArchiveFile('data.enc', data.length, data));
    final md = Directory('${dir.path}/media');
    for (final f in md.listSync().whereType<File>()) {
      final b = f.readAsBytesSync();
      arc.addFile(ArchiveFile(
          'media/${f.path.split(Platform.pathSeparator).last}', b.length, b));
    }
    final zip = ZipEncoder().encode(arc)!;
    final tmp = await getTemporaryDirectory();
    final d = DateTime.now();
    final f = File(
        '${tmp.path}/family_backup_${d.year}${_two(d.month)}${_two(d.day)}_${_two(d.hour)}${_two(d.minute)}.zip');
    await f.writeAsBytes(zip);
    return f;
  }

  Future<bool> restoreBackup(String path, String password) async {
    try {
      final arc = ZipDecoder().decodeBytes(File(path).readAsBytesSync());
      final df = arc.files.firstWhere((f) => f.name == 'data.enc');
      final json = jsonDecode(_decrypt(
              utf8.decode(df.content as List<int>), _pwKey(password)))
          as Map<String, dynamic>;
      for (final f in arc.files) {
        if (f.isFile && f.name.startsWith('media/')) {
          final out = File('${dir.path}/${f.name}');
          out.parent.createSync(recursive: true);
          out.writeAsBytesSync(f.content as List<int>);
        }
      }
      _fromJson(json);
      current = null;
      await save();
      return true;
    } catch (_) {
      return false;
    }
  }
}
