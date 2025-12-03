import 'package:flutter/material.dart';
import '../models/story_data.dart';
import 'stories_page.dart';

const StoryData ishaqStory = StoryData(
  id: 'ishaq',
  appBarTitle: 'Prophet Ishaq (as)',
  chipLabel: 'Prophet Ishaq (as)',
  title: 'The Story of Prophet Ishaq (as)',
  subtitle: 'A child of promise, patience and trust in Allah',
  icon: Icons.family_restroom_rounded,
  cardPreview:
  'The son granted to Ibrahim (as) in old age, whose life reminds us of trust, family and Allah’s promise.',
  body:
  'Prophet Ishaq (peace be upon him) was the son of Prophet Ibrahim (as) and his wife Sarah. '
      'For many years, Ibrahim (as) and Sarah had no children. They grew old, but they still trusted in Allah’s plan.\n\n'
      'Then, by Allah’s mercy, angels came with good news. They told Ibrahim (as) and Sarah that Allah would bless them with a son named Ishaq. '
      'Sarah was surprised because of her old age, but nothing is impossible for Allah.\n\n'
      'Ishaq (as) grew up in a home full of faith. His father Ibrahim (as) was a prophet who always obeyed Allah, even in the hardest tests. '
      'From his father, Ishaq (as) learned to rely on Allah, to speak the truth, and to live with sincerity and kindness.\n\n'
      'When he grew older, Allah chose Ishaq (as) as a prophet as well. He continued the message of tawheed — that only Allah deserves to be worshipped — just as Ibrahim (as) had done. '
      'He taught his family to avoid idols, to be just, and to be grateful for every blessing.\n\n'
      'Allah also blessed Ishaq (as) with children and grandchildren, and from his family came many prophets. '
      'Among his descendants were great prophets like Yaqub (as) and Yusuf (as). This shows that a home built on faith can spread goodness for many generations.\n\n'
      'Prophet Ishaq (as) lived a calm and blessed life, devoted to worship, dua, and guiding his family. '
      'Even though we do not have as many detailed stories about him as some other prophets, what we do know is that he was righteous, patient, and obedient to Allah.\n\n'
      'From the story of Ishaq (as), we learn that Allah never forgets the dua of His servants, even if answers come after many years. '
      'We also learn that being a good parent and child of faith can have a huge impact on the future, because faith and good character can be passed on like a beautiful gift.',
  questions: [
    QuizQuestion(
      question: 'Who were the parents of Prophet Ishaq (as)?',
      options: [
        'Ibrahim (as) and Hajar',
        'Ibrahim (as) and Sarah',
        'Yaqub (as) and Rachel',
        'Adam (as) and Hawwa',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: 'How did Ibrahim (as) and Sarah feel before Ishaq (as) was born?',
      options: [
        'They had many children',
        'They thought they were too old to have children',
        'They did not want children',
        'They were angry with Allah',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: 'Who gave the good news about Ishaq (as) to Ibrahim (as)?',
      options: [
        'Neighbours',
        'Strangers',
        'Angels sent by Allah',
        'Merchants',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'What main message did Ishaq (as) continue to teach?',
      options: [
        'To worship idols',
        'To follow the stars',
        'To worship Allah alone (tawheed)',
        'To collect more wealth',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'Which great prophets came from the family of Ishaq (as)?',
      options: [
        'Nuh (as) and Hud (as)',
        'Musa (as) and Harun (as)',
        'Yaqub (as) and Yusuf (as)',
        'Yunus (as) and Shuayb (as)',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'What did Ishaq (as) learn from his father Ibrahim (as)?',
      options: [
        'To love idols',
        'To disobey Allah',
        'To obey Allah and speak the truth',
        'To build big palaces',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'What do we learn from the delayed birth of Ishaq (as)?',
      options: [
        'Allah never answers dua',
        'Allah only helps the young',
        'Allah forgets His servants',
        'Allah answers dua in the best time and way',
      ],
      correctIndex: 3,
    ),
    QuizQuestion(
      question: 'How was the home of Ishaq (as) described?',
      options: [
        'Full of idols',
        'Full of anger',
        'Full of faith and obedience to Allah',
        'Always noisy and careless',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'What kind of impact can a faithful family like that of Ishaq (as) have?',
      options: [
        'No impact at all',
        'Only on neighbours',
        'It can spread goodness for generations',
        'Only in times of war',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'What is one key lesson from the story of Ishaq (as)?',
      options: [
        'To give up making dua',
        'That Allah’s promise is always true',
        'That family does not matter',
        'That only wealth brings happiness',
      ],
      correctIndex: 1,
    ),
  ],
);
