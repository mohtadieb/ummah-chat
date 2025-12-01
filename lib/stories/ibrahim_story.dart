// lib/pages/ibrahim_story.dart  (or lib/stories/ibrahim_story.dart)
import 'package:flutter/material.dart';
import '../models/story_data.dart';
import 'stories_page.dart';

const StoryData ibrahimStory = StoryData(
  id: 'ibrahim',
  appBarTitle: 'Prophet Ibrahim (as)',
  chipLabel: 'Prophet Ibrahim (as)',
  title: 'The Story of Prophet Ibrahim (as)',
  subtitle: 'His unwavering faith and the test of sacrifice',
  icon: Icons.local_fire_department_rounded, // 🔥 symbolizes the fire miracle
  cardPreview: 'The prophet who stood against idolatry, survived the fire, and built the Kaaba with his son.',
  body:
  'Prophet Ibrahim (as) is one of the greatest messengers of Allah and a central figure in Islam. '
      'He is known for his pure monotheism, courage, and absolute trust in Allah even during the toughest trials.\n\n'
      'From a young age, Ibrahim (as) recognized the falsehood of idol worship practiced by his people. '
      'He questioned the beliefs of his community and invited them to worship Allah alone. When they refused, he destroyed their idols '
      'to show them that statues could not protect themselves, let alone benefit others.\n\n'
      'His people became furious and decided to burn him alive. A massive fire was built, so large that birds could not fly over it. '
      'Ibrahim (as) was thrown into the fire using a catapult. In that moment, he placed his trust completely in Allah.\n\n'
      'Allah commanded the fire: "O fire! Be coolness and safety for Ibrahim!" '
      'The fire became harmless, and he emerged unharmed — a miracle that shook his people.\n\n'
      'Later in life, Ibrahim (as) was tested with the command to sacrifice his beloved son, Ismail (as). '
      'Though it was the hardest test a father could face, he submitted completely to Allah\'s will. '
      'Ismail (as), too, was willing to obey Allah. Just as Ibrahim (as) moved the knife, Allah replaced Ismail with a ram, '
      'proving their sincerity without requiring the sacrifice.\n\n'
      'Because of his incredible faith, Ibrahim (as) is honored as "Khalilullah" — the close friend of Allah. '
      'His devotion is remembered every year during Eid al-Adha and through the Hajj rituals.\n\n'
      'The story of Ibrahim (as) teaches us:\n'
      '• True faith requires trust in Allah even when things seem impossible\n'
      '• Sacrifice is part of spiritual growth\n'
      '• Allah never lets down those who sincerely obey Him',
  questions: [
    QuizQuestion(
      question: 'What made Prophet Ibrahim (as) reject the beliefs of his people?',
      options: [
        'He saw idols being made by people and knew they could not be gods',
        'He was told by a traveler that idols were fake',
        'He had a dream to destroy the idols',
        'He was influenced by a neighboring tribe',
      ],
      correctIndex: 0,
    ),
    QuizQuestion(
      question: 'How did Ibrahim (as) demonstrate the idols’ weakness?',
      options: [
        'He secretly moved them to another city',
        'He destroyed them except for the biggest one',
        'He painted them in different colors',
        'He hid them so people would look for them',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: 'What happened when Ibrahim (as) was thrown into the fire?',
      options: [
        'The fire grew even stronger',
        'He escaped before landing',
        'The fire became cool and safe by Allah’s command',
        'The people changed their minds and rescued him',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'What was Ibrahim’s (as) response to Allah’s command to sacrifice his son?',
      options: [
        'He refused and asked for another test',
        'He obeyed although it was extremely difficult',
        'He waited many years before obeying',
        'He told no one and ran away',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: 'How did Ismail (as) react to the command of sacrifice?',
      options: [
        'He cried and begged to be spared',
        'He encouraged his father to obey Allah',
        'He ran away to avoid it',
        'He asked for a replacement animal',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: 'What did Allah replace Ismail (as) with during the sacrifice?',
      options: [
        'A bull',
        'A camel',
        'A lion',
        'A ram',
      ],
      correctIndex: 3,
    ),
    QuizQuestion(
      question: 'Why is Ibrahim (as) called Khalilullah?',
      options: [
        'Because he built the first mosque',
        'Because he was a skilled warrior',
        'Because he was a close friend of Allah',
        'Because he lived for many years',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'Which yearly Islamic event commemorates the sacrifice of Ibrahim (as)?',
      options: [
        'Eid al-Fitr',
        'Eid al-Adha',
        'Laylat al-Qadr',
        'Ashura',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: 'What major structure did Ibrahim (as) help build?',
      options: [
        'Masjid Al-Aqsa',
        'Ka\'bah',
        'Masjid Al-Nabawi',
        'The pyramids',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: 'What is the main lesson from the story of Ibrahim (as)?',
      options: [
        'Success comes through wealth',
        'Miracles happen without effort',
        'True faith requires total trust in Allah',
        'People must follow traditions no matter what',
      ],
      correctIndex: 2,
    ),
  ],
);
