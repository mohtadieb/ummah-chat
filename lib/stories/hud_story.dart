import 'package:flutter/material.dart';
import '../models/story_data.dart';
import '../pages/stories_page.dart';

const StoryData hudStory = StoryData(
  id: 'hud',
  appBarTitle: 'Prophet Hud (as)',
  chipLabel: 'Prophet Hud (as)',
  title: 'The Story of Prophet Hud (as)',
  subtitle: 'Warning a powerful nation that forgot Allah',
  icon: Icons.wind_power_rounded,
  cardPreview:
  'A prophet sent to a strong and proud people who built huge buildings but refused to obey Allah, until a mighty wind destroyed them.',
  body:
  'Prophet Hud (peace be upon him) was sent to the people of \'Ad. They were a very strong and powerful nation. '
      'They built tall pillars and impressive buildings in the land of Al-Ahqaf, and they were proud of their strength. '
      'Instead of being grateful to Allah, they became arrogant. They worshipped idols, oppressed others, and felt that no one could defeat them.\n\n'
      'Allah sent Hud (as) to guide them. He was from among their own people, spoke their language, and cared about them. '
      'He called them to worship Allah alone, to stop worshipping idols, and to fear Allah, who had given them everything they had. '
      'He reminded them that their strength and their beautiful homes were gifts from Allah, not reasons to be proud and unjust.\n\n'
      'Hud (as) told them that if they believed and obeyed Allah, He would increase their blessings. But if they continued in their arrogance and disbelief, '
      'a punishment would come. The leaders of \'Ad laughed at him. They said things like, “Who is stronger than us?” and accused Hud (as) of being foolish. '
      'They did not want to give up their pride or their idols.\n\n'
      'Hud (as) remained patient. He told them clearly that he did not ask for any reward from them, that his reward was only with Allah. '
      'He warned them again and again, over many years. Only a small group believed in him and followed him.\n\n'
      'When the people completely refused to listen, the punishment of Allah began. At first, their land became dry. The rain stopped, and the people of \'Ad hoped for clouds of rain. '
      'One day, they saw a huge dark cloud approaching and became happy, thinking it would bring water. But that cloud carried a violent, freezing wind. '
      'The wind blew with great force for many days, destroying their homes and throwing their bodies to the ground. The strong nation of \'Ad, which thought no one could defeat them, '
      'was wiped out. Only Hud (as) and the believers with him were saved.\n\n'
      'Allah mentions the people of \'Ad in the Qur’an as a warning to others: power and wealth are not a protection if a person is arrogant and disobedient. '
      'True safety is in obeying Allah and being humble.\n\n'
      'From the story of Prophet Hud (as), we learn not to be proud of our strength, our homes, or our achievements. '
      'Everything we have is a gift from Allah, and He can take it away whenever He wills. We also learn to stay patient like Hud (as) when others reject the truth, '
      'and to remember that real honor comes from obeying Allah, not from impressing people.',
  questions: [
    QuizQuestion(
      question: 'To which nation was Prophet Hud (as) sent?',
      options: [
        'The people of Madyan',
        'The people of \'Ad',
        'The people of Thamud',
        'The people of Quraysh',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
      'What were the people of \'Ad especially known for?',
      options: [
        'Their weakness and poverty',
        'Their love of traveling by sea',
        'Their strength and tall buildings',
        'Their skill in writing books',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'What was the main message that Hud (as) gave to his people?',
      options: [
        'To build even bigger houses',
        'To worship Allah alone and stop worshipping idols',
        'To move to another land',
        'To stop farming completely',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
      'How did many of the leaders of \'Ad react to Hud (as)?',
      options: [
        'They welcomed him and believed immediately',
        'They were afraid and left the town',
        'They mocked him and called him foolish',
        'They stayed silent and neutral',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'What did Hud (as) tell his people about the blessings they had?',
      options: [
        'That they earned them all by themselves',
        'That the idols gave them everything',
        'That they were gifts from Allah and should make them grateful',
        'That they did not deserve any blessings',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'What happened in the land of \'Ad before the punishment came?',
      options: [
        'It started raining heavily for many months',
        'They had an earthquake first',
        'Their land became dry and they hoped for rain',
        'A big fire appeared from the sky',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'What was inside the dark cloud that the people of \'Ad thought was bringing rain?',
      options: [
        'Soft, gentle rain only',
        'A bright rainbow',
        'A violent, freezing wind that destroyed them',
        'Many birds',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'What happened to Prophet Hud (as) and the believers when the punishment came?',
      options: [
        'They were destroyed with the others',
        'They were saved by Allah',
        'They moved to the sky',
        'They turned into angels',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
      'What important lesson do we learn from the story of Hud (as) and the people of \'Ad?',
      options: [
        'That being strong means you will never be punished',
        'That wealth and power can replace obedience to Allah',
        'That arrogance and idol worship can destroy a nation',
        'That prophets should not warn their people',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'What is a good way to act, based on the story of Hud (as)?',
      options: [
        'Be proud and show off your strength',
        'Think you are better than others',
        'Be humble, thank Allah for His gifts, and obey Him',
        'Ignore all warnings and do what you want',
      ],
      correctIndex: 2,
    ),
  ],
);
