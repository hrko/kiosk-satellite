import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'font_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: FontDemo()),
  );
}

class FontDemo extends StatefulWidget {
  const FontDemo({super.key});
  @override
  State<FontDemo> createState() => _FontDemoState();
}

class _FontDemoState extends State<FontDemo> {
  FontStore? store;
  final loaded = <String, LoadedFamily>{};
  bool busy = true;
  String status = 'Restoring saved fonts…';
  double size = 22;
  double weight = 400;
  static const defaultSample =
      'Home Assistant 12:34 — 温度 23.5°C\n'
      '日本語：鬱 鷹 警 麟 曜 醤油 / ひらがな カタカナ\n'
      '简体中文：欢迎回家　繁體中文：歡迎回家\n'
      '한국어: 안녕하세요';
  String sample = defaultSample;
  static const slots = {
    'regular': 'Regular only (one static font)',
    'static': 'Multiple weights (one font family)',
    'variable': 'Variable font (wght axis)',
  };

  @override
  void initState() {
    super.initState();
    restore();
  }

  Future<void> restore() async {
    try {
      final directory = await getApplicationSupportDirectory();
      store = FontStore(Directory('${directory.path}/imported_fonts'));
      final errors = <String>[];
      for (final slot in slots.keys) {
        try {
          final family = await store!.restore(slot);
          if (family != null) loaded[slot] = family;
        } catch (e) {
          errors.add('$slot: $e');
        }
      }
      status =
          'Restored ${loaded.length} font families from local storage at startup.'
          '${errors.isEmpty ? '' : '\nRestore errors: ${errors.join('\n')}'}';
    } catch (e) {
      status = 'Cannot open font storage: $e';
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> import(String slot) async {
    setState(() => busy = true);
    try {
      // Android providers do not always classify font MIME types correctly.
      final List<PlatformFile> result;
      if (slot == 'static') {
        result = await FilePicker.pickFiles();
      } else {
        final file = await FilePicker.pickFile();
        result = file == null ? [] : [file];
      }
      if (result.isEmpty) return;
      if (slot == 'static' && result.length < 2) {
        throw const FormatException(
          'Select at least two files, such as Regular and Bold.',
        );
      }
      final sources = result.map((file) {
        if (file.path == null) throw StateError('Cannot open ${file.name}');
        return FontSource(file.name, File(file.path!));
      }).toList();
      loaded[slot] = await store!.import(slot, sources);
      status =
          '${slots[slot]} copied and loaded.\nForce-stop and reopen the app to test persistence.';
    } catch (e) {
      status = 'Import failed: $e';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> remove(String slot) async {
    setState(() => busy = true);
    try {
      await store!.remove(slot);
      loaded.remove(slot);
      status =
          'Saved fonts removed. Loaded fonts remain in memory until the process exits.';
    } catch (e) {
      status = 'Removal failed: $e';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget specimens(String? family, {bool variable = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final w in [FontWeight.w400, FontWeight.w700]) ...[
        Text('fontWeight: ${w.value}'),
        Text(
          sample,
          style: TextStyle(fontFamily: family, fontWeight: w, fontSize: size),
        ),
        const SizedBox(height: 12),
      ],
      if (variable) ...[
        Text(
          'fontVariations: wght = ${weight.round()} (fontWeight fixed at w400)',
        ),
        Slider(
          value: weight,
          min: 100,
          max: 900,
          divisions: 800,
          label: weight.round().toString(),
          onChanged: (value) => setState(() => weight = value),
        ),
        Text(
          sample,
          style: TextStyle(
            fontFamily: family,
            fontSize: size,
            fontWeight: FontWeight.w400,
            fontVariations: [FontVariation('wght', weight)],
          ),
        ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('FontLoader Demo')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Import local TTF / OTF files. For multiple weights, select files from the same font family together.',
        ),
        const SizedBox(height: 8),
        SelectableText(status),
        if (busy) const LinearProgressIndicator(),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Sample text (leave empty for the default)',
          ),
          maxLines: 3,
          onChanged: (value) =>
              setState(() => sample = value.isEmpty ? defaultSample : value),
        ),
        Text('Font size: ${size.round()}'),
        Slider(
          value: size,
          min: 12,
          max: 48,
          divisions: 36,
          onChanged: (value) => setState(() => size = value),
        ),
        const Text('System font', style: TextStyle(fontSize: 20)),
        specimens(null),
        for (final entry in slots.entries)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.value, style: const TextStyle(fontSize: 20)),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(
                        onPressed: busy || store == null
                            ? null
                            : () => import(entry.key),
                        child: const Text('Choose files'),
                      ),
                      TextButton(
                        onPressed: busy || store == null
                            ? null
                            : () => remove(entry.key),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                  if (loaded[entry.key] case final family?) ...[
                    Text(
                      '${family.names.join('\n')}\n${(family.bytes / 1024 / 1024).toStringAsFixed(1)} MiB',
                    ),
                    const SizedBox(height: 12),
                    specimens(family.alias, variable: entry.key == 'variable'),
                  ] else
                    const Text('No font imported'),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
