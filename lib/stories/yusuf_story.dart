// lib/pages/yusuf_story.dart
import 'package:flutter/material.dart';
import '../models/story_models.dart';
import 'stories_page.dart';

const StoryData yusufStory = StoryData(
  id: 'yusuf',
  appBarTitle: 'Prophet Yusuf (as)',
  chipLabel: 'Prophet Yusuf (as)',
  title: 'The Story of Prophet Yusuf (as)',
  subtitle: 'A journey of patience, dreams and forgiveness',
  icon: Icons.star_rounded,
  body:
  'Prophet Yusuf (peace be upon him) was the son of Prophet Ya’qub (Jacob, as). '
      'As a young boy, Yusuf (as) had a beautiful and pure character. One night he saw a special dream. '
      'In his dream he saw eleven stars, the sun, and the moon bowing down to him. He told his father about this dream.\n\n'
      'His father understood that this dream was from Allah and that Yusuf (as) would one day be given great honour. '
      'He lovingly advised Yusuf (as) not to tell this dream to his brothers, because he knew that some of them were jealous of him.\n\n'
      'Yusuf’s brothers were many in number. They felt that their father loved Yusuf (as) and his younger brother more than them. '
      'Jealousy slowly grew in their hearts. Instead of fighting against this feeling and trusting Allah, they let it control them. '
      'They planned to get rid of Yusuf (as). Some wanted to kill him, others suggested a less severe plan: to throw him into a deep well so that he would be taken by travellers.\n\n'
      'They asked their father for permission to take Yusuf (as) out to play. Ya’qub (as) was worried and mentioned that a wolf might harm him. '
      'But the brothers insisted and promised to protect him. When they got the chance, they took Yusuf (as) away and threw him into a dark well, leaving him there alone.\n\n'
      'They went back to their father crying and brought his shirt with false blood on it. They claimed that a wolf had eaten Yusuf (as). '
      'Ya’qub (as) knew in his heart that their story was not true, but he turned to Allah with patience and said that beautiful patience (sabr jameel) was the best response.\n\n'
      'Meanwhile, a caravan of travellers passed by the well. One of them lowered a bucket and was surprised to find a boy holding onto it. '
      'They took Yusuf (as) out and decided to sell him as a slave in Egypt. He was bought by a noble man, often called al-‘Aziz, who told his wife to treat Yusuf (as) kindly.\n\n'
      'As he grew up in Egypt, Yusuf (as) became known for his honesty, good manners and beauty. The wife of al-‘Aziz tried to tempt him towards sin, but he refused and said he feared Allah. '
      'She locked the doors and called him, but he chose Allah over his desires. When he fled towards the door, she tore his shirt from behind. '
      'A member of the household later testified that Yusuf (as) was innocent.\n\n'
      'Even though he was innocent, Yusuf (as) was put into prison to protect the reputation of the people of the palace. '
      'In prison, he continued to behave with goodness and spoke gently about Allah. Two men in the prison had strange dreams and asked Yusuf (as) to interpret them. '
      'By Allah’s permission, he explained the meaning of their dreams correctly.\n\n'
      'Later, the king of Egypt had a troubling dream: seven fat cows being eaten by seven thin cows, and seven green ears of grain with seven dry ones. '
      'No one could explain it until one of the former prisoners remembered Yusuf (as). Yusuf (as) interpreted the dream as a message from Allah: '
      'there would be seven years of good harvest followed by seven years of hardship and famine, and he gave wise advice on how to store food during the good years.\n\n'
      'The king was impressed and wanted Yusuf (as) to be brought to him. But Yusuf (as) asked that his innocence be made clear first. '
      'The truth about what had happened with the women in the palace was finally admitted. Yusuf (as) was declared innocent and honoured by the king. '
      'He was given a high position in the land, placed in charge of the storehouses of grain.\n\n'
      'When the years of famine came, people from many lands travelled to Egypt to buy food. Among them were Yusuf’s brothers. '
      'They did not recognise him, but he recognised them. With wisdom, he tested their hearts and eventually brought his younger brother close to him.\n\n'
      'After some time and several meetings, Yusuf (as) revealed his true identity to his brothers. They felt deep regret for what they had done to him in the past. '
      'Instead of taking revenge, Yusuf (as) forgave them and said that no blame would be upon them that day. He recognised that Allah had guided the whole story and raised him in rank.\n\n'
      'Finally, Yusuf (as) invited his parents and his whole family to come to Egypt. They came and were united with him. '
      'At that moment, the dream of his childhood came true: it was as if the sun, moon, and eleven stars had bowed to him, meaning his parents and eleven brothers were honouring him. '
      'He thanked Allah for His kindness throughout his life.\n\n'
      'From the story of Prophet Yusuf (as), we learn the power of patience, purity, trust in Allah, and forgiveness. '
      'Even when others wrong us, Allah can bring out great good from our suffering if we remain patient and close to Him.',
  questions: [
    QuizQuestion(
      question:
      'What did young Yusuf (as) see in his special dream as a child?',
      options: [
        'Angels giving him a book',
        'Eleven stars, the sun and the moon bowing to him',
        'A whale in the sea',
        'A palace made of gold',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: 'Why were the brothers of Yusuf (as) jealous of him?',
      options: [
        'Because he was the youngest in the family',
        'Because he could read and write',
        'Because they felt their father loved Yusuf (as) more',
        'Because he was a king',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'What did the brothers decide to do with Yusuf (as) out of jealousy?',
      options: [
        'Send him to another city to study',
        'Throw him into a deep well',
        'Lock him in a room',
        'Sell him to the king directly',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
      'What did the brothers show their father when they returned without Yusuf (as)?',
      options: [
        'An empty shirt',
        'A letter from Yusuf (as)',
        'His shirt with false blood on it',
        'A broken toy',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'How did Yusuf (as) end up in Egypt after being thrown into the well?',
      options: [
        'He walked there alone',
        'A caravan of travellers found him and sold him as a slave',
        'His father took him there',
        'He was carried by angels',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
      'How did Yusuf (as) behave when the wife of al-‘Aziz tried to tempt him to sin?',
      options: [
        'He agreed quickly',
        'He ran away and said he feared Allah',
        'He shouted at her and left the house permanently',
        'He went to complain to his brothers',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
      'What was Yusuf (as) known for when he was in prison in Egypt?',
      options: [
        'His strength in fighting',
        'His singing voice',
        'His wisdom, good character, and dream interpretations',
        'His skills in building houses',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'What did Yusuf (as) say when he finally met his brothers again and they regretted their actions?',
      options: [
        '“I will never forgive you.”',
        '“You must leave Egypt now.”',
        '“No blame will be upon you today.”',
        '“You must become my servants.”',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'What position did Yusuf (as) receive in Egypt after interpreting the king’s dream?',
      options: [
        'He became a soldier',
        'He became the keeper of the storehouses of grain',
        'He became a judge in the marketplace',
        'He became a farmer',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
      'What is one major lesson we learn from the story of Yusuf (as)?',
      options: [
        'To always take revenge on people who hurt us',
        'That jealousy is a good motivator',
        'That Allah never tests the people He loves',
        'That patience, trust in Allah, and forgiveness can lead to great honour',
      ],
      correctIndex: 3,
    ),
  ],
);
