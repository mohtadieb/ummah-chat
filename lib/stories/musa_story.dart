// lib/pages/musa_story.dart  (or lib/stories/musa_story.dart if you prefer)
import 'package:flutter/material.dart';
import '../models/storyData.dart';
import 'stories_page.dart';

const StoryData musaStory = StoryData(
  id: 'musa',
  appBarTitle: 'Prophet Musa (as)',
  chipLabel: 'Prophet Musa (as)',
  title: 'The Story of Prophet Musa (as)',
  subtitle: 'Trust in Allah, courage and steadfastness',
  icon: Icons.landscape_rounded, // 🆕 DIFFERENT BADGE ICON
  cardPreview: 'The prophet who faced Pharaoh, parted the sea, and led his people with courage.',
  body:
  'Prophet Musa (peace be upon him) was born in Egypt at a time when Pharaoh was a cruel ruler. '
      'Pharaoh feared that a boy from the Children of Israel would one day challenge his power, so he ordered '
      'that newborn boys from Bani Isra’il be killed.\n\n'
      'Allah inspired the mother of baby Musa (as) to place him in a small basket and set it afloat on the river. '
      'She did this with a heart full of fear, but also full of trust in Allah. Allah caused the basket to float safely '
      'until it reached the palace of Pharaoh. There, the wife of Pharaoh, Asiyah (may Allah be pleased with her), found the baby. '
      'She felt mercy and love for him and convinced Pharaoh to let the child live and be raised in the palace.\n\n'
      'Thus, Musa (as) grew up under the care of Allah, in the house of the very man who wanted to kill boys like him. '
      'When he grew older and stronger, he saw the injustice that Pharaoh and his people were doing to the Children of Israel. '
      'One day, Musa (as) saw a man from his own people being attacked by an Egyptian. Musa (as) intervened and struck the Egyptian, '
      'but the man died from the blow. Musa (as) did not intend to kill him. He immediately turned to Allah, asking for forgiveness. '
      'Allah forgave him.\n\n'
      'After this, Musa (as) left Egypt in fear and travelled to the land of Madyan. There he helped two sisters who were struggling '
      'to water their animals, while others pushed ahead of them. He moved the heavy stone from the well for them, showing strength and good manners. '
      'Later, he was invited to their home and eventually married one of them. He stayed in Madyan for several years, living a simple, honest life.\n\n'
      'One day, as he was travelling back towards Egypt with his family, Musa (as) saw a fire on the side of a mountain. '
      'He went towards it and there, at Mount Tur, Allah spoke to him. Allah chose him as a messenger and ordered him to go to Pharaoh '
      'and call him to worship Allah alone, to free the Children of Israel and to stop his oppression.\n\n'
      'Musa (as) felt afraid and shy, and he asked Allah to strengthen him and to make his brother Harun (as) a helper for him. '
      'Allah accepted his dua and gave him miracles. One miracle was that his staff (stick) would turn into a real snake by Allah’s permission. '
      'Another was that his hand would shine with a bright light when he took it out from under his arm.\n\n'
      'With these signs, Musa (as) went to Pharaoh and spoke calmly but clearly: to worship Allah alone and to be just. '
      'Pharaoh became arrogant and refused. He called the magicians of Egypt to challenge Musa (as). The magicians threw their ropes and sticks,'
      'and they looked like moving snakes. By Allah’s command, Musa (as) threw down his staff, and it turned into a real snake '
      'that swallowed all their tricks. The magicians realized that this was not magic, but a true miracle from Allah. They believed in Allah '
      'and fell in prostration, even though Pharaoh threatened them.\n\n'
      'After many signs and punishments sent to Pharaoh and his people, they still refused to believe. '
      'Allah then commanded Musa (as) to lead the Children of Israel out of Egypt. They travelled at night, heading towards the sea. '
      'When they reached the water, they saw Pharaoh and his army chasing them from behind. Some of Bani Isra’il panicked and said, '
      '“We are surely caught!” But Musa (as) replied with full trust in Allah: “No! Indeed, my Lord is with me; He will guide me.”\n\n'
      'Allah then commanded Musa (as) to strike the sea with his staff. The sea split into paths, standing like great walls of water, '
      'and the ground became dry. Musa (as) and his people crossed safely. When Pharaoh and his army tried to follow, the sea closed in on them, '
      'and they were drowned.\n\n'
      'From the story of Prophet Musa (as), we learn to trust Allah even in the most difficult situations, '
      'to stand up against injustice, and to be brave while keeping our hearts connected to Allah. '
      'We also learn that Allah can open a way out from places we could never imagine—just like He opened a path through the sea.',
  questions: [
    QuizQuestion(
      question: 'Why did Pharaoh order that baby boys from Bani Isra’il be killed?',
      options: [
        'He was afraid they would become too kind',
        'He feared a boy would one day threaten his power',
        'He wanted to make the families richer',
        'He needed soldiers for his army',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
      'What did the mother of Musa (as) do when she feared for his safety?',
      options: [
        'She hid him in a cave',
        'She left him in the desert',
        'She placed him in a basket and put him in the river',
        'She took him to another country',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'Who found baby Musa (as) by the river?',
      options: [
        'A shepherd',
        'The wife of Pharaoh',
        'A soldier',
        'A group of children',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
      'What happened when Musa (as) tried to help the man from his people in Egypt?',
      options: [
        'He was made a minister',
        'Nothing happened',
        'The Egyptian man died from Musa’s strike',
        'They both became friends',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'Where did Musa (as) go after leaving Egypt?',
      options: [
        'To Makkah',
        'To Madyan',
        'To Jerusalem',
        'To a nearby village',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
      'What special event happened to Musa (as) at Mount Tur (the mountain)?',
      options: [
        'He found treasure',
        'He became a king',
        'Allah spoke to him and chose him as a messenger',
        'He built a house there',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'Which miracle did Allah give to Musa (as) with his staff (stick)?',
      options: [
        'It became very heavy',
        'It turned into a snake by Allah’s permission',
        'It disappeared',
        'It became gold',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
      'How did Musa (as) and Bani Isra’il escape from Pharaoh and his army?',
      options: [
        'They built boats',
        'They climbed over a mountain',
        'The sea split into paths for them by Allah’s command',
        'They hid in caves',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'What did Musa (as) say when his people thought they were trapped at the sea?',
      options: [
        '“We are lost forever.”',
        '“Run in every direction!”',
        '“No! My Lord is with me; He will guide me.”',
        '“Let us surrender to Pharaoh.”',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'What is one key lesson from the story of Prophet Musa (as)?',
      options: [
        'That we should never travel',
        'That we can only rely on ourselves',
        'That Allah can open a way out, even when things seem impossible',
        'That might and injustice always win',
      ],
      correctIndex: 2,
    ),
  ],
);
