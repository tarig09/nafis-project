import 'package:flutter/material.dart';

import '../../core/supa.dart';
import '../../data/posts_repo.dart';
import '../../models/post.dart';
import '../../widgets/post_card.dart';

class SearchScreen extends StatefulWidget {
  final String query;
  const SearchScreen({super.key, required this.query});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final Future<List<Post>> _future = _load();

  Future<List<Post>> _load() async {
    final data = await supa.rpc('search_posts', params: {'q': widget.query});
    return attachAuthors(asRows(data));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('نتائج: ${widget.query}')),
      body: FutureBuilder<List<Post>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return const Center(child: Text('تعذر البحث'));
          }
          final posts = snap.data ?? [];
          if (posts.isEmpty) {
            return const Center(child: Text('لا نتائج (البحث يشمل آخر 30 يوماً)'));
          }
          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (_, i) => PostCard(post: posts[i]),
          );
        },
      ),
    );
  }
}
