import 'package:flutter/material.dart';

class PostImages extends StatelessWidget {
  final List<String> urls;
  const PostImages({super.key, required this.urls});

  Widget _tile(BuildContext context, int i, {double? height}) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ImageViewer(urls: urls, index: i)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          urls[i],
          fit: BoxFit.cover,
          width: double.infinity,
          height: height,
          errorBuilder: (context, error, stack) => Container(
            height: height,
            color: const Color(0xFFF3F4F6),
            child: const Center(child: Icon(Icons.broken_image_outlined)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    if (urls.length == 1) return _tile(context, 0, height: 220);
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      childAspectRatio: 1.2,
      children: List.generate(urls.length, (i) => _tile(context, i)),
    );
  }
}

class ImageViewer extends StatelessWidget {
  final List<String> urls;
  final int index;
  const ImageViewer({super.key, required this.urls, required this.index});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: PageView.builder(
        controller: PageController(initialPage: index),
        itemCount: urls.length,
        itemBuilder: (context, i) => InteractiveViewer(
          child: Center(child: Image.network(urls[i], fit: BoxFit.contain)),
        ),
      ),
    );
  }
}
