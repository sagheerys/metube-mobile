part of 'backup_service.dart';

/// **One typed cell of the plain format**, written into the store and put
/// back on a rollback.
///
/// **A `part` file rather than its own library** (the size limit): it works
/// on the service's own `store`.
extension BackupServiceCells on BackupService {
  /// Puts a value back as it was, to roll back a restore that failed
  /// halfway.
  Future<void> _restoreRaw(String key, Object value) async {
    switch (value) {
      case String v:
        await store.setString(key, v);
      case bool v:
        await store.setBool(key, v);
      case int v:
        await store.setInt(key, v);
      case double v:
        await store.setDouble(key, v);
      case List v:
        await store.setStringList(key, [for (final e in v) e.toString()]);
      default:
        await store.remove(key);
    }
  }

  Future<bool> _applyCell(String key, dynamic cell) async {
    if (cell is! Map) return false;
    final v = cell['v'];
    switch (cell['t']) {
      // Credentials inside an address are stripped on the way in as on the
      // way out: dart:io would send `user:pass@` from one on every request.
      case 's':
        await store.setString(key, BackupAddresses.stripIfUrl(v.toString()));
      case 'b':
        await store.setBool(key, v == true);
      case 'i':
        if (v is! num) return false;
        await store.setInt(key, v.toInt());
      case 'd':
        if (v is! num) return false;
        await store.setDouble(key, v.toDouble());
      case 'l':
        if (v is! List) return false;
        await store.setStringList(key, [
          for (final e in v) BackupAddresses.stripIfUrl(e.toString()),
        ]);
      default:
        return false;
    }
    return true;
  }
}
