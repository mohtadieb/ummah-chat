// lib/pages/select_stories_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ummah_chat/stories/ibrahim_story.dart';
import 'package:ummah_chat/stories/nuh_story.dart';
import 'package:ummah_chat/stories/sulayman_story.dart';

import '../models/storyData.dart';
import '../services/database/database_provider.dart';
import '../services/auth/auth_service.dart';
import 'stories_page.dart';
import 'yunus_story.dart';
import 'yusuf_story.dart';
import 'musa_story.dart';

class SelectStoriesPage extends StatefulWidget {
  const SelectStoriesPage({super.key});

  @override
  State<SelectStoriesPage> createState() => _SelectStoriesPageState();
}

class _SelectStoriesPageState extends State<SelectStoriesPage> {
  final Color _accent = const Color(0xFF0F8254);
  late final List<StoryData> _stories;

  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _stories = [
      yunusStory,
      yusufStory,
      musaStory,
      ibrahimStory,
      nuhStory,
      sulaymanStory,
    ];

    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final db = Provider.of<DatabaseProvider>(context, listen: false);
    final currentUserId = AuthService().getCurrentUserId();
    await db.loadCompletedStories(currentUserId);
    if (mounted) {
      setState(() {
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,

      // 🌿 Fixed header so cards never scroll "under" it
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0, // 🔥 prevents color change on scroll
        surfaceTintColor: Colors.transparent, // 🔥 prevents M3 overlay tint
        backgroundColor: colorScheme.surface,
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Stories of the Prophets',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: _accent,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose a story to read and explore the quiz.',
              style: textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),

      body: SafeArea(
        // top: false to avoid extra gap under the AppBar
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Consumer<DatabaseProvider>(
            builder: (context, db, _) {
              final completedIds = db.completedStoryIds;

              if (!_loaded) {
                return const Center(child: CircularProgressIndicator());
              }

              return ScrollConfiguration(
                behavior: const _NoBounceScrollBehavior(),
                child: ListView.separated(
                  physics: const ClampingScrollPhysics(), // ✅ no stretch / weird movement
                  itemCount: _stories.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final story = _stories[index];
                    final isCompleted = completedIds.contains(story.id);

                    return _buildStoryCard(
                      context: context,
                      story: story,
                      isCompleted: isCompleted,
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStoryCard({
    required BuildContext context,
    required StoryData story,
    required bool isCompleted,
  }) {
    final textTheme = Theme.of(context).textTheme;

    final String subtitlePreview = story.cardPreview ?? '';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StoriesPage(story: story),
          ),
        );
        // Reload progress when coming back
        _loadProgress();
      },
      child: Ink(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              blurRadius: 12,
              offset: const Offset(0, 4),
              color: Colors.black.withValues(alpha: 0.05),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(story.icon, color: _accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      story.title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    if (isCompleted) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.6),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Completed',
                              style: textTheme.bodySmall?.copyWith(
                                color: Colors.green[800],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (story.subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        story.subtitle!,
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      subtitlePreview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

// 🔒 Custom scroll behavior: no bounce, no stretch, no glow
class _NoBounceScrollBehavior extends ScrollBehavior {
  const _NoBounceScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // Force non-bouncy, non-stretch physics
    return const ClampingScrollPhysics();
  }

  @override
  Widget buildOverscrollIndicator(
      BuildContext context,
      Widget child,
      ScrollableDetails details,
      ) {
    // Remove iOS / Material3 stretch / glow visuals
    return child;
  }
}
