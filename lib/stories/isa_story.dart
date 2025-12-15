import 'package:flutter/material.dart';
import '../models/story_data.dart';
import '../pages/stories_page.dart';

const StoryData isaStory = StoryData(
  id: 'isa',
  appBarTitle: 'Prophet Isa (as)',
  chipLabel: 'Prophet Isa (as)',
  title: 'The Story of Prophet Isa (as)',
  subtitle:
  'A noble prophet, miracles by Allah’s permission, and a message of tawheed',
  icon: Icons.wb_sunny_rounded,
  cardPreview:
  'A prophet born without a father, who spoke as a baby, performed miracles by Allah’s permission, and will return near the end of time.',
  body:
  'Prophet Isa (peace be upon him) was one of the greatest messengers of Allah. '
      'He was born in a miraculous way to Maryam (as), a pure and righteous woman, without a father. '
      'Allah mentions in the Qur’an that when the angels brought the news to Maryam, she was surprised and asked how this could happen. '
      'Allah reminded her that He only says “Be” and it is. For Allah, nothing is impossible.\n\n'
      'Maryam (as) withdrew to a distant place. There, Isa (as) was born. When she returned to her people with the baby, they were shocked and accused her unfairly. '
      'Maryam (as) did not argue with them. Instead, she pointed to the baby. By the permission of Allah, Isa (as) spoke while still in the cradle. '
      'He said that he was a servant of Allah, that Allah had given him a book, made him a prophet, and commanded him to pray and give charity. '
      'From his very first words, he declared that he belonged to Allah and that he was not a god himself.\n\n'
      'As Isa (as) grew up, he was known for his purity, wisdom, and kindness. He called his people to worship Allah alone, without partners. '
      'He reminded them to follow the straight path, to obey Allah’s commands, and to purify their hearts from pride and hypocrisy.\n\n'
      'Allah supported him with clear miracles. By Allah’s permission, he healed those who were born blind and those who had leprosy. '
      'By Allah’s permission, he brought the dead back to life. He also shaped a bird from clay, and by Allah’s permission, it became a living bird. '
      'All of these miracles were signs, not magic. They showed that Allah is All-Powerful and that Isa (as) was truly His messenger.\n\n'
      'Allah gave Isa (as) the Injil (Gospel) as a book of guidance and light. He confirmed the truth of the Torah that came before him and made some things easier for his people. '
      'He taught mercy, kindness, and humility. He encouraged people to care for the poor, the sick, and the weak. '
      'He had close companions who believed in him and supported his message. They were called the Hawariyyun.\n\n'
      'One day, some of his followers asked for a special sign: a table spread with food sent down from the sky, so that their hearts would be at peace and their faith would grow stronger. '
      'Isa (as) warned them to fear Allah and not to ask for signs without need, but when they insisted sincerely, he made dua. '
      'Allah sent down the table as a clear sign and warned that anyone who disbelieved afterwards would face a severe punishment.\n\n'
      'Despite all these signs, many leaders among Bani Isra’il rejected Isa (as). They were afraid of losing their status and power. '
      'They spread lies about him and plotted to harm him. They planned to kill him, but Allah is the best of planners. '
      'They thought they had succeeded, but in reality they did not kill him and did not crucify him. It only appeared so to them. '
      'Allah raised Isa (as) up to Himself and saved him from their evil.\n\n'
      'Islam teaches that Isa (as) is alive and will return near the end of time as a great sign. '
      'When he returns, he will break the cross, kill the false messiah (Dajjal), and clarify the truth about himself: that he is a servant and messenger of Allah, not a god. '
      'He will rule with justice, and there will be a time of peace and fairness on earth.\n\n'
      'As Muslims, we love and respect Isa (as) deeply. We believe he was a human being honored by Allah, just like all the prophets. '
      'He called people to tawheed – worshipping Allah alone. We do not worship him, but we follow the message that he brought: to obey Allah and to purify our hearts.\n\n'
      'From the story of Prophet Isa (as), we learn that miracles belong only to Allah, even if they appear at the hands of His prophets. '
      'We learn to stand firm on the truth, even when others misunderstand us or spread lies. '
      'We also learn to stay humble, gentle, and full of mercy, and to remember that true honor is in being a servant of Allah, not in being praised by people.',
  questions: [
    QuizQuestion(
      question: 'How was Prophet Isa (as) born?',
      options: [
        'In a normal way to two parents',
        'He was created from clay like Adam (as)',
        'He was born to Maryam (as) without a father, by Allah’s will',
        'He was found as a baby in a basket on a river',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'What did baby Isa (as) do when Maryam’s people accused her?',
      options: [
        'He stayed silent',
        'He cried loudly',
        'He walked away',
        'He spoke in the cradle by Allah’s permission and defended his mother',
      ],
      correctIndex: 3,
    ),
    QuizQuestion(
      question:
      'What did Isa (as) say about himself when he spoke as a baby?',
      options: [
        'That he was a god',
        'That he was the son of a king',
        'That he was a servant of Allah and a prophet',
        'That he would never grow up',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'Which of these is one of the miracles given to Isa (as) by Allah’s permission?',
      options: [
        'He moved mountains with his hands',
        'He healed the blind and those with leprosy',
        'He stopped the sun in the sky',
        'He turned stones into gold for people',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: 'What book was revealed to Prophet Isa (as)?',
      options: [
        'The Qur’an',
        'The Tawrah (Torah)',
        'The Zabur (Psalms)',
        'The Injil (Gospel)',
      ],
      correctIndex: 3,
    ),
    QuizQuestion(
      question:
      'Who were the Hawariyyun in the story of Isa (as)?',
      options: [
        'His enemies who plotted against him',
        'A group of angels',
        'His close companions who believed in him and supported his message',
        'A group of merchants',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'What was the “table from the sky” (al-ma’idah) that some of his followers asked for?',
      options: [
        'A book sent down from heaven',
        'A table spread with food as a special sign from Allah',
        'A large stone to build a house',
        'A sword for fighting',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
      'What do Muslims believe actually happened when people thought Isa (as) was crucified?',
      options: [
        'He was killed and stayed in the grave',
        'He disappeared forever with no return',
        'They truly killed him, but his soul lives on',
        'They did not really kill or crucify him; Allah raised him up',
      ],
      correctIndex: 3,
    ),
    QuizQuestion(
      question:
      'What will Prophet Isa (as) do when he returns near the end of time?',
      options: [
        'Teach people to worship him',
        'Break the cross, defeat the false messiah, and rule with justice',
        'Hide from people and live alone',
        'Build a huge palace for himself',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
      'What is one key lesson we learn from the story of Isa (as)?',
      options: [
        'That people’s praise is more important than Allah’s pleasure',
        'That miracles belong to Allah and we must stay humble, truthful, and obedient to Him',
        'That we should stop helping the weak',
        'That prophets never face any difficulties',
      ],
      correctIndex: 1,
    ),
  ],
);
