// lib/pages/stories_page.dart
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
  final Color _accent = const Color(0xFF0F8254);

  late final List<QuizQuestion> _questions;
  late final List<int?> _selectedIndices;

  bool _initialAnswersLoaded = false;

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

    // 1️⃣ Always save answers (so they persist)
    await db.saveStoryAnswers(widget.story.id, _selectedIndices);

    // 2️⃣ Check if all questions are answered
    final allAnswered = _selectedIndices.every((i) => i != null);

    // 3️⃣ Check if all answers are correct
    final allCorrect = allAnswered &&
        List.generate(_questions.length, (i) => i).every((i) {
          final selected = _selectedIndices[i];
          if (selected == null) return false;
          return selected == _questions[i].correctIndex;
        });

    // 4️⃣ Only then mark completed (and only once)
    if (allCorrect && !db.completedStoryIds.contains(widget.story.id)) {
      await db.markStoryCompleted(widget.story.id);
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _accent,
        elevation: 0,
        title: Text(
          widget.story.appBarTitle,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _accent.withValues(alpha: 0.06),
              Colors.white,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: !_initialAnswersLoaded
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStoryCard(textTheme),
                const SizedBox(height: 24),
                Text(
                  'Quiz about the story',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _accent,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the answer you think is correct. If you are wrong, the correct answer will be highlighted for you.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _questions.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _buildQuestionCard(index, textTheme);
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStoryCard(TextTheme textTheme) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      shadowColor: _accent.withValues(alpha: 0.2),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      Icon(widget.story.icon, size: 16, color: _accent),
                      const SizedBox(width: 6),
                      Text(
                        widget.story.chipLabel,
                        style: TextStyle(
                          color: _accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Icon(Icons.auto_stories, color: Colors.grey[400], size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.story.title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.story.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.story.subtitle!,
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              widget.story.body,
              style: textTheme.bodyMedium?.copyWith(
                height: 1.4,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int questionIndex, TextTheme textTheme) {
    final question = _questions[questionIndex];
    final selectedIndex = _selectedIndices[questionIndex];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      shadowColor: _accent.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${questionIndex + 1}',
                    style: TextStyle(
                      color: _accent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    question.question,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...List.generate(question.options.length, (optionIndex) {
              return _buildOptionChip(
                questionIndex: questionIndex,
                optionIndex: optionIndex,
              );
            }),
            if (selectedIndex != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  selectedIndex == question.correctIndex
                      ? 'Well done!'
                      : 'Check the highlighted correct answer 💡',
                  style: textTheme.bodySmall?.copyWith(
                    color: selectedIndex == question.correctIndex
                        ? _accent
                        : Colors.orange[700],
                    fontStyle: FontStyle.italic,
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
    final question = _questions[questionIndex];
    final selectedIndex = _selectedIndices[questionIndex];
    final attempted = selectedIndex != null;

    final bool isCorrectOption = optionIndex == question.correctIndex;
    final bool isSelected = optionIndex == selectedIndex;
    final bool isUserCorrect = attempted && isSelected && isCorrectOption;
    final bool isUserWrong = attempted && isSelected && !isCorrectOption;

    Color borderColor = Colors.grey.withValues(alpha: 0.3);
    Color? fillColor;
    IconData? icon;
    Color? iconColor;

    if (attempted) {
      if (isCorrectOption) {
        borderColor = Colors.green;
        fillColor = Colors.green.withValues(alpha: .06);
        icon = Icons.check_circle;
        iconColor = Colors.green;
      } else if (isUserWrong) {
        borderColor = Colors.red;
        fillColor = Colors.red.withValues(alpha: .06);
        icon = Icons.cancel;
        iconColor = Colors.red;
      } else {
        borderColor = Colors.grey.withValues(alpha: 0.3);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _onOptionTap(questionIndex, optionIndex),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: fillColor ?? Theme.of(context).colorScheme.secondary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  question.options[optionIndex],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                    isCorrectOption && attempted ? FontWeight.w600 : null,
                    color: Theme.of(context).colorScheme.inversePrimary,
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
