import 'package:flutter/material.dart';
import '../models/story_data.dart';
import 'stories_page.dart';

const StoryData muhammadPart1Story = StoryData(
  id: 'muhammad_part1',
  appBarTitle: 'Prophet Muhammad (ﷺ) – Part 1',
  chipLabel: 'Muhammad (ﷺ) – Part 1',
  title: 'Early Life of Prophet Muhammad (ﷺ)',
  subtitle: 'Orphanhood, honesty and a pure heart',
  icon: Icons.star_rounded,
  cardPreview:
  'The early life of Prophet Muhammad (ﷺ): growing up as an orphan, earning the name Al-Amin, and staying pure in a society full of idols.',
  body:
  'Prophet Muhammad (peace be upon him) was born in the city of Makkah, in the tribe of Quraysh. '
      'His father, Abdullah, passed away before he was born, and his mother, Amina, passed away when he was still very young. '
      'He grew up as an orphan, but Allah was always protecting and guiding him.\n\n'
      'First, his grandfather Abdul Muttalib took care of him with great love. '
      'After his grandfather died, his uncle Abu Talib looked after him and treated him like his own son. '
      'Even though he had a difficult start in life, the Prophet (ﷺ) did not become bitter or hard-hearted. '
      'He grew into a gentle, kind and thoughtful young man.\n\n'
      'As a child, he never bowed to idols and did not join the wrong customs and celebrations of his people. '
      'He stayed away from drinking alcohol, lying, cheating and bad behaviour. '
      'People in Makkah noticed his honesty and fairness in everything he did.\n\n'
      'When he became older, he worked as a shepherd, looking after sheep. '
      'This taught him patience, mercy and responsibility, because shepherds must protect their flock and guide them carefully. '
      'Later, he worked as a trader and helped people with their business.\n\n'
      'In trade, he was completely honest. '
      'He did not hide faults in the goods, and he did not raise prices unfairly. '
      'He spoke calmly, never shouted, and never broke his promises. '
      'Because of this, people trusted him deeply and gave him the beautiful nickname “Al-Amin”, which means “the trustworthy one”.\n\n'
      'A noble woman named Khadijah (may Allah be pleased with her) heard about his honesty and character. '
      'She asked him to manage some of her trade journeys. '
      'When her servant returned, he told her how kind, respectful and trustworthy Muhammad (ﷺ) was on the journey.\n\n'
      'Khadijah (ra) admired his character and later they married. '
      'She became his loving and loyal wife, and Allah blessed them with children. '
      'Their home was filled with warmth, mercy and respect.\n\n'
      'Even before he became a prophet, Muhammad (ﷺ) felt uncomfortable with the wrong things happening in Makkah. '
      'People were worshipping idols, cheating in trade and being unfair to the weak and poor. '
      'His heart was pure, and he knew these actions could not be the right way.\n\n'
      'From his early life, we see that Allah was preparing him for a great mission. '
      'He grew up patient and strong through hardship, gentle and honest with people, and always far away from shirk and bad habits.\n\n'
      'From this part of his story, we learn that difficult beginnings do not stop a person from becoming beloved to Allah. '
      'We also learn that good manners, honesty and purity are the foundation of a believer’s life.',
  questions: [
    QuizQuestion(
      question: 'In which city was Prophet Muhammad (ﷺ) born?',
      options: [
        'Madinah',
        'Makkah',
        'Jerusalem',
        'Taif',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
      'What happened to the parents of Prophet Muhammad (ﷺ) when he was young?',
      options: [
        'They travelled far away',
        'They became kings',
        'They both passed away and he became an orphan',
        'They moved to another city',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'Who took care of him after his mother passed away?',
      options: [
        'His friend Abu Bakr (ra)',
        'His grandfather Abdul Muttalib and then his uncle Abu Talib',
        'A stranger in another town',
        'A teacher in a school',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
      'What special nickname did the people of Makkah give Muhammad (ﷺ)?',
      options: [
        'Al-Kareem (The Generous)',
        'Al-Qawi (The Strong)',
        'Al-Amin (The Trustworthy)',
        'Al-Alim (The Knowledgeable)',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'What kind of work did he do when he was young?',
      options: [
        'Builder and farmer',
        'Shepherd and trader',
        'Soldier and judge',
        'Teacher and doctor',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
      'How did Prophet Muhammad (ﷺ) behave in business and trade?',
      options: [
        'He cheated sometimes to earn more',
        'He lied if it helped the sale',
        'He was honest, calm and fair',
        'He refused to work at all',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'Which noble woman later became his wife and loved his good character?',
      options: [
        'Aisha (ra)',
        'Fatimah (ra)',
        'Hafsah (ra)',
        'Khadijah (ra)',
      ],
      correctIndex: 3,
    ),
    QuizQuestion(
      question:
      'What did the people around him worship before Islam came?',
      options: [
        'They worshipped only Allah',
        'They worshipped idols and statues',
        'They worshipped trees',
        'They did not worship anything',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
      'How did Prophet Muhammad (ﷺ) feel about the wrong things in Makkah?',
      options: [
        'He loved them',
        'He joined them happily',
        'He felt uncomfortable and stayed away from them',
        'He organised more idol festivals',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'What is one important lesson from this part of his life?',
      options: [
        'Good manners and honesty are only for old people',
        'A difficult childhood means you cannot succeed',
        'Being pure and trustworthy prepares a person for great responsibilities',
        'Worshipping idols is fine if others do it',
      ],
      correctIndex: 2,
    ),
  ],
);
