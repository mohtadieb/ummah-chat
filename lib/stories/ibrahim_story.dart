// lib/stories/ibrahim_story.dart
import 'package:flutter/material.dart';
import '../models/story_data.dart';
import '../pages/stories_page.dart';

const StoryData ibrahimStory = StoryData(
  id: 'ibrahim',
  appBarTitle: 'story_ibrahim.appBarTitle',
  chipLabel: 'story_ibrahim.chipLabel',
  title: 'story_ibrahim.title',
  subtitle: 'story_ibrahim.subtitle',
  icon: Icons.local_fire_department_rounded, // 🔥 fire miracle + strength
  cardPreview: 'story_ibrahim.cardPreview',
  body: 'story_ibrahim.body',
  questions: [
    QuizQuestion(
      question: 'story_ibrahim.q1.question',
      options: [
        'story_ibrahim.q1.o1',
        'story_ibrahim.q1.o2',
        'story_ibrahim.q1.o3',
        'story_ibrahim.q1.o4',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: 'story_ibrahim.q2.question',
      options: [
        'story_ibrahim.q2.o1',
        'story_ibrahim.q2.o2',
        'story_ibrahim.q2.o3',
        'story_ibrahim.q2.o4',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: 'story_ibrahim.q3.question',
      options: [
        'story_ibrahim.q3.o1',
        'story_ibrahim.q3.o2',
        'story_ibrahim.q3.o3',
        'story_ibrahim.q3.o4',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'story_ibrahim.q4.question',
      options: [
        'story_ibrahim.q4.o1',
        'story_ibrahim.q4.o2',
        'story_ibrahim.q4.o3',
        'story_ibrahim.q4.o4',
      ],
      correctIndex: 3,
    ),
    QuizQuestion(
      question: 'story_ibrahim.q5.question',
      options: [
        'story_ibrahim.q5.o1',
        'story_ibrahim.q5.o2',
        'story_ibrahim.q5.o3',
        'story_ibrahim.q5.o4',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: 'story_ibrahim.q6.question',
      options: [
        'story_ibrahim.q6.o1',
        'story_ibrahim.q6.o2',
        'story_ibrahim.q6.o3',
        'story_ibrahim.q6.o4',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'story_ibrahim.q7.question',
      options: [
        'story_ibrahim.q7.o1',
        'story_ibrahim.q7.o2',
        'story_ibrahim.q7.o3',
        'story_ibrahim.q7.o4',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: 'story_ibrahim.q8.question',
      options: [
        'story_ibrahim.q8.o1',
        'story_ibrahim.q8.o2',
        'story_ibrahim.q8.o3',
        'story_ibrahim.q8.o4',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'story_ibrahim.q9.question',
      options: [
        'story_ibrahim.q9.o1',
        'story_ibrahim.q9.o2',
        'story_ibrahim.q9.o3',
        'story_ibrahim.q9.o4',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'story_ibrahim.q10.question',
      options: [
        'story_ibrahim.q10.o1',
        'story_ibrahim.q10.o2',
        'story_ibrahim.q10.o3',
        'story_ibrahim.q10.o4',
      ],
      correctIndex: 1,
    ),
  ],
);
