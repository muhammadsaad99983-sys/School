// Data models, field definitions and Urdu/English strings.

String appLang = 'ur';

String tr(String k) {
  final v = _t[k];
  if (v == null) return k;
  return appLang == 'ur' ? v[0] : v[1];
}

String fmtDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class FieldDef {
  final String key, ur, en, type;
  const FieldDef(this.key, this.ur, this.en, [this.type = 'text']);
  String get label => appLang == 'ur' ? ur : en;
}

/// All 34 profile items (the photo is item 2 and is stored separately).
const personFields = <FieldDef>[
  FieldDef('fullName', 'مکمل نام', 'Full name'),
  FieldDef('gender', 'جنس', 'Gender', 'gender'),
  FieldDef('fatherName', 'والد کا مکمل نام', "Father's full name"),
  FieldDef('motherName', 'والدہ کا مکمل نام', "Mother's full name"),
  FieldDef('grandfatherName', 'دادا کا نام', "Paternal grandfather's name"),
  FieldDef('grandmotherName', 'دادی کا نام', "Paternal grandmother's name"),
  FieldDef('maternalGrandfatherName', 'نانا کا نام', "Maternal grandfather's name"),
  FieldDef('maternalGrandmotherName', 'نانی کا نام', "Maternal grandmother's name"),
  FieldDef('birthDate', 'تاریخ پیدائش', 'Date of birth', 'date'),
  FieldDef('birthPlace', 'جائے پیدائش', 'Place of birth'),
  FieldDef('country', 'ملک', 'Country'),
  FieldDef('province', 'صوبہ', 'Province'),
  FieldDef('district', 'ضلع', 'District'),
  FieldDef('city', 'شہر یا گاؤں', 'City or village'),
  FieldDef('currentAddress', 'موجودہ مکمل پتہ', 'Current full address', 'multiline'),
  FieldDef('permanentAddress', 'مستقل پتہ', 'Permanent address', 'multiline'),
  FieldDef('cnic', 'شناختی کارڈ نمبر (CNIC)', 'CNIC number', 'cnic'),
  FieldDef('passport', 'پاسپورٹ نمبر', 'Passport number'),
  FieldDef('mobile', 'موبائل نمبر', 'Mobile number', 'phone'),
  FieldDef('mobile2', 'اضافی موبائل نمبر', 'Additional mobile number', 'phone'),
  FieldDef('email', 'ای میل', 'Email', 'email'),
  FieldDef('education', 'تعلیم', 'Education'),
  FieldDef('profession', 'پیشہ', 'Profession'),
  FieldDef('job', 'ملازمت', 'Employment'),
  FieldDef('maritalStatus', 'ازدواجی حیثیت', 'Marital status', 'marital'),
  FieldDef('spouseName', 'شریک حیات کا نام', "Spouse's name"),
  FieldDef('marriageDate', 'نکاح کی تاریخ', 'Marriage date', 'date'),
  FieldDef('marriagePlace', 'نکاح کا مقام', 'Marriage place'),
  FieldDef('childrenNames', 'بچوں کے نام', "Children's names", 'multiline'),
  FieldDef('relation', 'خاندان میں رشتہ', 'Relation in family'),
  FieldDef('deathDate', 'وفات کی تاریخ', 'Date of death', 'date'),
  FieldDef('deathPlace', 'وفات کا مقام', 'Place of death'),
  FieldDef('notes', 'اضافی معلومات', 'Additional information', 'multiline'),
];

const sensitiveKeys = {'cnic', 'passport', 'mobile', 'mobile2', 'email'};

String displayValue(FieldDef f, String v) {
  if (v.isEmpty) return v;
  if (f.type == 'gender' || f.type == 'marital') return tr(v);
  return v;
}

String maskValue(String v) {
  if (v.isEmpty) return v;
  if (v.length <= 4) return '••••';
  return '••••${v.substring(v.length - 3)}';
}

/// Used by CSV/Excel import: turns user-typed text into stored codes.
String normalizeValue(String key, String val) {
  if (val.isEmpty) return val;
  final low = val.toLowerCase();
  switch (key) {
    case 'gender':
      if (['male', 'm', 'مرد'].contains(low)) return 'male';
      if (['female', 'f', 'عورت', 'خاتون'].contains(low)) return 'female';
      return '';
    case 'maritalStatus':
      if (['single', 'unmarried', 'غیر شادی شدہ', 'کنوارا'].contains(low)) return 'single';
      if (['married', 'شادی شدہ'].contains(low)) return 'married';
      if (['widowed', 'widow', 'بیوہ', 'رنڈوا'].contains(low)) return 'widowed';
      if (['divorced', 'مطلقہ', 'طلاق یافتہ'].contains(low)) return 'divorced';
      return '';
    case 'birthDate':
    case 'marriageDate':
    case 'deathDate':
      final m = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})$').firstMatch(val);
      if (m != null) {
        return '${m.group(3)}-${m.group(2)!.padLeft(2, '0')}-${m.group(1)!.padLeft(2, '0')}';
      }
      final d = DateTime.tryParse(val);
      return d == null ? val : fmtDate(d);
    default:
      return val;
  }
}

