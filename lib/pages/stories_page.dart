import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/story_data.dart';
import '../services/database/database_provider.dart';

class StoriesPage extends StatefulWidget {
  final StoryData story;

  const StoriesPage({super.key, required this.story});

  @override
  State<StoriesPage> createState() => _StoriesPageState();
}

class _StoriesPageState extends State<StoriesPage> {
  late final List<QuizQuestion> _questions;
  late final List<int?> _selectedIndices;

  bool _initialAnswersLoaded = false;
  bool _celebrationShown = false;

  static const Color _gold = Color(0xFFC9A74E);
  static const Color _goldDeep = Color(0xFF9F7B22);

  bool _isMuhammadStory() {
    return widget.story.id.startsWith('muhammad_part');
  }

  @override
  void initState() {
    super.initState();
    _questions = widget.story.questions;
    _selectedIndices = List<int?>.filled(_questions.length, null);
    _loadSavedAnswers();
  }

  Future<void> _loadSavedAnswers() async {
    final db = Provider.of<DatabaseProvider>(context, listen: false);
    final saved = await db.getStoryAnswers(widget.story.id);

    if (!mounted) return;

    setState(() {
      saved.forEach((questionIndex, optionIndex) {
        if (questionIndex >= 0 && questionIndex < _selectedIndices.length) {
          _selectedIndices[questionIndex] = optionIndex;
        }
      });
      _initialAnswersLoaded = true;
    });
  }

  Future<void> _onOptionTap(int questionIndex, int optionIndex) async {
    setState(() {
      _selectedIndices[questionIndex] = optionIndex;
    });

    final db = Provider.of<DatabaseProvider>(context, listen: false);
    final bool wasAlreadyCompleted = db.completedStoryIds.contains(widget.story.id);

    await db.saveStoryAnswers(widget.story.id, _selectedIndices);

    final allAnswered = _selectedIndices.every((i) => i != null);

    final allCorrect =
        allAnswered &&
            List.generate(_questions.length, (i) => i).every((i) {
              final selected = _selectedIndices[i];
              if (selected == null) return false;
              return selected == _questions[i].correctIndex;
            });

    if (allCorrect && !wasAlreadyCompleted) {
      await db.markStoryCompleted(widget.story.id);

      if (mounted && !_celebrationShown) {
        _celebrationShown = true;
        await _showCompletionCelebration();
      }
    }
  }

