// lib/pages/sulayman_story.dart
import 'package:flutter/material.dart';
import '../models/story_data.dart';
import '../pages/stories_page.dart';

const StoryData sulaymanStory = StoryData(
  id: 'sulayman',
  appBarTitle: 'Prophet Sulayman (as)',
  chipLabel: 'Prophet Sulayman (as)',
  title: 'The Story of Prophet Sulayman (as)',
  subtitle: 'Wisdom, gratitude and kindness to all creatures',
  icon: Icons.account_tree_rounded,
  cardPreview: 'The prophet blessed with wisdom, who understood creatures and ruled with justice and gratitude.',
  body:
  'Prophet Sulayman (peace be upon him) was the son of Prophet Dawud (David, as). '
      'Allah blessed him with a special kingdom, great wisdom, and many gifts. '
      'One of his special gifts was that he could understand the speech of animals and birds by the permission of Allah.\n\n'
      'Sulayman (as) knew that all power and knowledge come only from Allah. '
      'He did not become proud because of his gifts. Instead, he was humble and always thanked Allah. '
      'He was a just ruler who cared for people, animals, and even tiny creatures like ants.\n\n'
      'One day, Prophet Sulayman (as) was marching with his army. His army was very special: it was made up of humans, jinn, and birds, all organised in rows. '
      'As they passed through a valley of ants, one small ant saw the army approaching and became worried. '
      'The ant cried out to the other ants, telling them to go back into their homes so that Sulayman (as) and his army would not accidentally step on them.\n\n'
      'Allah allowed Sulayman (as) to hear the words of this little ant. '
      'When he heard what the ant said, he smiled gently and laughed in a kind way, not in a mocking way. '
      'He was touched by the ant’s care for its community. '
      'He immediately turned to Allah in gratitude and made dua, asking Allah to help him be thankful for all His blessings and to do good deeds that please Allah.\n\n'
      'Another famous part of his story is about the hoopoe bird (al-hudhud). '
      'One day, Sulayman (as) noticed that the hoopoe bird was missing from its place in the army. '
      'A king normally might become angry, but Sulayman (as) waited to hear the bird’s reason before deciding. '
      'When the hoopoe finally returned, it brought important news.\n\n'
      'The hoopoe told Sulayman (as) about a distant land called Saba (Sheba), ruled by a queen. '
      'The people there had many blessings, but instead of worshipping Allah, they worshipped the sun. '
      'The hoopoe had seen their strong kingdom and their throne, but also their wrong way of worship.\n\n'
      'Prophet Sulayman (as) wanted to invite them to the truth, not to take their land. '
      'He wrote a gentle but firm letter in the name of Allah, the Most Merciful. '
      'In the letter, he invited the queen and her people to stop worshipping the sun and to submit to Allah alone. '
      'The hoopoe carried this letter and dropped it to the queen.\n\n'
      'The Queen of Sheba was wise. She did not rush to fight. She consulted her advisors and then decided to visit Sulayman (as) to see for herself. '
      'Before she arrived, Sulayman (as) wanted to show her that his power came from Allah. '
      'He asked who could bring her throne to him before she reached his court. '
      'By Allah’s permission, a strong jinn brought the throne very quickly. '
      'Another person, who had knowledge from the Book, brought it even faster, in the blink of an eye.\n\n'
      'When Sulayman (as) saw the throne placed in front of him, he did not boast. '
      'Instead, he said that this was a test from his Lord, to see if he would be grateful or ungrateful. '
      'This shows that even when something amazing happened, he remembered that it came from Allah.\n\n'
      'When the queen finally met Sulayman (as), she saw his justice, his good manners, and the signs of Allah’s power. '
      'She realised that her people’s way of worship was wrong. '
      'In the end, she accepted the truth and submitted to Allah along with Sulayman (as).\n\n'
      'Throughout his life, Prophet Sulayman (as) remained a thankful servant of Allah. '
      'Even though he had a great kingdom, he never forgot that he was just a servant of his Lord.\n\n'
      'From the story of Prophet Sulayman (as), we learn to be grateful for our blessings, to stay humble even when we have strength or knowledge, '
      'to be kind to all creatures, and to use any power we have in a way that pleases Allah. '
      'We also learn that wisdom means thinking carefully, listening to others, and always remembering Allah first.',
  questions: [
    QuizQuestion(
      question:
      'Who was the father of Prophet Sulayman (as)?',
      options: [
        'Prophet Ibrahim (as)',
        'Prophet Musa (as)',
        'Prophet Dawud (as)',
        'Prophet Yunus (as)',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'Which special gift did Allah give to Prophet Sulayman (as)?',
      options: [
        'He could become invisible',
        'He could understand the speech of animals and birds',
        'He could live forever',
        'He could turn stones into gold',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
      'What did the ant warn the other ants about?',
      options: [
        'A big storm was coming',
        'Sulayman’s army might step on them without noticing',
        'A flood in the valley',
        'A group of hunters nearby',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
      'How did Prophet Sulayman (as) react when he heard the ant speaking?',
      options: [
        'He became angry',
        'He ignored it',
        'He smiled and thanked Allah',
        'He ordered his army to stop forever',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'Which bird brought news about the Queen of Sheba to Sulayman (as)?',
      options: [
        'An eagle',
        'A pigeon',
        'A hoopoe bird (al-hudhud)',
        'A parrot',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'What was wrong with the way the people of Sheba worshipped?',
      options: [
        'They did not pray at all',
        'They only worshipped at night',
        'They worshipped the sun instead of Allah',
        'They worshipped in the wrong language',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'What did Sulayman (as) send to the Queen of Sheba?',
      options: [
        'A gift of gold',
        'A warning to go to war',
        'A letter inviting her to worship Allah alone',
        'A new crown',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'What amazing thing did the jinn and the man with knowledge do before the queen arrived?',
      options: [
        'They made the sun stand still',
        'They turned water into milk',
        'They brought the queen’s throne to Sulayman (as)',
        'They built a new palace in one day',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'When Sulayman (as) saw the throne brought so quickly, what did he say this was?',
      options: [
        'A trick from the jinn',
        'A test from his Lord to see if he would be grateful',
        'Just normal magic',
        'A good chance to show off his power',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
      'What is an important lesson we learn from the story of Prophet Sulayman (as)?',
      options: [
        'To always show off our blessings',
        'That power means we can do anything we want',
        'That we should be grateful, humble, and kind to all creatures',
        'That animals are not important',
      ],
      correctIndex: 2,
    ),
  ],
);
