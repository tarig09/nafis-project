import 'package:flutter/material.dart';

import '../../core/supa.dart';
import '../../data/posts_repo.dart';
import '../../models/post.dart';
import '../../widgets/post_card.dart';
import 'search_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => FeedScreenState();
}

class FeedScreenState extends State<FeedScreen> {
  List<Post> _posts = [];
  bool _loading = true;
  String? _error;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    try {
      final data = await supa.rpc('get_feed', params: {'p_limit': 30, 'p_offset': 0});
      final posts = await attachAuthors(asRows(data));
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل المنشورات';
      });
    }
  }

  void _runSearch(String q) {
    final query = q.trim();
    if (query.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SearchScreen(query: query)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            automaticallyImplyLeading: false,
            backgroundColor: Colors.white,
            toolbarHeight: 60,
            titleSpacing: 12,
            title: SizedBox(
              height: 44,
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: _runSearch,
                decoration: InputDecoration(
                  hintText: 'ابحث: تصميم، برمجة، تسويق، مونتاج...',
                  hintStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text(_error!)),
            )
          else if (_posts.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('لا توجد منشورات بعد. كن أول من ينشر!')),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => PostCard(post: _posts[i], onDeleted: refresh),
                childCount: _posts.length,
              ),
            ),
        ],
      ),
    );
  }
}
