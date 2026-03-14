import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ummah_chat/stories/adam_story.dart';
import 'package:ummah_chat/stories/ayyub_story.dart';
import 'package:ummah_chat/stories/dawud_story.dart';
import 'package:ummah_chat/stories/harun_story.dart';
import 'package:ummah_chat/stories/ibrahim_story.dart';
import 'package:ummah_chat/stories/idris_story.dart';
import 'package:ummah_chat/stories/ishaq_story.dart';
import 'package:ummah_chat/stories/maryam_story.dart';
import 'package:ummah_chat/stories/muhammad_story_part_1.dart';
import 'package:ummah_chat/stories/nuh_story.dart';
import 'package:ummah_chat/stories/sulayman_story.dart';
import 'package:ummah_chat/stories/zakariya_story.dart';

import '../models/story_data.dart';
import '../services/database/database_provider.dart';
import '../services/auth/auth_service.dart';
import '../stories/alyasa_story.dart';
import '../stories/dhulkifl_story.dart';
import '../stories/hud_story.dart';
import '../stories/ilyas_story.dart';
import '../stories/isa_story.dart';
import '../stories/ismail_story.dart';
import '../stories/lut_story.dart';
import '../stories/muhammad_story_part_2.dart';
import '../stories/muhammad_story_part_3.dart';
import '../stories/muhammad_story_part_4.dart';
import '../stories/muhammad_story_part_5.dart';
import '../stories/muhammad_story_part_6.dart';
import '../stories/muhammad_story_part_7.dart';
import '../stories/salih_story.dart';
import '../stories/shuayb_story.dart';
import '../stories/yahya_story.dart';
import '../stories/yaqub_story.dart';
import 'stories_page.dart';
import '../stories/yunus_story.dart';
import '../stories/yusuf_story.dart';
import '../stories/musa_story.dart';

class SelectStoriesPage extends StatefulWidget {
  const SelectStoriesPage({super.key});

  @override
  State<SelectStoriesPage> createState() => _SelectStoriesPageState();
}

class _SelectStoriesPageState extends State<SelectStoriesPage> {
  final Color _gold = const Color(0xFFC9A74E);
  final Color _goldDeep = const Color(0xFF9F7B22);
  late final List<StoryData> _stories;

  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _stories = [
      adamStory,
      idrisStory,
      nuhStory,
      hudStory,
      salihStory,
      ibrahimStory,
      lutStory,
      ismailStory,
      ishaqStory,
      yaqubStory,
      yusufStory,
      shuaybStory,
      ayyubStory,
      dhulKiflStory,
      musaStory,
      harunStory,
      dawudStory,
      sulaymanStory,
      ilyasStory,
      alyasaStory,
      yunusStory,
      zakariyaStory,
      yahyaStory,
      maryamStory,
      isaStory,
      muhammadPart1Story,
      muhammadPart2Story,
      muhammadPart3Story,
      muhammadPart4Story,
      muhammadPart5Story,
      muhammadPart6Story,
      muhammadPart7Story,
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

  bool _isMuhammadStory(StoryData story) {
    return story.id.startsWith('muhammad_part');
  }

  bool _isFirstMuhammadStory(int index) {
    final story = _stories[index];
    if (!_isMuhammadStory(story)) return false;

    for (int i = 0; i < index; i++) {
      if (_isMuhammadStory(_stories[i])) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cs.surface,
              cs.surface,
              cs.surfaceContainerLowest,
            ],
          ),
        ),
        child: SafeArea(
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
                    physics: const ClampingScrollPhysics(),
                    itemCount: _stories.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _PremiumStoriesHeader(
                          title: 'Stories of the Prophets'.tr(),
                          subtitle: 'Choose a story to read and explore the quiz.'.tr(),
                        );
                      }

                      final story = _stories[index - 1];
                      final isCompleted = completedIds.contains(story.id);
                      final isMuhammad = _isMuhammadStory(story);
                      final isFirstMuhammad = _isFirstMuhammadStory(index - 1);

                      final card = _buildStoryCard(
                        context: context,
                        story: story,
                        isCompleted: isCompleted,
                        isMuhammad: isMuhammad,
                      );

                      if (isFirstMuhammad) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _gold.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: _gold.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Text(
                                'prophet_muhammad'.tr(),
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: _gold,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            card,
                          ],
                        );
                      }

                      return card;
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStoryCard({
    required BuildContext context,
    required StoryData story,
    required bool isCompleted,
    required bool isMuhammad,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final String subtitlePreview = (story.cardPreview ?? '');

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StoriesPage(story: story),
          ),
        );
        _loadProgress();
      },
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.surfaceContainerHigh,
              cs.surfaceContainer,
            ],
          ),
          border: Border.all(
            color: isMuhammad
                ? _gold.withValues(alpha: 0.65)
                : cs.outlineVariant.withValues(alpha: 0.55),
            width: isMuhammad ? 1.4 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 16,
              offset: const Offset(0, 6),
              color: Colors.black.withValues(alpha: 0.05),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isMuhammad
                      ? _gold.withValues(alpha: 0.12)
                      : cs.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  story.icon,
                  color: isMuhammad ? _gold : cs.primary,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      story.title.tr(),
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    if (isCompleted) ...[
                      const SizedBox(height: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isMuhammad
                              ? _gold.withValues(alpha: 0.10)
                              : Colors.green.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: isMuhammad
                                ? _gold.withValues(alpha: 0.38)
                                : Colors.green.withValues(alpha: 0.35),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: isMuhammad ? _goldDeep : Colors.green,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Completed'.tr(),
                              style: textTheme.bodySmall?.copyWith(
                                color: isMuhammad ? _goldDeep : Colors.green[800],
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (story.subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        story.subtitle!.tr(),
                        style: textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.60),
                        ),
                      ),
                    ],
                    if (subtitlePreview.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitlePreview.tr(),
                        style: textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.68),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumStoriesHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PremiumStoriesHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withValues(alpha: 0.14),
            cs.secondary.withValues(alpha: 0.55),
            cs.surfaceContainerHigh,
          ],
        ),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primary.withValues(alpha: 0.14),
            ),
            child: Icon(
              Icons.auto_stories_rounded,
              color: cs.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.72),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoBounceScrollBehavior extends ScrollBehavior {
  const _NoBounceScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }

  @override
  Widget buildOverscrollIndicator(
      BuildContext context,
      Widget child,
      ScrollableDetails details,
      ) {
    return child;
  }
}