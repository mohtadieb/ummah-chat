import 'package:flutter/material.dart';
import '../models/story_data.dart';
import '../pages/stories_page.dart';

const StoryData muhammadPart2Story = StoryData(
  id: 'muhammad_part2',
  appBarTitle: 'Prophet Muhammad (ﷺ) – Part 2',
  chipLabel: 'Muhammad (ﷺ) – Part 2',
  title: 'The First Revelation',
  subtitle: '“Read in the name of your Lord”',
  icon: Icons.menu_book_rounded,
  cardPreview:
  'The moment in Cave Hira when the first verses of the Qur’an were revealed and the mission of prophethood began.',
  body:
  'As the Prophet Muhammad (ﷺ) grew older, he became more and more upset by the idol worship and injustice around him in Makkah. '
      'His heart was pure and he wanted to be close to Allah. '
      'He would spend time alone in a cave called Hira, on a mountain just outside Makkah.\n\n'
      'He took food and water with him and stayed there for several nights, thinking deeply, remembering Allah, and reflecting on the creation. '
      'This quiet time helped him disconnect from the noise and sins of the city and connect with his Lord.\n\n'
      'When he was about forty years old, something amazing happened. '
      'One night in the month of Ramadan, while he was in the cave of Hira, the angel Jibreel (Gabriel, peace be upon him) came to him. '
      'The angel said to him: “Read.”\n\n'
      'The Prophet (ﷺ) replied that he could not read. '
      'The angel repeated the command and then recited the first verses of the Qur’an by the permission of Allah. '
      'These verses spoke about reading in the name of Allah, the One who created us.\n\n'
      'This was the beginning of revelation and the start of his mission as the final messenger. '
      'The Prophet (ﷺ) was deeply moved and shaken by this powerful experience. '
      'He quickly left the cave and went home to his wife Khadijah (ra), his heart trembling.\n\n'
      'He said, “Cover me, cover me,” and she wrapped him in a cloak and comforted him. '
      'He told her what had happened, and how the angel came to him with the words of Allah. '
      'Khadijah (ra) listened carefully and did not doubt him for a moment.\n\n'
      'She reminded him of his good qualities: that he kept family ties, helped the poor, cared for guests, and supported people in difficulty. '
      'She said that Allah would never disgrace someone with such noble character. '
      'She believed in him immediately and became the first person to accept Islam.\n\n'
      'Khadijah (ra) then took him to a wise man named Waraqah ibn Nawfal, who knew the previous scriptures. '
      'After hearing what happened, Waraqah said that the angel who came to him was the same angel who came to Musa (as), '
      'and that Muhammad (ﷺ) had truly been chosen as a prophet.\n\n'
      'After this, revelation paused for a short time, and the Prophet (ﷺ) felt great longing and fear, wondering when it would come again. '
      'Then more verses came, calling him to stand up and warn people, and to purify his heart and rely only on Allah.\n\n'
      'From this part of the story, we learn that guidance is a gift from Allah, that knowledge should be connected to faith (“Read in the name of your Lord”), '
      'and that having a supportive and believing family, like Khadijah (ra), is a great blessing.',
  questions: [
    QuizQuestion(
      question: 'Where did the Prophet (ﷺ) go to be alone and reflect?',
      options: [
        'A garden in Madinah',
        'A market in Makkah',
        'A cave called Hira',
        'A ship at sea',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'Why did he go to the cave of Hira?',
      options: [
        'To sell goods',
        'To hide from his family',
        'To remember Allah and reflect away from idol worship',
        'To sleep all day',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'Which angel came to him with the first revelation?',
      options: [
        'Angel Israfil',
        'Angel Jibreel (Gabriel)',
        'Angel Mikail',
        'Angel of Death',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: 'What was the first command the angel said to him?',
      options: [
        'Pray',
        'Run',
        'Read',
        'Travel',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'How did the Prophet (ﷺ) feel after the first revelation?',
      options: [
        'He laughed loudly',
        'He was careless',
        'He was shaken and rushed home',
        'He told no one ever',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'What did he ask Khadijah (ra) to do when he reached home?',
      options: [
        'Give him food',
        'Cover him with a cloak',
        'Call the neighbours',
        'Write a letter',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
      'How did Khadijah (ra) react when he told her about the revelation?',
      options: [
        'She doubted him',
        'She laughed at him',
        'She believed him and comforted him',
        'She told him to forget it',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'Who was Waraqah ibn Nawfal?',
      options: [
        'A child from Madinah',
        'A wise man who knew previous scriptures',
        'A soldier from another tribe',
        'A trader in Yemen',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
      'What did Waraqah say about the angel who came to Muhammad (ﷺ)?',
      options: [
        'It was only a dream',
        'It was a stranger',
        'It was the same angel who came to Musa (as)',
        'It was a jinn from the desert',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'What is one lesson from this part of the story?',
      options: [
        'Knowledge should be connected to faith and remembering Allah',
        'We should keep all feelings to ourselves',
        'Family support does not matter',
        'Revelation is only about stories, not guidance',
      ],
      correctIndex: 0,
    ),
  ],
);