class Person {
  String id, groupId;
  String? fatherId, motherId, spouseId, photo;
  Map<String, String> f;
  List<String> docs; // entries look like "storedName::originalName"
  bool deleted;

  Person({
    required this.id,
    required this.groupId,
    this.fatherId,
    this.motherId,
    this.spouseId,
    this.photo,
    Map<String, String>? f,
    List<String>? docs,
    this.deleted = false,
  })  : f = f ?? {},
        docs = docs ?? [];

  String v(String k) => f[k] ?? '';
  String get name => v('fullName');
  bool get isMale => v('gender') == 'male';
  bool get isFemale => v('gender') == 'female';
  bool get deceased => v('deathDate').isNotEmpty;
  DateTime? get birth => DateTime.tryParse(v('birthDate'));

  int? get age {
    final b = birth;
    if (b == null) return null;
    final end = DateTime.tryParse(v('deathDate')) ?? DateTime.now();
    var a = end.year - b.year;
    if (end.month < b.month || (end.month == b.month && end.day < b.day)) a--;
    return a < 0 ? 0 : a;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'groupId': groupId,
        'fatherId': fatherId,
        'motherId': motherId,
        'spouseId': spouseId,
        'photo': photo,
        'f': f,
        'docs': docs,
        'deleted': deleted,
      };

  factory Person.fromJson(Map<String, dynamic> j) => Person(
        id: j['id'] as String,
        groupId: (j['groupId'] ?? '') as String,
        fatherId: j['fatherId'] as String?,
        motherId: j['motherId'] as String?,
        spouseId: j['spouseId'] as String?,
        photo: j['photo'] as String?,
        f: Map<String, String>.from(j['f'] ?? {}),
        docs: List<String>.from(j['docs'] ?? []),
        deleted: j['deleted'] == true,
      );
}

class Group {
  String id, name;
  String? parentId;
  Group({required this.id, required this.name, this.parentId});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'parentId': parentId};
  factory Group.fromJson(Map<String, dynamic> j) =>
      Group(id: j['id'], name: j['name'], parentId: j['parentId']);
}

class Announcement {
  String id, title, body, date;
  Announcement({required this.id, required this.title, required this.body, required this.date});
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'body': body, 'date': date};
  factory Announcement.fromJson(Map<String, dynamic> j) =>
      Announcement(id: j['id'], title: j['title'], body: j['body'], date: j['date']);
}

class AppUser {
  String username, salt, hash, role; // role: admin | editor | viewer
  AppUser({required this.username, required this.salt, required this.hash, required this.role});
  Map<String, dynamic> toJson() =>
      {'username': username, 'salt': salt, 'hash': hash, 'role': role};
  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
      username: j['username'], salt: j['salt'], hash: j['hash'], role: j['role']);
}

