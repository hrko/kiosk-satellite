import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

class FontSource {
  const FontSource(this.name, this.file);
  final String name;
  final File file;
}

class LoadedFamily {
  const LoadedFamily(this.alias, this.names, this.bytes);
  final String alias;
  final List<String> names;
  final int bytes;
}

typedef FamilyLoader = Future<void> Function(String alias, List<File> files);

class FontStore {
  FontStore(this.root, {FamilyLoader? loader}) : _loader = loader ?? loadFamily;
  final Directory root;
  final FamilyLoader _loader;
  static int _generation = 0;
  static const slots = ['regular', 'static', 'variable'];

  File _manifest(String slot) {
    if (!slots.contains(slot)) throw ArgumentError.value(slot, 'slot');
    return File('${root.path}/$slot.json');
  }

  static Future<void> loadFamily(String alias, List<File> files) async {
    final loader = FontLoader(alias);
    for (final file in files) {
      loader.addFont(file.readAsBytes().then(ByteData.sublistView));
    }
    // Weight/style come from font metadata, not filenames or addFont arguments.
    await loader.load();
  }

  Future<LoadedFamily> _load(
    String slot,
    Directory dir,
    List<String> names,
  ) async {
    final files = [
      for (var i = 0; i < names.length; i++) File('${dir.path}/$i.font'),
    ];
    var bytes = 0;
    for (final file in files) {
      final handle = await file.open();
      try {
        final header = await handle.read(4);
        if (header.length != 4 ||
            (ByteData.sublistView(header).getUint32(0) != 0x00010000 &&
                ascii.decode(header, allowInvalid: true) != 'OTTO')) {
          throw const FormatException(
            'Select a standalone TTF / OTF file (TTC / WOFF are not supported).',
          );
        }
        bytes += await handle.length();
      } finally {
        await handle.close();
      }
    }
    // Unique aliases avoid mixing old and replacement faces in the engine.
    final alias =
        'Demo_${slot}_${DateTime.now().microsecondsSinceEpoch}_${_generation++}';
    await _loader(alias, files);
    return LoadedFamily(alias, names, bytes);
  }

  Future<LoadedFamily?> restore(String slot) async {
    final manifest = _manifest(slot);
    if (!await manifest.exists()) return null;
    final data =
        jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
    final directory = data['directory'] as String;
    if (!RegExp(r'^family_[a-zA-Z0-9_]+$').hasMatch(directory)) {
      throw const FormatException('Invalid storage directory');
    }
    final names = (data['names'] as List).cast<String>();
    if (names.isEmpty) throw const FormatException('The font list is empty');
    return _load(slot, Directory('${root.path}/$directory'), names);
  }

  Future<LoadedFamily> import(String slot, List<FontSource> sources) async {
    final manifest = _manifest(slot);
    if (sources.isEmpty) throw ArgumentError('No fonts selected');
    await root.create(recursive: true);
    final dir = await root.createTemp('family_');
    var committed = false;
    try {
      for (var i = 0; i < sources.length; i++) {
        await sources[i].file.copy('${dir.path}/$i.font');
      }
      final names = sources.map((source) => source.name).toList();
      final loaded = await _load(slot, dir, names);
      final pending = File('${manifest.path}.tmp');
      await pending.writeAsString(
        jsonEncode({
          'directory': dir.uri.pathSegments.where((s) => s.isNotEmpty).last,
          'names': names,
        }),
        flush: true,
      );
      // Atomic on Android: failed imports preserve the previous selection.
      await pending.rename(manifest.path);
      committed = true;
      await _collectUnused();
      return loaded;
    } finally {
      if (!committed && await dir.exists()) await dir.delete(recursive: true);
    }
  }

  Future<void> _collectUnused() async {
    // Cleanup must not turn a committed import into an error.
    try {
      final referenced = <String>{};
      for (final slot in slots) {
        final file = _manifest(slot);
        if (await file.exists()) {
          final data =
              jsonDecode(await file.readAsString()) as Map<String, dynamic>;
          referenced.add(data['directory'] as String);
        }
      }
      await for (final entry in root.list(followLinks: false)) {
        final name = entry.path.split('/').last;
        if (entry is Directory &&
            name.startsWith('family_') &&
            !referenced.contains(name)) {
          await entry.delete(recursive: true);
        }
      }
    } catch (_) {
      /* Retry after the next import/removal. */
    }
  }

  Future<void> remove(String slot) async {
    final file = _manifest(slot);
    if (await file.exists()) await file.delete();
    await _collectUnused();
  }
}
