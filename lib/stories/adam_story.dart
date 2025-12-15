import 'package:flutter/material.dart';
import '../models/story_data.dart';
import '../pages/stories_page.dart';

const StoryData adamStory = StoryData(
  id: 'adam',
  appBarTitle: 'Prophet Adam (as)',
  chipLabel: 'Prophet Adam (as)',
  title: 'The Story of Prophet Adam (as)',
  subtitle: 'The first human, the first prophet, and the beginning of our story',
  icon: Icons.park_rounded,
  cardPreview:
  'The first human created by Allah, who lived in Jannah and taught us about repentance and mercy.',
  body:
  'Prophet Adam (peace be upon him) was the first human being and the first prophet. '
      'Allah created Adam (as) from clay and shaped him with His own hands. Then Allah breathed His spirit into him, '
      'and Adam (as) came to life. Allah honored him by teaching him the names of all things and giving him knowledge that even the angels did not have.\n\n'
      'Allah commanded the angels to bow down to Adam (as) as a sign of respect, not worship. All of them obeyed except Iblis. '
      'Iblis was arrogant and full of pride. He thought he was better than Adam (as) because he was created from fire, while Adam (as) was created from clay. '
      'He refused to obey Allah and became one of the disbelievers. From that moment, Iblis became the enemy of Adam (as) and all his children.\n\n'
      'Allah gave Adam (as) a home in Jannah, a beautiful garden with rivers, trees, and blessings. Allah gave him a wife, Hawwa (Eve), and they lived together in peace. '
      'They were allowed to enjoy everything in Jannah except one specific tree. Allah clearly warned them not to eat from that tree.\n\n'
      'Iblis, however, wanted Adam (as) and Hawwa to disobey Allah so that they would lose the blessings of Jannah. '
      'He whispered to them and tried to trick them. He told them that if they ate from the forbidden tree, they would become like angels or live forever. '
      'He made the sin look small and attractive. In a moment of weakness, Adam (as) and Hawwa listened to his whisper and ate from the tree.\n\n'
      'As soon as they did, they realized their mistake. Their clothes of light disappeared, and they felt exposed and ashamed. '
      'They quickly covered themselves with leaves from the trees of Jannah. They knew that they had disobeyed Allah.\n\n'
      'Adam (as) and Hawwa immediately turned back to Allah in repentance. They did not blame anyone else. They said a sincere dua, asking Allah to forgive them. '
      'Allah taught them the words of repentance and accepted their tawbah. This shows us that even when we make mistakes, Allah’s door of mercy is still open if we return to Him.\n\n'
      'After this, Allah sent Adam (as) and Hawwa down to the earth. This was part of Allah’s plan, because He had already decided to make human beings live on earth as generations, '
      'worshipping Him and building a life here. Allah told them that they and their children would live on earth, sometimes facing hardship and tests, but also receiving guidance from Him. '
      'Whoever follows that guidance will be safe, and whoever turns away will be lost.\n\n'
      'Adam (as) lived on earth as a prophet, teaching his children to worship Allah alone, to be grateful, and to stay away from the whispers of Shaytan. '
      'From him, all of humanity began. Every person alive today is one of his descendants.\n\n'
      'From the story of Prophet Adam (as), we learn many important lessons: that Allah created us with honor and purpose; '
      'that Shaytan is our clear enemy; that sins can happen, but the true believer turns back quickly to Allah with sincere repentance; '
      'and that Allah is the Most Forgiving and Most Merciful to those who return to Him.',
  questions: [
    QuizQuestion(
      question: 'From what did Allah create Prophet Adam (as)?',
      options: [
        'From light',
        'From fire',
        'From clay',
        'From iron',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'What special gift did Allah give to Adam (as) that even the angels did not have?',
      options: [
        'Wings to fly',
        'Knowledge of the names of all things',
        'A crown of gold',
        'The ability to become invisible',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
      'Why did Iblis refuse to bow down to Adam (as) when Allah commanded it?',
      options: [
        'He did not hear the command',
        'He was too tired',
        'He felt proud and thought he was better',
        'He loved Adam (as) too much',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'Where did Adam (as) and Hawwa first live together?',
      options: [
        'In a desert',
        'In Jannah (Paradise)',
        'On a mountain',
        'In a village on earth',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
      'What was the one rule Allah gave Adam (as) and Hawwa in Jannah?',
      options: [
        'Do not speak to the angels',
        'Do not drink from the rivers',
        'Do not eat from one specific tree',
        'Do not walk in the garden',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'How did Iblis try to trick Adam (as) and Hawwa into eating from the forbidden tree?',
      options: [
        'He forced them to eat',
        'He whispered that they would live forever or become like angels',
        'He shouted at them angrily',
        'He wrote a letter to them',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
      'What happened immediately after Adam (as) and Hawwa ate from the forbidden tree?',
      options: [
        'They forgot everything',
        'They became invisible',
        'Their clothes of light disappeared and they felt ashamed',
        'They turned into angels',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'How did Adam (as) and Hawwa react after realizing they had disobeyed Allah?',
      options: [
        'They blamed each other and Iblis',
        'They ran away and hid',
        'They turned back to Allah in sincere repentance',
        'They ignored what happened',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'Where did Allah send Adam (as) and Hawwa after forgiving them?',
      options: [
        'Back to Jannah',
        'To live on earth',
        'To another planet',
        'To live with the angels',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
      'What is one important lesson from the story of Prophet Adam (as)?',
      options: [
        'That humans were created without any purpose',
        'That we should never ask Allah for forgiveness',
        'That Shaytan is our enemy and we must return to Allah when we make mistakes',
        'That we must never live on earth',
      ],
      correctIndex: 2,
    ),
  ],
);