const Map<String, List<String>> _t = {
  'app': ['فیملی گروپ مینجمنٹ', 'Family Group Manager'],
  'setup_title': ['ایڈمن اکاؤنٹ بنائیں', 'Create admin account'],
  'setup_msg': [
    'پہلی مرتبہ ایپ کھولنے پر ایڈمن اکاؤنٹ بنانا ضروری ہے۔ پاس ورڈ یاد رکھیں۔',
    'Create the admin account on first launch. Remember the password.'
  ],
  'username': ['صارف نام', 'Username'],
  'password': ['پاس ورڈ', 'Password'],
  'confirm_password': ['پاس ورڈ دوبارہ لکھیں', 'Confirm password'],
  'create_admin': ['اکاؤنٹ بنائیں', 'Create account'],
  'login': ['لاگ ان', 'Log in'],
  'logout': ['لاگ آؤٹ', 'Log out'],
  'wrong_login': ['صارف نام یا پاس ورڈ غلط ہے', 'Wrong username or password'],
  'pw_short': ['پاس ورڈ کم از کم 4 حروف کا ہو', 'Password must be at least 4 characters'],
  'pw_mismatch': ['پاس ورڈ آپس میں نہیں ملتے', 'Passwords do not match'],
  'required': ['یہ خانہ ضروری ہے', 'This field is required'],
  'default_group': ['میرا خاندان', 'My Family'],
  'dashboard': ['ڈیش بورڈ', 'Dashboard'],
  'people': ['افراد', 'People'],
  'tree': ['شجرہ', 'Tree'],
  'groups': ['گروپس', 'Groups'],
  'more': ['مزید', 'More'],
  'total': ['کل افراد', 'Total members'],
  'males': ['مرد', 'Males'],
  'females': ['خواتین', 'Females'],
  'children': ['بچے', 'Children'],
  'married_c': ['شادی شدہ', 'Married'],
  'unmarried_c': ['غیر شادی شدہ', 'Unmarried'],
  'deceased_c': ['مرحوم افراد', 'Deceased'],
  'branches': ['خاندانی شاخیں', 'Family branches'],
  'all_groups': ['تمام گروپس', 'All groups'],
  'upcoming': ['آنے والی تقریبات (7 دن)', 'Upcoming events (7 days)'],
  'today': ['آج', 'Today'],
  'days': ['دن', 'days'],
  'birthdays': ['سالگرہ', 'Birthday'],
  'marriages': ['شادی کی سالگرہ', 'Anniversary'],
  'deaths': ['وفات کا ریکارڈ', 'Death records'],
  'no_data': ['کوئی ریکارڈ موجود نہیں', 'No records'],
  'search_hint': [
    'نام، والد، شناختی کارڈ، موبائل، شہر، ضلع، گروپ یا ID',
    'Name, father, CNIC, mobile, city, district, group or ID'
  ],
  'add_person': ['نیا فرد شامل کریں', 'Add person'],
  'edit_person': ['ترمیم', 'Edit'],
  'profile': ['پروفائل', 'Profile'],
  'save': ['محفوظ کریں', 'Save'],
  'cancel': ['منسوخ', 'Cancel'],
  'ok': ['ٹھیک ہے', 'OK'],
  'yes': ['ہاں', 'Yes'],
  'no': ['نہیں', 'No'],
  'delete': ['حذف کریں', 'Delete'],
  'restore': ['بحال کریں', 'Restore'],
  'delete_forever': ['مستقل حذف', 'Delete permanently'],
  'confirm_delete': [
    'کیا آپ یہ ریکارڈ حذف کرنا چاہتے ہیں؟ (ٹریش سے بحال ہو سکتا ہے)',
    'Delete this record? (It can be restored from Trash)'
  ],
  'confirm_purge': ['یہ ریکارڈ ہمیشہ کے لیے ختم ہو جائے گا۔ جاری رکھیں؟', 'This record will be erased forever. Continue?'],
  'saved_ok': ['محفوظ ہو گیا', 'Saved'],
  'photo': ['تصویر', 'Photo'],
  'gallery': ['گیلری', 'Gallery'],
  'camera': ['کیمرہ', 'Camera'],
  'remove': ['ہٹائیں', 'Remove'],
  'group': ['فیملی گروپ', 'Family group'],
  'choose': ['منتخب کریں', 'Choose'],
  'clear': ['صاف کریں', 'Clear'],
  'family_links': ['خاندانی روابط', 'Family links'],
  'father': ['والد', 'Father'],
  'mother': ['والدہ', 'Mother'],
  'spouse': ['شریک حیات', 'Spouse'],
  'kids': ['بچے', 'Children'],
  'documents': ['دستاویزات', 'Documents'],
  'add_document': ['دستاویز شامل کریں', 'Add document'],
  'no_docs': ['کوئی دستاویز نہیں', 'No documents'],
  'member_id': ['ممبر ID', 'Member ID'],
  'deceased_tag': ['مرحوم', 'Deceased'],
  'invalid_cnic': ['شناختی کارڈ 13 ہندسوں کا ہونا چاہیے', 'CNIC must have 13 digits'],
  'invalid_email': ['ای میل درست نہیں', 'Invalid email'],
  'age': ['عمر', 'Age'],
  'male': ['مرد', 'Male'],
  'female': ['عورت', 'Female'],
  'single': ['غیر شادی شدہ', 'Single'],
  'married': ['شادی شدہ', 'Married'],
  'widowed': ['بیوہ / رنڈوا', 'Widowed'],
  'divorced': ['مطلقہ / طلاق یافتہ', 'Divorced'],
  'reminders': ['یاددہانیاں اور تقریبات', 'Reminders & events'],
  'announcements': ['خاندانی اعلانات', 'Family announcements'],
  'trash': ['حذف شدہ ریکارڈ (ٹریش)', 'Trash'],
  'backup': ['بیک اپ اور بحالی', 'Backup & restore'],
  'export_import': ['ایکسپورٹ / امپورٹ', 'Export / Import'],
  'users': ['صارفین اور اجازتیں', 'Users & permissions'],
  'settings': ['سیٹنگز', 'Settings'],
  'add_group': ['نیا گروپ / شاخ', 'New group / branch'],
  'rename': ['نام تبدیل کریں', 'Rename'],
  'group_name': ['گروپ کا نام', 'Group name'],
  'parent_branch': ['مرکزی گروپ (شاخ کے لیے)', 'Parent group (for a branch)'],
  'main_group': ['— مرکزی گروپ —', '— Main group —'],
  'members': ['افراد', 'members'],
  'group_not_empty': [
    'اس گروپ میں افراد یا شاخیں موجود ہیں، پہلے انہیں منتقل کریں',
    'This group still has members or branches'
  ],
  'last_group': ['کم از کم ایک گروپ ضروری ہے', 'At least one group is required'],
  'add_announcement': ['نیا اعلان', 'New announcement'],
  'title': ['عنوان', 'Title'],
  'text': ['تفصیل', 'Text'],
  'no_announcements': ['کوئی اعلان نہیں', 'No announcements'],
  'create_backup': ['بیک اپ بنائیں اور شیئر کریں', 'Create backup & share'],
  'restore_backup': ['بیک اپ سے بحال کریں', 'Restore from backup'],
  'backup_pw': ['بیک اپ کا پاس ورڈ', 'Backup password'],
  'backup_hint': [
    'بیک اپ میں تمام ریکارڈ، تصاویر اور دستاویزات شامل ہوتی ہیں اور پاس ورڈ سے انکرپٹ ہوتی ہیں۔ یہ پاس ورڈ یاد رکھیں، اس کے بغیر بحالی ممکن نہیں۔',
    'The backup contains all records, photos and documents, encrypted with a password. Remember it: restore is impossible without it.'
  ],
  'restore_confirm': ['موجودہ تمام ڈیٹا بیک اپ سے بدل جائے گا۔ جاری رکھیں؟', 'All current data will be replaced. Continue?'],
  'restore_ok': ['بحالی مکمل ہوئی، دوبارہ لاگ ان کریں', 'Restore complete, please log in again'],
  'restore_fail': ['بحالی ناکام: پاس ورڈ یا فائل غلط ہے', 'Restore failed: wrong password or file'],
  'export_csv': ['CSV میں ایکسپورٹ', 'Export CSV'],
  'export_excel': ['Excel میں ایکسپورٹ', 'Export Excel'],
  'export_pdf': ['PDF میں ایکسپورٹ (انٹرنیٹ درکار)', 'Export PDF (needs internet for font)'],
  'import_data': ['CSV / Excel سے امپورٹ', 'Import from CSV / Excel'],
  'import_template': ['خالی نمونہ فائل (CSV)', 'Blank template (CSV)'],
  'import_group': ['امپورٹ شدہ افراد کس گروپ میں جائیں', 'Group for imported people'],
  'import_hint': [
    'پہلی قطار میں کالم کے نام ہوں (نمونہ فائل دیکھیں)۔ صرف مکمل نام لازمی ہے۔',
    'First row must hold column names (see the template). Only full name is required.'
  ],
  'import_done': ['افراد امپورٹ ہوئے', 'people imported'],
  'working': ['براہ کرم انتظار کریں...', 'Please wait...'],
  'add_user': ['نیا صارف', 'New user'],
  'role': ['کردار', 'Role'],
  'admin': ['ایڈمن (مکمل اختیار)', 'Admin (full access)'],
  'editor': ['ایڈیٹر (شامل/ترمیم)', 'Editor (add/edit)'],
  'viewer': ['ناظر (صرف دیکھنا)', 'Viewer (read only)'],
  'user_exists': ['یہ صارف نام پہلے سے موجود ہے', 'Username already exists'],
  'reset_password': ['نیا پاس ورڈ', 'Reset password'],
  'new_password': ['نیا پاس ورڈ', 'New password'],
  'cannot_delete_self': ['آپ اپنا اکاؤنٹ حذف نہیں کر سکتے', 'You cannot delete your own account'],
  'language': ['زبان', 'Language'],
  'dark_mode': ['ڈارک موڈ', 'Dark mode'],
  'change_password': ['میرا پاس ورڈ تبدیل کریں', 'Change my password'],
  'pw_changed': ['پاس ورڈ تبدیل ہو گیا', 'Password changed'],
  'open_profile': ['پروفائل کھولیں', 'Open profile'],
  'sensitive_hidden': ['حساس معلومات صرف ایڈمن/ایڈیٹر کو مکمل نظر آتی ہیں', 'Sensitive data is fully visible to admin/editor only'],
};
