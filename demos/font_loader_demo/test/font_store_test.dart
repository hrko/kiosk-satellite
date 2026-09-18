import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_loader_demo/font_store.dart';

void main() {
  late Directory temp;
  late Directory root;
  late File source;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('font_store_test_');
    root = Directory('${temp.path}/store');
    source = await File(
      '${temp.path}/source.ttf',
    ).writeAsBytes([0, 1, 0, 0, 42]);
  });
  tearDown(() => temp.delete(recursive: true));

  test('new store restores copied bytes after original is deleted', () async {
    final calls = <List<List<int>>>[];
    Future<void> loader(String alias, List<File> files) async {
      calls.add(await Future.wait(files.map((f) => f.readAsBytes())));
    }

    final first = FontStore(root, loader: loader);
    await first.import('static', [
      FontSource('Regular.ttf', source),
      FontSource('Bold.ttf', source),
    ]);
    await source.delete();
    final restored = await FontStore(root, loader: loader).restore('static');
    expect(restored!.names, ['Regular.ttf', 'Bold.ttf']);
    expect(restored.bytes, 10);
    expect(calls.last, calls.first);
    expect(calls.last.length, 2);
    await first.remove('static');
    expect(await first.restore('static'), isNull);
    expect(await root.list().where((e) => e is Directory).length, 0);
  });

  test('failed replacement keeps previous persisted family', () async {
    final store = FontStore(root, loader: (_, _) async {});
    await store.import('regular', [FontSource('Old.ttf', source)]);
    final failing = FontStore(
      root,
      loader: (_, _) async => throw StateError('load failed'),
    );
    await expectLater(
      failing.import('regular', [FontSource('New.ttf', source)]),
      throwsStateError,
    );
    expect((await store.restore('regular'))!.names, ['Old.ttf']);
    await source.writeAsString('not a font');
    await expectLater(
      store.import('regular', [FontSource('bad.ttf', source)]),
      throwsFormatException,
    );
    expect((await store.restore('regular'))!.names, ['Old.ttf']);
    expect(await root.list().where((e) => e is Directory).length, 1);
  });
}
