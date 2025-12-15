import 'package:flutter/material.dart';
import '../models/story_data.dart';
import '../pages/stories_page.dart';

const StoryData harunStory = StoryData(
  id: 'harun',
  appBarTitle: 'Prophet Harun (as)',
  chipLabel: 'Prophet Harun (as)',
  title: 'The Story of Prophet Harun (as)',
  subtitle: 'Brotherhood, support and speaking with wisdom',
  icon: Icons.record_voice_over_rounded,
  cardPreview:
  'The brother of Musa (as), chosen by Allah to support him with gentle speech and wisdom.',
  body:
  'Prophet Harun (peace be upon him) was the brother of Prophet Musa (as). '
      'Both of them were chosen by Allah as prophets and were sent to guide the people of Bani Israil and to speak to the powerful Pharaoh of Egypt.\n\n'
      'Musa (as) once made dua to Allah asking for help in delivering the message. He said that his speech was not as smooth as he wanted, '
      'and he asked Allah to make his brother Harun (as) a prophet with him and a helper in his mission.\n\n'
      'Allah accepted this beautiful dua and chose Harun (as) as a prophet. '
      'Harun (as) was known for his gentle speaking, wisdom, and calm manner. '
      'Together, Musa (as) and Harun (as) went to Pharaoh to invite him to worship Allah alone and to free the oppressed people.\n\n'
      'Allah commanded them to speak to Pharaoh with soft and respectful words, even though he was a cruel and proud ruler. '
      'This teaches us that even when we stand against injustice, our words should still be careful and wise.\n\n'
      'Harun (as) stayed by Musa’s side during many important moments — during the miracles, the warnings to Pharaoh, and the rescue of Bani Israil. '
      'He was a trustworthy partner, standing firm in faith when others doubted.\n\n'
      'Later, when Musa (as) went up to the mountain for a time to receive guidance from Allah, Harun (as) was left in charge of the people. '
      'Some of them fell into the sin of worshipping a golden calf, and Harun (as) tried to warn and stop them, reminding them that only Allah deserves worship.\n\n'
      'From the story of Harun (as), we learn the importance of supporting one another in doing good, speaking gently even to those who are wrong, '
      'and standing firm in our belief even when others pressure us to do the opposite.',
  questions: [
    QuizQuestion(
      question: 'Who was Prophet Harun (as) the brother of?',
      options: [
        'Prophet Ibrahim (as)',
        'Prophet Yusuf (as)',
        'Prophet Musa (as)',
        'Prophet Isa (as)',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'Why did Musa (as) ask Allah to send Harun (as) with him?',
      options: [
        'To build houses',
        'To help him speak and deliver the message',
        'To cook food',
        'To count the people',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: 'How was Harun (as) described?',
      options: [
        'Harsh and loud',
        'Gentle and wise in speech',
        'Silent and afraid',
        'Always angry',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
      'Who did Musa (as) and Harun (as) go to speak to by Allah’s command?',
      options: [
        'A poor farmer',
        'The king of Yemen',
        'Pharaoh, the ruler of Egypt',
        'A group of travellers',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'How did Allah tell them to speak to Pharaoh?',
      options: [
        'With very rude words',
        'With shouting and insults',
        'With soft and respectful words',
        'By staying silent',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'What did some of Bani Israil do when Musa (as) went to the mountain?',
      options: [
        'They stayed patient and quiet',
        'They built a masjid',
        'They started worshipping a golden calf',
        'They left the land',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'What did Harun (as) do when the people turned to the calf?',
      options: [
        'He joined them',
        'He reminded them to worship Allah alone',
        'He left and never returned',
        'He destroyed everything',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
      'What lesson do we learn about teamwork from Musa (as) and Harun (as)?',
      options: [
        'We should do everything alone',
        'It is weak to ask for help',
        'Helping each other in good makes us stronger',
        'Only family can help',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'What is one lesson from how they spoke to Pharaoh?',
      options: [
        'We should always be rude to those who are wrong',
        'Soft and wise speech is powerful, even against injustice',
        'Words do not matter',
        'We should be silent all the time',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
      'How can we follow the example of Harun (as)?',
      options: [
        'Speak kindly and support others in doing good',
        'Argue loudly all the time',
        'Never remind people of Allah',
        'Only care about ourselves',
      ],
      correctIndex: 0,
    ),
  ],
);
