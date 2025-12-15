// lib/stories/ibrahim_story.dart
import 'package:flutter/material.dart';
import '../models/story_data.dart';
import '../pages/stories_page.dart';

const StoryData ibrahimStory = StoryData(
  id: 'ibrahim',
  appBarTitle: 'Prophet Ibrahim (as)',
  chipLabel: 'Prophet Ibrahim (as)',
  title: 'The Story of Prophet Ibrahim (as)',
  subtitle: 'Pure tawheed, great tests, and building the Kaaba',
  icon: Icons.local_fire_department_rounded, // 🔥 fire miracle + strength
  cardPreview:
  'The prophet who challenged idol worship, survived the fire, left his family in the desert for Allah, and built the Kaaba with his son.',
  body:
  'Prophet Ibrahim (peace be upon him) is one of the greatest messengers of Allah and is called “Khalilullah” – the close friend of Allah. '
      'He is known for his pure belief in one God (tawheed), his courage, and his complete trust in Allah during very difficult tests.\n\n'
      'Ibrahim (as) grew up in a society where people worshipped idols, stars, the sun, and the moon. Even his own father made idols. '
      'But from a young age, Ibrahim (as) questioned everything around him. He watched the stars appear at night and disappear at dawn. '
      'He saw the moon shining and then fading, the sun rising and then setting. He realised that anything that disappears cannot be a true god. '
      'He understood that the real God must be the One who created all of these things and never disappears.\n\n'
      'He began to speak to his people with wisdom and questions. He asked them why they worshipped statues that could not hear, see, or help themselves. '
      'He tried gently to show his father the truth, but his father refused and even threatened him. Still, Ibrahim (as) stayed respectful and said he would pray for his father.\n\n'
      'One day, when the people left the town for a festival, Ibrahim (as) went to the place where the idols stood. '
      'He broke the smaller idols and left only the biggest one standing. He hung the axe on the big idol. When the people returned, they were shocked. '
      'They asked who had done this. Ibrahim (as) told them to ask the big idol – if it could speak. They understood, deep down, that idols could not do anything, '
      'but their pride stopped many of them from accepting the truth.\n\n'
      'The leaders became very angry and decided to punish Ibrahim (as). They built a huge fire, so hot that they had to catapult him into it. '
      'In that moment, Ibrahim (as) turned his heart completely to Allah. Allah then commanded the fire: “O fire, be coolness and safety for Ibrahim.” '
      'The fire did not burn him at all. He came out unharmed, a clear sign from Allah that He protects those who trust Him.\n\n'
      'After this, Ibrahim (as) migrated for the sake of Allah. He travelled to other lands and continued calling people to worship Allah alone. '
      'For many years, he and his wife Sarah (as) did not have children. Later, Allah blessed him with two sons: Ismail (as) and Ishaq (as), peace be upon them both. '
      'They would also become prophets and fathers of prophets.\n\n'
      'Allah tested Ibrahim (as) with another very great trial. He commanded him to take Hajar (Hagar, as) and baby Ismail (as) to a barren valley – '
      'what would later become Makkah. There were no trees, no water, and no people. Ibrahim (as) left them there by Allah’s command. '
      'When Hajar (as) asked if Allah had ordered this, and he nodded yes, she replied with trust: that Allah would not abandon them.\n\n'
      'When the food and water ran out, baby Ismail (as) cried from thirst. Hajar (as) ran between the hills of Safa and Marwah, searching for help, '
      'seven times back and forth, full of worry but also trust in Allah. Allah then caused the water of Zamzam to spring out from under the feet of baby Ismail (as). '
      'This blessed water still flows in Makkah today, and the running between Safa and Marwah became part of the Hajj and Umrah rituals.\n\n'
      'Later, when Ismail (as) was older, Allah gave Ibrahim (as) another test. In a dream, he saw that he was sacrificing his son. '
      'Dreams of the prophets are a form of revelation, so he knew this was a command from Allah. He spoke to Ismail (as) about it. '
      'Ismail (as), showing his own faith, told his father to do what Allah had commanded and that he would be patient.\n\n'
      'When they both submitted to Allah’s will and Ibrahim (as) placed his son down in obedience, Allah called out to him and stopped the sacrifice. '
      'Ismail (as) was replaced with a ram, and Allah made it clear that the test was about their sincerity and obedience, not about the actual sacrifice. '
      'This event is remembered every year during Eid al-Adha.\n\n'
      'Another great honour given to Ibrahim (as) was the building of the Kaaba. Allah commanded Ibrahim (as) and his son Ismail (as) to raise the foundations of the House in Makkah. '
      'They built the Kaaba together as a place where people would worship Allah alone. While building, they made dua: that Allah accept their work, make them obedient to Him, '
      'and send a messenger from among their descendants to teach people the Book and wisdom. This dua was fulfilled when Prophet Muhammad (peace be upon him) was sent.\n\n'
      'Allah also ordered Ibrahim (as) to call people to Hajj, even though the valley was empty at that time. He obeyed, and Allah caused that call to reach the hearts of people across the world. '
      'Until today, millions of Muslims travel to Makkah every year answering that same call.\n\n'
      'Throughout his life, Ibrahim (as) made beautiful duas that are mentioned in the Qur’an: for a righteous family, for a safe city of Makkah, and for forgiveness for himself and his children. '
      'He remained humble, grateful, and devoted to Allah in every situation.\n\n'
      'From the story of Prophet Ibrahim (as), we learn that true faith means trusting Allah completely, even when His commands are difficult. '
      'We learn that sacrifice and patience bring us closer to Allah, that tawheed is the heart of our religion, and that Allah never abandons those who sincerely obey Him.',
  questions: [
    QuizQuestion(
      question: 'Why did Prophet Ibrahim (as) reject the worship of stars, the moon and the sun?',
      options: [
        'Because they were not beautiful enough',
        'Because he saw that they appear and disappear and cannot be the true God',
        'Because his friends told him to stop',
        'Because they did not give him what he wanted',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: 'How did Ibrahim (as) show his people that their idols were weak?',
      options: [
        'He hid all the idols underground',
        'He destroyed the smaller idols and left the biggest one with an axe on it',
        'He painted all the idols black',
        'He moved the idols to another city',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: 'What happened when Ibrahim (as) was thrown into the huge fire?',
      options: [
        'The fire burned him badly',
        'He escaped before he fell in',
        'The fire became cool and safe for him by Allah’s command',
        'The people stopped the punishment at the last second',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'Why did Ibrahim (as) take Hajar (as) and baby Ismail (as) to the empty valley?',
      options: [
        'Because there was a big city there',
        'Because there was a river and many trees',
        'Because he wanted to travel for business',
        'Because Allah commanded him, and he trusted Allah completely',
      ],
      correctIndex: 3,
    ),
    QuizQuestion(
      question:
      'What did Hajar (as) do when the water and food finished and baby Ismail (as) was crying?',
      options: [
        'She sat still and waited',
        'She ran between Safa and Marwah searching for help and trusting Allah',
        'She left the baby and went far away',
        'She shouted at Ibrahim (as)',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: 'How did the water of Zamzam appear?',
      options: [
        'It started raining heavily',
        'A river came from the mountains',
        'Allah caused water to spring from under the feet of baby Ismail (as)',
        'People dug a very deep well by themselves',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'What was the test that Ibrahim (as) saw in his dream about his son Ismail (as)?',
      options: [
        'To send him away to another land',
        'To sacrifice him for the sake of Allah',
        'To build a house for him',
        'To make him a king',
      ],
      correctIndex: 1,
    ),
    QuizQuestion(
      question:
      'What did Allah do when Ibrahim (as) and Ismail (as) both submitted to the sacrifice?',
      options: [
        'Allah let the sacrifice happen',
        'Allah turned Ismail (as) into an angel',
        'Allah replaced Ismail (as) with a ram and saved him',
        'Allah made them return to Egypt',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'What great building did Ibrahim (as) and Ismail (as) raise together in Makkah?',
      options: [
        'Masjid Al-Aqsa',
        'A large palace for the king',
        'The Kaaba, the House of Allah',
        'A market for traders',
      ],
      correctIndex: 2,
    ),
    QuizQuestion(
      question:
      'What is one key lesson from the full story of Prophet Ibrahim (as)?',
      options: [
        'That faith is only in the heart and never needs actions',
        'That true faith is to obey Allah with trust and patience, even in hard tests',
        'That we should never move to another place',
        'That wealth is the main sign of Allah’s love',
      ],
      correctIndex: 1,
    ),
  ],
);
