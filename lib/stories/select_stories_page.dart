// lib/pages/select_stories_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/story_models.dart';
import '../services/database/database_provider.dart';
import '../services/auth/auth_service.dart';
import 'stories_page.dart';
import 'yunus_story.dart';
import 'yusuf_story.dart';
import 'musa_story.dart'; // 🆕 NEW

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
      musaStory, // 🆕 added
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Consumer<DatabaseProvider>(
            builder: (context, db, _) {
              final completedIds = db.completedStoryIds;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stories of the Prophets',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose a story to read and explore the quiz.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: !_loaded
                        ? const Center(
                      child: CircularProgressIndicator(),
                    )
                        : ListView.separated(
                      itemCount: _stories.length,
                      separatorBuilder: (_, __) =>
                      const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final story = _stories[index];
                        final isCompleted =
                        completedIds.contains(story.id);

                        return _buildStoryCard(
                          context: context,
                          story: story,
                          isCompleted: isCompleted,
                        );
                      },
                    ),
                  ),
                ],
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

    String subtitlePreview;
    if (story.id == 'yunus') {
      subtitlePreview =
      'The prophet who called his people by the sea and was swallowed by the great fish.';
    } else if (story.id == 'yusuf') {
      subtitlePreview =
      'The prophet known for his patience, a dream, and a journey from a well to a throne.';
    } else if (story.id == 'musa') {
      subtitlePreview =
      'The prophet who faced Pharaoh, parted the sea, and led his people with courage.';
    } else {
      subtitlePreview = '';
    }

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
          color: Theme.of(context).colorScheme.tertiary,
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            story.title,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isCompleted) ...[
                          const SizedBox(width: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                size: 18,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Done',
                                style: textTheme.bodySmall?.copyWith(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    if (story.subtitle != null) ...[
                      const SizedBox(height: 2),
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
