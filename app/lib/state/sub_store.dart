import 'dart:convert';
import 'dart:io';

import '../models.dart';

/// Keeps subscriptions (metadata + downloaded body) between runs.
abstract class SubStore {
  Future<(List<Subscription>, String?)> load(); // list and active id
  Future<void> save(List<Subscription> subs, String? activeId);
  Future<String?> content(String id);
  Future<void> saveContent(String id, String content);
  Future<void> delete(String id);
}

/// `subs.json` plus `subs/<id>.conf` in the app data dir.
class FileSubStore implements SubStore {
  FileSubStore(this.dir);
  final Directory dir;

  String get _sep => Platform.pathSeparator;
  File get _index => File('${dir.path}${_sep}subs.json');
  File _body(String id) => File('${dir.path}${_sep}subs$_sep$id.conf');

  @override
  Future<(List<Subscription>, String?)> load() async {
    try {
      if (!await _index.exists()) return (<Subscription>[], null);
      final m = jsonDecode(await _index.readAsString()) as Map<String, dynamic>;
      final list = ((m['subscriptions'] as List?) ?? const [])
          .map((e) => Subscription.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      return (list, m['active'] as String?);
    } catch (_) {
      return (<Subscription>[], null);
    }
  }

  @override
  Future<void> save(List<Subscription> subs, String? activeId) async {
    await dir.create(recursive: true);
    final tmp = File('${_index.path}.tmp');
    await tmp.writeAsString(jsonEncode({'active': activeId, 'subscriptions': subs.map((s) => s.toJson()).toList()}),
        flush: true);
    await tmp.rename(_index.path);
  }

  @override
  Future<String?> content(String id) async {
    final f = _body(id);
    return await f.exists() ? f.readAsString() : null;
  }

  @override
  Future<void> saveContent(String id, String content) async {
    final f = _body(id);
    await f.parent.create(recursive: true);
    await f.writeAsString(content, flush: true);
  }

  @override
  Future<void> delete(String id) async {
    final f = _body(id);
    if (await f.exists()) await f.delete();
  }
}

class MemorySubStore implements SubStore {
  final List<Subscription> _subs = [];
  String? _active;
  final Map<String, String> _bodies = {};

  @override
  Future<(List<Subscription>, String?)> load() async => (List.of(_subs), _active);

  @override
  Future<void> save(List<Subscription> subs, String? activeId) async {
    _subs
      ..clear()
      ..addAll(subs);
    _active = activeId;
  }

  @override
  Future<String?> content(String id) async => _bodies[id];

  @override
  Future<void> saveContent(String id, String content) async => _bodies[id] = content;

  @override
  Future<void> delete(String id) async => _bodies.remove(id);
}
