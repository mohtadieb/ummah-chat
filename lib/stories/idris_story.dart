import 'package:flutter/material.dart';
import '../models/story_data.dart';
import 'stories_page.dart';

const StoryData idrisStory = StoryData(
  id: 'idris',
  appBarTitle: 'Prophet Idris (as)',
  chipLabel: 'Prophet Idris (as)',
  title: 'The Story of Prophet Idris (as)',
  subtitle: 'Knowledge, patience and striving for good',
  icon: Icons.self_improvement_rounded,
  cardPreview:
  'A early prophet known for his wisdom, writing, and patience, who always strove to do more good.',
  body:
  'Prophet Idris (peace be upon him) was one of the earlier prophets of Allah, living not long after Prophet Adam (as). '
      'He is mentioned in the Qur’an as being truthful, patient, and a prophet raised to a high place of honour.\n\n'
      'Idris (as) was known for his deep knowledge and love for learning. '
      'Many scholars say he was among the first to write with a pen and to teach people how to read and record knowledge. '
      'He helped his people learn useful skills so they could live better and more organised lives.\n\n'
      'But Idris (as) did not only teach worldly skills. His most important mission was to call people to worship Allah alone and to stay away from sins. '
      'He reminded people that life in this world is short, and that the real success is to meet Allah with a clean heart.\n\n'
      'Idris (as) was patient and calm. When people disobeyed or ignored his advice, he did not give up quickly. '
      'He continued to teach, remind, and pray for them, hoping they would return to the right path.\n\n'
      'He was also known for doing many good deeds and acts of worship. Some narrations mention that he always wanted to increase his good actions and draw closer to Allah. '
      'Because of his sincerity and efforts, Allah raised his status.\n\n'
      'Although we do not have as many detailed stories about Idris (as) as we do for some other prophets, '
      'the Qur’an tells us enough to know that he was a man of truth, patience, and strong faith.\n\n'
      'From the story of Idris (as), we learn the importance of seeking knowledge, using our skills for good, and being patient when others do not listen right away. '
      'We also learn that Allah values consistent good deeds and sincere effort, even if they seem small to us.',
  questions: [
    QuizQuestion(
      question: 'When did Prophet Idris (as) live?',
      options: [
        'After Prophet Muhammad (saw)',
        'Around the time of Musa (as)',
        'Not long after Prophet Adam (as)',
        'Only in our time',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'What was Prophet Idris (as) especially known for?',
      options: [
        'Writing and knowledge',
        'Building ships',
        'Cooking',
        'Farming only',
      ],
      correctIndex: 0,
    ),
    QuizQuestion(
      question:
      'What did Idris (as) teach people besides worldly skills?',
      options: [
        'How to worship stars',
        'How to forget Allah',
        'To worship Allah alone and avoid sins',
        'How to travel far',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'How did Idris (as) react when people did not listen?',
      options: [
        'He shouted and stopped teaching',
        'He gave up after one try',
        'He stayed patient and continued reminding them',
        'He left them forever',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'What kind of deeds did Idris (as) love to do?',
      options: [
        'Bad deeds',
        'Useless actions',
        'Good deeds and acts of worship',
        'Showing off to people',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'How does the Qur’an describe Idris (as)?',
      options: [
        'As a king of a large land',
        'As a man of truth and patience',
        'As a warrior',
        'As a traveller',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
      'What is one lesson from the story of Idris (as)?',
      options: [
        'Knowledge is not important',
        'We should seek knowledge and use it for good',
        'Only rich people need knowledge',
        'We should stop teaching if people ignore us',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
      'Why is patience important when we call others to good?',
      options: [
        'People change quickly',
        'People never change',
        'Some people need time and many reminders',
        'It is not our job to remind',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'What does Allah do with sincere good deeds, even if small?',
      options: [
        'Ignores them',
        'Only accepts the big ones',
        'Values them and raises a person’s rank',
        'Forgets them',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'What is a good way to follow the example of Idris (as)?',
      options: [
        'Stop going to school',
        'Learn and teach good things, and stay patient',
        'Only think about games',
        'Hide our knowledge from others',
      ],
      correctIndex: 1,
    ),
  ],
);