  Future<void> _showCompletionCelebration() async {
    if (!mounted) return;

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isMuhammad = _isMuhammadStory();

    final accent = isMuhammad ? _gold : cs.primary;
    final accentDeep = isMuhammad ? _goldDeep : cs.primary;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: accent.withValues(alpha: 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.20),
                  blurRadius: 28,
                  offset: const Offset(0, 16),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.14),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.30),
                        width: 1.4,
                      ),
                    ),
                    child: Icon(
                      widget.story.icon,
                      size: 36,
                      color: accentDeep,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '🎉 ${'Well done!'.tr()}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: accentDeep,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'You earned a new badge!'.tr(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.20),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Badge unlocked'.tr(),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: accentDeep,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.story.title.tr(),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface,
                          ),
                        ),
                        if (widget.story.subtitle != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            widget.story.subtitle!.tr(),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.64),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: accentDeep,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.check_rounded),
                      label: Text(
                        'Continue'.tr(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  int get _answeredCount => _selectedIndices.where((i) => i != null).length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isMuhammad = _isMuhammadStory();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isMuhammad
                ? [
              cs.surface,
              _gold.withValues(alpha: 0.03),
              cs.surfaceContainerLowest,
            ]
                : [
              cs.surface,
              cs.surface,
              cs.surfaceContainerLowest,
            ],
          ),
        ),
        child: SafeArea(
          child: !_initialAnswersLoaded
              ? const Center(child: CircularProgressIndicator())
              : Column(
            children: [
              // FIXED BACK BUTTON
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildTopBackButton(context),
                ),
              ),

              const SizedBox(height: 8),

              // SCROLLABLE CONTENT
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      _buildStoryHero(textTheme, cs),
                      const SizedBox(height: 14),
                      _buildStoryCard(textTheme, cs),
                      const SizedBox(height: 18),
                      _buildProgressStrip(cs, textTheme),
                      const SizedBox(height: 22),
                      Text(
                        'Quiz about the story'.tr(),
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isMuhammad ? _goldDeep : cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the answer you think is correct. If you are wrong, the correct answer will be highlighted for you.'
                            .tr(),
                        style: textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.68),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _questions.length,
                        separatorBuilder: (_, __) =>
                        const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          return _buildQuestionCard(index, textTheme, cs);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBackButton(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isMuhammad = _isMuhammadStory();

    return InkWell(
      onTap: () => Navigator.of(context).pop(),
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          Icons.arrow_back_rounded,
          color: isMuhammad ? _goldDeep : cs.onSurface,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildStoryHero(TextTheme textTheme, ColorScheme cs) {
    final isMuhammad = _isMuhammadStory();

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isMuhammad
              ? [
            _gold.withValues(alpha: 0.18),
            _gold.withValues(alpha: 0.10),
            cs.surfaceContainerHigh,
          ]
              : [
            cs.primary.withValues(alpha: 0.14),
            cs.secondary.withValues(alpha: 0.55),
            cs.surfaceContainerHigh,
          ],
        ),
        border: Border.all(
          color: isMuhammad
              ? _gold.withValues(alpha: 0.55)
              : cs.outlineVariant.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: isMuhammad
                ? _gold.withValues(alpha: 0.16)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isMuhammad
                  ? _gold.withValues(alpha: 0.16)
                  : cs.primary.withValues(alpha: 0.14),
              border: isMuhammad
                  ? Border.all(color: _gold.withValues(alpha: 0.32))
                  : null,
            ),
            child: Icon(
              widget.story.icon,
              color: isMuhammad ? _goldDeep : cs.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                widget.story.appBarTitle.tr(),
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: isMuhammad ? _goldDeep : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryCard(TextTheme textTheme, ColorScheme cs) {
    final isMuhammad = _isMuhammadStory();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
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
              ? _gold.withValues(alpha: 0.60)
              : cs.outlineVariant.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: isMuhammad
                ? _gold.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isMuhammad
                        ? _gold.withValues(alpha: 0.12)
                        : cs.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: isMuhammad
                        ? Border.all(
                      color: _gold.withValues(alpha: 0.30),
                      width: 0.8,
                    )
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.story.icon,
                        size: 16,
                        color: isMuhammad ? _goldDeep : cs.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.story.chipLabel.tr(),
                        style: TextStyle(
                          color: isMuhammad ? _goldDeep : cs.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.auto_stories_rounded,
                  color: isMuhammad
                      ? _gold.withValues(alpha: 0.70)
                      : cs.onSurface.withValues(alpha: 0.28),
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              widget.story.title.tr(),
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
            if (widget.story.subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                widget.story.subtitle!.tr(),
                style: textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.58),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              widget.story.body.tr(),
              style: textTheme.bodyMedium?.copyWith(
                height: 1.55,
                color: cs.onSurface.withValues(alpha: 0.82),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressStrip(ColorScheme cs, TextTheme textTheme) {
    final progress =
    _questions.isEmpty ? 0.0 : _answeredCount / _questions.length;
    final isMuhammad = _isMuhammadStory();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMuhammad
              ? _gold.withValues(alpha: 0.35)
              : cs.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_answeredCount}/${_questions.length} ${'answered'.tr()}',
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: isMuhammad ? _goldDeep : cs.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress.clamp(0.0, 1.0),
              backgroundColor: isMuhammad
                  ? _gold.withValues(alpha: 0.16)
                  : cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(
                isMuhammad ? _gold : cs.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(
      int questionIndex,
      TextTheme textTheme,
      ColorScheme cs,
      ) {
    final question = _questions[questionIndex];
    final selectedIndex = _selectedIndices[questionIndex];
    final isMuhammad = _isMuhammadStory();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.surfaceContainerHigh,
            cs.surfaceContainer,
          ],
        ),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isMuhammad
                        ? _gold.withValues(alpha: 0.14)
                        : cs.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: isMuhammad
                        ? Border.all(
                      color: _gold.withValues(alpha: 0.30),
                      width: 0.8,
                    )
                        : null,
                  ),
                  child: Text(
                    '${questionIndex + 1}',
                    style: TextStyle(
                      color: isMuhammad ? _goldDeep : cs.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    question.question.tr(),
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(question.options.length, (optionIndex) {
              return _buildOptionChip(
                questionIndex: questionIndex,
                optionIndex: optionIndex,
              );
            }),
            if (selectedIndex != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  selectedIndex == question.correctIndex
                      ? 'Well done!'.tr()
                      : 'Check the highlighted correct answer 💡'.tr(),
                  style: textTheme.bodySmall?.copyWith(
                    color: selectedIndex == question.correctIndex
                        ? (isMuhammad ? _goldDeep : cs.primary)
                        : Colors.orange[700],
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOptionChip({
    required int questionIndex,
    required int optionIndex,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isMuhammad = _isMuhammadStory();

    final question = _questions[questionIndex];
    final selectedIndex = _selectedIndices[questionIndex];
    final attempted = selectedIndex != null;

    final bool isCorrectOption = optionIndex == question.correctIndex;
    final bool isSelected = optionIndex == selectedIndex;
    final bool isUserWrong = attempted && isSelected && !isCorrectOption;

    Color borderColor = cs.outlineVariant;
    Color fillColor = cs.surfaceContainerHighest.withValues(alpha: 0.85);
    IconData? icon;
    Color? iconColor;
    FontWeight weight = FontWeight.w600;

    if (attempted) {
      if (isCorrectOption) {
        borderColor = Colors.green;
        fillColor = Colors.green.withValues(alpha: 0.08);
        icon = Icons.check_circle;
        iconColor = Colors.green;
        weight = FontWeight.w700;
      } else if (isUserWrong) {
        borderColor = Colors.red;
        fillColor = Colors.red.withValues(alpha: 0.08);
        icon = Icons.cancel;
        iconColor = Colors.red;
      }
    } else if (isSelected) {
      borderColor = isMuhammad
          ? _gold.withValues(alpha: 0.55)
          : cs.primary.withValues(alpha: 0.40);
      fillColor = isMuhammad
          ? _gold.withValues(alpha: 0.12)
          : cs.primary.withValues(alpha: 0.06);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _onOptionTap(questionIndex, optionIndex),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.15),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  question.options[optionIndex].tr(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: weight,
                    color: cs.onSurface,
                    height: 1.35,
                  ),
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 8),
                Icon(
                  icon,
                  size: 20,
                  color: iconColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}