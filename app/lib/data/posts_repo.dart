import '../core/supa.dart';
import '../models/post.dart';

List<Map<String, dynamic>> asRows(dynamic data) => (data as List)
    .map((e) => Map<String, dynamic>.from(e as Map))
    .toList();

Future<List<Post>> attachAuthors(List<Map<String, dynamic>> rows) async {
  if (rows.isEmpty) return [];
  final ids = rows.map((r) => r['author_id'] as String).toSet().toList();
  final profs = await supa
      .from('profiles')
      .select('id, display_name, photo_url, role, verification')
      .inFilter('id', ids);
  final byId = {
    for (final p in profs) p['id'] as String: Map<String, dynamic>.from(p)
  };
  return rows.map((r) => Post.fromMap(r, byId[r['author_id']])).toList();
}
