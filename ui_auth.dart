import 'package:flutter/material.dart';

import 'models.dart';
import 'store.dart';

Widget _langButton() => TextButton.icon(
      onPressed: () => store.setLang(appLang == 'ur' ? 'en' : 'ur'),
      icon: const Icon(Icons.language),
      label: Text(appLang == 'ur' ? 'English' : 'اردو'),
    );

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});
  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final _u = TextEditingController();
  final _p = TextEditingController();
  final _p2 = TextEditingController();
  String? _err;

  Future<void> _create() async {
    if (_u.text.trim().isEmpty) {
      setState(() => _err = tr('required'));
      return;
    }
    if (_p.text.length < 4) {
      setState(() => _err = tr('pw_short'));
      return;
    }
    if (_p.text != _p2.text) {
      setState(() => _err = tr('pw_mismatch'));
      return;
    }
    await store.addUser(_u.text, _p.text, 'admin');
    if (store.groups.isEmpty) await store.addGroup(tr('default_group'));
    store.login(_u.text, _p.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(actions: [_langButton()]),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Icon(Icons.family_restroom, size: 80),
            const SizedBox(height: 8),
            Text(tr('setup_title'), style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(tr('setup_msg'), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextField(
                controller: _u,
                decoration: InputDecoration(
                    labelText: tr('username'), border: const OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(
                controller: _p,
                obscureText: true,
                decoration: InputDecoration(
                    labelText: tr('password'), border: const OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(
                controller: _p2,
                obscureText: true,
                decoration: InputDecoration(
                    labelText: tr('confirm_password'),
                    border: const OutlineInputBorder())),
            if (_err != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_err!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _create, child: Text(tr('create_admin'))),
          ]),
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _u = TextEditingController();
  final _p = TextEditingController();
  String? _err;

  void _login() {
    if (!store.login(_u.text, _p.text)) {
      setState(() => _err = tr('wrong_login'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(actions: [_langButton()]),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Icon(Icons.family_restroom, size: 80),
            const SizedBox(height: 8),
            Text(tr('app'), style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            TextField(
                controller: _u,
                decoration: InputDecoration(
                    labelText: tr('username'), border: const OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(
                controller: _p,
                obscureText: true,
                onSubmitted: (_) => _login(),
                decoration: InputDecoration(
                    labelText: tr('password'), border: const OutlineInputBorder())),
            if (_err != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_err!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _login, child: Text(tr('login'))),
          ]),
        ),
      ),
    );
  }
}
