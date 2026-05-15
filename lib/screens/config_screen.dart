import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'streaming_screen.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  static const _keyName = 'last_camera_name';
  static const _keyUrl = 'last_rtmp_url';

  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _nameController.text = prefs.getString(_keyName) ?? '';
      _urlController.text = prefs.getString(_keyUrl) ?? '';
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, _nameController.text.trim());
    await prefs.setString(_keyUrl, _urlController.text.trim());
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => StreamingScreen(
          rtmpBaseUrl: _urlController.text.trim(),
          cameraName: _nameController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/svg/logo-visor.svg',
                    width: 120,
                    height: 120,
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _nameController,
                    style: TextStyle(color: scheme.onSurface),
                    decoration: const InputDecoration(
                      labelText: 'Nome da câmera',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Preencha o nome';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _urlController,
                    style: TextStyle(color: scheme.onSurface),
                    decoration: const InputDecoration(
                      labelText: 'URL RTMP',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Preencha a URL';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _start,
                      child: const Text('Iniciar Stream'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
