import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/post.dart';
import '../models/private_reflection.dart';
import '../services/database/database_provider.dart';
import '../components/my_post_tile.dart';
import '../components/my_confirmation_box.dart'; // ✅ ADD THIS (adjust path if needed)

// ✅ Quran service
import '../services/quran/quran_service.dart';

class SavedPage extends StatefulWidget {
  const SavedPage({super.key});

  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  bool _loading = true;

  // 0 = posts, 1 = ayat, 2 = reflections
  int _segment = 0;

  // posts
  List<Post> _savedPosts = [];

  // ayat
  final QuranService _quran = QuranService();
  List<Map<String, dynamic>> _savedAyat = []; // {surah, ayah, arabic, translation, ...}
  List<String> _savedAyahKeys = []; // ["2:255","1:1"]

  // reflections
  List<PrivateReflection> _savedReflections = [];

  // ✅ NEW: reload ayat when user changes app language
  String? _lastLang;

  // ✅ NEW: used to force rebuild of MyPostTile when user cancels unbookmark
  final Map<String, int> _postTileNonce = {};

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final lang = context.locale.languageCode;

    // ✅ Only reload if language changed
    if (_lastLang != lang) {
      _lastLang = lang;

      // Ayat tab depends on lang (translation)
      if (_segment == 1) {
        _loadSavedAyat();
      }
    }
  }

  Future<void> _loadCurrent() async {
    if (_segment == 0) {
      await _loadSavedPosts();
    } else if (_segment == 1) {
      await _loadSavedAyat();
    } else {
      await _loadSavedReflections();
    }
  }

  Future<void> _loadSavedPosts() async {
    final db = Provider.of<DatabaseProvider>(context, listen: false);
    setState(() => _loading = true);

    try {
      await db.loadBookmarks();

      // ✅ posts only
      final ids = db.bookmarkedPostIds.toList();

      final posts = <Post>[];
      for (final id in ids) {
        final p = await db.getPostById(id);
        if (p != null) posts.add(p);
      }

      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (!mounted) return;
      setState(() => _savedPosts = posts);
    } catch (e) {
      debugPrint('Error loading saved posts: $e');
      if (!mounted) return;
      setState(() => _savedPosts = []);
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadSavedAyat() async {
    final db = Provider.of<DatabaseProvider>(context, listen: false);
    setState(() => _loading = true);

    // ✅ NEW: pass selected app language to QuranService
    final lang = context.locale.languageCode;

    try {
      await db.loadBookmarks();

      // ✅ ayah keys like "2:255"
      final keys = db.bookmarkedAyahKeys.toList();

      final ayat = <Map<String, dynamic>>[];
      for (final k in keys) {
        try {
          // ✅ IMPORTANT: pass langCode so translation matches app language
          final a = await _quran.fetchAyahByKey(k, langCode: lang);
          ayat.add(a);
        } catch (e) {
          debugPrint('Failed fetching ayah $k: $e');
        }
      }

      // sort by surah then ayah
      ayat.sort((a, b) {
        final sa = (a['surah'] as num?)?.toInt() ?? 0;
        final sb = (b['surah'] as num?)?.toInt() ?? 0;
        if (sa != sb) return sa.compareTo(sb);
        final aa = (a['ayah'] as num?)?.toInt() ?? 0;
        final ab = (b['ayah'] as num?)?.toInt() ?? 0;
        return aa.compareTo(ab);
      });

      if (!mounted) return;
      setState(() {
        _savedAyahKeys = keys;
        _savedAyat = ayat;
      });
    } catch (e) {
      debugPrint('Error loading saved ayat: $e');
      if (!mounted) return;
      setState(() {
        _savedAyahKeys = [];
        _savedAyat = [];
      });
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadSavedReflections() async {
    final db = Provider.of<DatabaseProvider>(context, listen: false);
    setState(() => _loading = true);

    try {
      await db.loadPrivateReflections();

      // newest first (if your model has createdAt)
      final list = List<PrivateReflection>.from(db.privateReflections);
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (!mounted) return;
      setState(() => _savedReflections = list);
    } catch (e) {
      debugPrint('Error loading saved reflections: $e');
      if (!mounted) return;
      setState(() => _savedReflections = []);
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _ayahKeyFrom(Map<String, dynamic> a) {
    final surah = (a['surah'] as num?)?.toInt() ?? 0;
    final ayah = (a['ayah'] as num?)?.toInt() ?? 0;
    return '$surah:$ayah';
  }

  String _compact(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  // ✅ NEW: generic confirm dialog returning true/false
  Future<bool> _confirmRemoveBookmark() async {
    final res = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text('remove_bookmark'.tr()),
        content: Text('remove_bookmark_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('remove'.tr()),
          ),
        ],
      ),
    );
    return res == true;
  }

  void _bumpPostTileNonce(String postId) {
    final current = _postTileNonce[postId] ?? 0;
    _postTileNonce[postId] = current + 1;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text("Saved".tr()),
      ),
      body: Column(
        children: [
          // ✅ Toggle: Posts / Ayat / Reflections
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // 3 equal segments across full width
                  final segmentWidth = constraints.maxWidth / 3;

                  Widget segLabel(String key) => SizedBox(
                    width: segmentWidth,
                    child: Center(
                      child: Text(
                        key.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );

                  return SegmentedButton<int>(
                    segments: [
                      ButtonSegment(value: 0, label: segLabel('saved_posts')),
                      ButtonSegment(value: 1, label: segLabel('saved_ayat')),
                      ButtonSegment(
                          value: 2, label: segLabel('saved_reflections')),
                    ],
                    selected: {_segment},
                    onSelectionChanged: (s) async {
                      final v = s.first;
                      if (v == _segment) return;
                      setState(() => _segment = v);
                      await _loadCurrent();
                    },
                    // Optional: keep height consistent too
                    style: ButtonStyle(
                      minimumSize:
                      WidgetStateProperty.all(const Size.fromHeight(40)),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadCurrent,
              child: _loading
                  ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator()),
                ],
              )
                  : (_segment == 0)
                  ? _buildPostsView(theme)
                  : (_segment == 1)
                  ? _buildAyatView(theme)
                  : _buildReflectionsView(theme),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- POSTS TAB ----------------

  Widget _buildPostsView(ThemeData theme) {
    if (_savedPosts.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 60),
          Icon(
            Icons.bookmark_border,
            size: 60,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              "No saved posts yet".tr(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(height: 60),
        ],
      );
    }

    final db = Provider.of<DatabaseProvider>(context, listen: false);

    return ListView.builder(
      itemCount: _savedPosts.length,
      itemBuilder: (context, index) {
        final post = _savedPosts[index];
        final nonce = _postTileNonce[post.id] ?? 0;

        return MyPostTile(
          key: ValueKey('saved_post_${post.id}_$nonce'), // ✅ forces rebuild on cancel
          post: post,
          scaffoldContext: context,
          onPostTap: () {},
          onUserTap: () {},
          onBookmarkChanged: (isSaved) async {
            // MyPostTile already toggled. We confirm only when user is removing.
            if (!isSaved) {
              final confirm = await _confirmRemoveBookmark();
              if (!mounted) return;

              if (confirm) {
                // ✅ keep removed (tile already toggled DB)
                setState(() {
                  _savedPosts.removeWhere((p) => p.id == post.id);
                });
              } else {
                // ✅ revert: re-bookmark in DB + rebuild tile to reset optimistic state
                await db.toggleBookmark(itemType: 'post', itemId: post.id);
                if (!mounted) return;
                setState(() {
                  _bumpPostTileNonce(post.id);
                });
              }
            }
          },
        );
      },
    );
  }

  // ---------------- AYAT TAB ----------------

  Widget _buildAyatView(ThemeData theme) {
    if (_savedAyat.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 60),
          Icon(
            Icons.menu_book_outlined,
            size: 60,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              "no_saved_ayat_yet".tr(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(height: 60),
        ],
      );
    }

    final db = Provider.of<DatabaseProvider>(context);

    return ListView.builder(
      itemCount: _savedAyat.length,
      itemBuilder: (context, index) {
        final a = _savedAyat[index];
        final key = _ayahKeyFrom(a);

        final arabic = _compact((a['arabic'] ?? '').toString());
        final translation =
        _compact((a['translation'] ?? a['translation_en'] ?? '').toString());
        final preview = translation.isNotEmpty ? translation : arabic;

        final isSaved = db.isAyahBookmarkedByCurrentUser(key);

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_stories_outlined,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${'daily_ayah_title'.tr()} ($key)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: isSaved ? 'saved'.tr() : 'save'.tr(),
                    onPressed: () async {
                      // ✅ confirm only when removing
                      if (isSaved) {
                        final confirm = await _confirmRemoveBookmark();
                        if (!mounted) return;
                        if (!confirm) return;
                      }

                      await db.toggleBookmark(itemType: 'ayah', itemId: key);
                      if (!mounted) return;

                      // remove immediately if unsaved
                      final stillSaved = db.isAyahBookmarkedByCurrentUser(key);
                      if (!stillSaved) {
                        setState(() {
                          _savedAyat.removeWhere((x) => _ayahKeyFrom(x) == key);
                          _savedAyahKeys.removeWhere((k) => k == key);
                        });
                      }
                    },
                    icon: Icon(
                      isSaved ? Icons.bookmark : Icons.bookmark_border,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                preview,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  height: 1.25,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------- REFLECTIONS TAB ----------------

  Widget _buildReflectionsView(ThemeData theme) {
    if (_savedReflections.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 60),
          Icon(
            Icons.lock_outline_rounded,
            size: 60,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'no_private_reflections_yet'.tr(), // ✅ use this key
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(height: 60),
        ],
      );
    }

    final db = Provider.of<DatabaseProvider>(context);

    return ListView.builder(
      itemCount: _savedReflections.length,
      itemBuilder: (context, index) {
        final r = _savedReflections[index];

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final postId = r.postId;

            if (postId == null || postId.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('post_no_longer_available'.tr())),
              );
              return;
            }

            // Fetch the post that this reflection belongs to
            final post = await db.getPostById(postId);

            if (!context.mounted) return;

            if (post == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('post_no_longer_available'.tr())),
              );
              return;
            }

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _PostFromReflectionPage(post: post),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'private_reflection'.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'delete'.tr(),
                      onPressed: () async {
                        showDialog(
                          context: context,
                          builder: (_) => MyConfirmationBox(
                            title: 'delete'.tr(),
                            content: 'delete_private_reflection_confirm'.tr(),
                            confirmText: 'delete'.tr(),
                            onConfirm: () async {
                              await db.deletePrivateReflection(r.id);
                              if (!mounted) return;
                              setState(() {
                                _savedReflections
                                    .removeWhere((x) => x.id == r.id);
                              });
                            },
                          ),
                        );
                      },
                      icon: Icon(Icons.delete_outline,
                          color: theme.colorScheme.error),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  r.text,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                ),

                // ✅ Optional: little hint it's tappable
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.open_in_new_rounded,
                        size: 16,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.55)),
                    const SizedBox(width: 6),
                    Text(
                      'open_post'.tr(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PostFromReflectionPage extends StatelessWidget {
  final Post post;

  const _PostFromReflectionPage({required this.post});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Post'.tr()),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          MyPostTile(
            post: post,
            scaffoldContext: context,
            onPostTap: () {}, // already on the post screen
            onUserTap: () {}, // optional: navigate to profile if you want
            onBookmarkChanged: (_) {},
          ),
          const SizedBox(height: 24),
          Divider(
            height: 1,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
