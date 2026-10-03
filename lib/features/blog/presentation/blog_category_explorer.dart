import 'package:flutter/material.dart';

import '../../../data/models/blog_category_model.dart';
import '../../../data/repositories/blog_repository.dart';
import '../../home/presentation/home_widgets.dart';

class BlogCategorySelection {
  final BlogCategoryModel category;
  final BlogCategoryModel? parent;
  const BlogCategorySelection(this.category, {this.parent});
}

Future<BlogCategorySelection?> showBlogCategoryExplorer(
  BuildContext context,
  BlogRepository repository, {
  BlogCategoryModel? initialParent,
}) => showModalBottomSheet<BlogCategorySelection>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
  ),
  builder: (_) => FractionallySizedBox(
    heightFactor: .88,
    child: BlogCategoryExplorer(
      repository: repository,
      initialParent: initialParent,
    ),
  ),
);

class BlogCategoryExplorer extends StatefulWidget {
  final BlogRepository repository;
  final BlogCategoryModel? initialParent;
  final ValueChanged<BlogCategorySelection>? onSelected;
  final bool embedded;
  const BlogCategoryExplorer({
    super.key,
    required this.repository,
    this.initialParent,
    this.onSelected,
    this.embedded = false,
  });
  @override
  State<BlogCategoryExplorer> createState() => _BlogCategoryExplorerState();
}

class _BlogCategoryExplorerState extends State<BlogCategoryExplorer> {
  List<BlogCategoryModel> _roots = [];
  BlogCategoryModel? _parent;
  bool _loading = true, _error = false;
  final _scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final roots = await widget.repository.getCategories();
      if (mounted) {
        setState(() {
          _roots = roots;
          final id = widget.initialParent?.id;
          if (id != null) {
            _parent = roots.where((root) => root.id == id).firstOrNull;
          }
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = true;
          _loading = false;
        });
      }
    }
  }

  void _step(BlogCategoryModel? parent) {
    setState(() => _parent = parent);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _select(BlogCategorySelection selection) {
    if (widget.onSelected != null) {
      widget.onSelected!(selection);
    } else {
      Navigator.pop(context, selection);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = _parent?.children ?? _roots;
    return Column(
      children: [
        if (!widget.embedded)
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            decoration: BoxDecoration(
              color: homeLine,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              if (_parent != null)
                IconButton(
                  tooltip: 'Ana kategoriler',
                  onPressed: () => _step(null),
                  icon: const Icon(Icons.arrow_back),
                ),
              Expanded(
                child: Text(
                  _parent?.name ?? 'Kategori Seç',
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: homeNavy,
                  ),
                ),
              ),
              if (!widget.embedded)
                IconButton(
                  tooltip: 'Kapat',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
        ),
        const Divider(color: homeLine),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error
              ? SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const HomeMessage('Kategoriler yüklenemedi.'),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Tekrar Dene'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  key: const ValueKey('blog-category-list'),
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: categories.length + (_parent == null ? 0 : 1),
                  itemBuilder: (context, index) {
                    if (_parent != null && index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: FilledButton(
                          key: const ValueKey('blog-parent-feed'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () =>
                              _select(BlogCategorySelection(_parent!)),
                          child: const Text('Bu kategorinin tüm yazıları'),
                        ),
                      );
                    }
                    final category =
                        categories[index - (_parent == null ? 0 : 1)];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: homeLine),
                        ),
                        child: InkWell(
                          key: ValueKey('blog-select-${category.id}'),
                          onTap: () =>
                              _parent == null && category.children.isNotEmpty
                              ? _step(category)
                              : _select(
                                  BlogCategorySelection(
                                    category,
                                    parent: _parent,
                                  ),
                                ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary
                                        .withAlpha(15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _icon(category.iconKey ?? category.icon),
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                    size: 22,
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        category.name,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          height: 1.5,
                                          fontWeight: FontWeight.w600,
                                          color: homeNavy,
                                        ),
                                      ),
                                      Text(
                                        '${category.articleCount} yazı${category.children.isNotEmpty ? ' · ${category.children.length} alt konu' : ''}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          height: 1.6,
                                          color: homeMuted,
                                        ),
                                      ),
                                      if (category.description.isNotEmpty)
                                        Text(
                                          category.description,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            height: 1.6,
                                            color: homeMuted,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  size: 20,
                                  color: homeMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  IconData _icon(String? key) => switch (key) {
    'utensils' || 'soup' || '🍲' => Icons.restaurant_outlined,
    '🍷' => Icons.wine_bar_outlined,
    'cpu' || '💻' => Icons.memory_outlined,
    'heart' || '❤️' || '🩺' => Icons.favorite_border,
    '🧭' => Icons.explore_outlined,
    '🏡' => Icons.home_outlined,
    '🎓' => Icons.school_outlined,
    '💳' => Icons.credit_card_outlined,
    '🎭' => Icons.theater_comedy_outlined,
    '🏃' => Icons.directions_run_rounded,
    '👨‍👩‍👧' => Icons.family_restroom_rounded,
    '💄' => Icons.face_retouching_natural_outlined,
    '🚗' => Icons.directions_car_outlined,
    '🌿' => Icons.eco_outlined,
    '✂️' => Icons.content_cut_rounded,
    '🔬' => Icons.science_outlined,
    '🐾' => Icons.pets_outlined,
    '📈' => Icons.trending_up_rounded,
    'book' => Icons.menu_book_outlined,
    _ => Icons.category_outlined,
  };
}
