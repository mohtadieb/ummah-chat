// lib/pages/yunus_story.dart
import 'package:flutter/material.dart';
import '../models/story_data.dart';
import 'stories_page.dart';

const StoryData yunusStory = StoryData(
  id: 'yunus',
  appBarTitle: 'Prophet Yunus (as)',
  chipLabel: 'Prophet Yunus (as)',
  title: 'The Story of Prophet Yunus (as)',
  subtitle: 'Patience, repentance and Allah’s mercy',
  icon: Icons.water_rounded,
  cardPreview: 'The prophet who called his people by the sea and was swallowed by the great fish.',
  body:
  'Prophet Yunus (peace be upon him) was sent by Allah to a large town near the sea. '
      'The people of this town worshipped idols and refused to obey Allah. Yunus (as) called them '
      'with patience and sincerity: to worship Allah alone, to leave their idols, and to live justly.\n\n'
      'But most of the people rejected him. They argued with him, mocked him, and ignored his warnings. '
      'After a long time of calling them, Yunus (as) felt deep sadness. He warned them that the punishment '
      'of Allah could come if they continued to disbelieve. However, instead of waiting for Allah’s command, '
      'he left the town out of frustration, thinking that his people would never believe.\n\n'
      'Yunus (as) travelled towards the sea and boarded a ship. At first, the ship sailed smoothly. '
      'Then a heavy storm came, and the sea became wild. The ship was in danger of sinking. The sailors decided '
      'to lighten the load by throwing some passengers overboard. They drew lots to decide who would be thrown. '
      'By the will of Allah, the name of Yunus (as) came out. They drew lots again, and again his name appeared. '
      'A third time, his name came out once more. Yunus (as) understood that this was Allah’s decree, '
      'so he accepted it and was thrown into the dark sea.\n\n'
      'As he fell into the waves, Allah ordered a huge whale to swallow him whole, without harming him. '
      'Suddenly Yunus (as) found himself alive inside the belly of the whale, in layers of darkness: '
      'the darkness of the night, the darkness of the sea, and the darkness inside the whale.\n\n'
      'In this state, Yunus (as) realized that he had left his people without the permission of Allah. '
      'He turned completely to Allah, full of regret and humility. He did not blame anyone else. Instead, he said the famous dua:\n\n'
      '“La ilaha illa Anta, subhanaka, inni kuntu minaz-zalimin.”\n\n'
      'Meaning: “There is no god except You. You are perfect. Truly, I have been of the wrongdoers.”\n\n'
      'He repeated this dua again and again, glorifying Allah and asking for forgiveness. '
      'Allah, in His mercy, accepted his repentance. He commanded the whale to go to the shore and release him. '
      'The whale came close to land and gently released Yunus (as) onto the beach.\n\n'
      'When he came out, Yunus (as) was weak and ill. Allah caused a special plant with large leaves to grow over him, '
      'giving him shade and protection. He was given food and strength until he recovered.\n\n'
      'Then Allah sent him back to the same people he had left. During the time that Yunus (as) was gone, his people had seen signs '
      'of punishment coming. They became afraid and truly regretted their disbelief. They all turned to Allah together, '
      'repenting and asking for forgiveness before the punishment reached them. Allah forgave the entire town and removed the punishment from them.\n\n'
      'When Yunus (as) returned, he found that his people had believed. It became a community that worshipped Allah alone. '
      'Allah mentions this as a special example in the Qur’an.\n\n'
      'From the story of Prophet Yunus (as), we learn many lessons: to be patient when calling others to good, '
      'to never despair of Allah’s mercy, and to always turn back to Him with sincere repentance, even when we make mistakes. '
      'Allah is able to save us from every kind of “darkness” when we call upon Him sincerely.',
  questions: [
    QuizQuestion(
      question:
      'In which kind of town was Prophet Yunus (as) sent as a messenger?',
      options: [
        'To a small village in the desert',
        'To a big city near the sea',
        'To a mountain village',
        'To a city in the jungle',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
      'What was the main message that Prophet Yunus (as) called his people to?',
      options: [
        'To build a big mosque',
        'To worship Allah alone and leave idols',
        'To collect more wealth',
        'To travel to another land',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
      'How did the people first react to the call of Prophet Yunus (as)?',
      options: [
        'They believed immediately',
        'They ignored and rejected him',
        'They moved to another town',
        'They imprisoned him',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
      'What did Prophet Yunus (as) do, out of sadness and frustration, before Allah gave him permission?',
      options: [
        'He destroyed their idols',
        'He left the town and went towards the sea',
        'He stopped believing',
        'He wrote them a letter and stayed',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: 'What happened when Prophet Yunus (as) was on the ship?',
      options: [
        'The ship started to sink in a storm',
        'The ship reached the destination safely',
        'He became the captain',
        'The ship turned into a whale',
      ],
      correctIndex: 0,
    ),
    QuizQuestion(
      question: 'Why was Prophet Yunus (as) thrown into the sea from the ship?',
      options: [
        'He asked them to throw him',
        'He fell by accident',
        'They drew lots and his name came up',
        'He tried to swim for fun',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'What miraculous event happened after he was thrown into the sea?',
      options: [
        'A bird saved him',
        'He walked on water',
        'A whale swallowed him by Allah’s permission',
        'He immediately reached the shore',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'What did Prophet Yunus (as) do inside the belly of the whale?',
      options: [
        'He slept until morning',
        'He complained loudly to the sailors',
        'He remembered Allah and made dua',
        'He tried to break the whale’s teeth',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'Which famous dua is linked to Prophet Yunus (as) in the whale?',
      options: [
        '“Rabbana atina fid-dunya hasanah…”',
        '“La ilaha illa Anta, subhanaka, inni kuntu minaz-zalimin”',
        '“Hasbunallahu wa ni’mal wakeel”',
        '“Rabbishrah li sadri…”',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
      'What is one important lesson we learn from the story of Prophet Yunus (as)?',
      options: [
        'To never travel by sea',
        'That Allah does not forgive mistakes',
        'To give up quickly when people reject us',
        'To be patient, to keep trusting Allah, and to always repent',
      ],
      correctIndex: 3,
    ),
  ],
);
