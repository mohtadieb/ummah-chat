// lib/models/story_data.dart
import 'package:flutter/material.dart';

class StoryData {
  final String id; // e.g. "yunus", "yusuf"
  final String appBarTitle;
  final String chipLabel;
  final String title;
  final String? subtitle;
  final String body;
  final IconData icon;
  final List<QuizQuestion> questions;
  final String? cardPreview;


  const StoryData({
    required this.id,
    required this.appBarTitle,
    required this.chipLabel,
    required this.title,
    this.subtitle,
    required this.body,
    required this.icon,
    required this.questions,
    this.cardPreview, // 🆕
  });
}

class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;

  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
  });
}
