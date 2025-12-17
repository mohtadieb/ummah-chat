
import 'package:ummah_chat/stories/ayyub_story.dart';
import 'package:ummah_chat/stories/harun_story.dart';
import 'package:ummah_chat/stories/idris_story.dart';
import 'package:ummah_chat/stories/ishaq_story.dart';
import 'package:ummah_chat/stories/maryam_story.dart';
import 'package:ummah_chat/stories/muhammad_story_part_1.dart';
import 'package:ummah_chat/stories/sulayman_story.dart';
import 'package:ummah_chat/stories/zakariya_story.dart';

import '../models/story_data.dart';
import '../stories/adam_story.dart';
import '../stories/alyasa_story.dart';
import '../stories/dawud_story.dart';
import '../stories/dhulkifl_story.dart';
import '../stories/hud_story.dart';
import '../stories/ilyas_story.dart';
import '../stories/isa_story.dart';
import '../stories/ismail_story.dart';
import '../stories/lut_story.dart';
import '../stories/muhammad_story_part_2.dart';
import '../stories/muhammad_story_part_3.dart';
import '../stories/muhammad_story_part_4.dart';
import '../stories/muhammad_story_part_5.dart';
import '../stories/muhammad_story_part_6.dart';
import '../stories/muhammad_story_part_7.dart';
import '../stories/nuh_story.dart';
import '../stories/salih_story.dart';
import '../stories/shuayb_story.dart';
import '../stories/yahya_story.dart';
import '../stories/yaqub_story.dart';
import '../stories/yunus_story.dart';
import '../stories/yusuf_story.dart';
import '../stories/musa_story.dart';
import '../stories/ibrahim_story.dart';


final Map<String, StoryData> allStoriesById = {
  // Early prophets
  adamStory.id: adamStory,
  idrisStory.id: idrisStory,
  nuhStory.id: nuhStory,
  hudStory.id: hudStory,
  salihStory.id: salihStory,

  // Ibrahim family
  ibrahimStory.id: ibrahimStory,
  lutStory.id: lutStory,
  ismailStory.id: ismailStory,
  ishaqStory.id: ishaqStory,
  yaqubStory.id: yaqubStory,
  yusufStory.id: yusufStory,

  // Other nations
  shuaybStory.id: shuaybStory,
  ayyubStory.id: ayyubStory,
  dhulKiflStory.id: dhulKiflStory,

  // Musa era
  musaStory.id: musaStory,
  harunStory.id: harunStory,

  // Kings & prophets
  dawudStory.id: dawudStory,
  sulaymanStory.id: sulaymanStory,
  ilyasStory.id: ilyasStory,
  alyasaStory.id: alyasaStory,
  yunusStory.id: yunusStory,

  // Later prophets
  zakariyaStory.id: zakariyaStory,
  yahyaStory.id: yahyaStory,
  maryamStory.id: maryamStory,
  isaStory.id: isaStory,

  // Final Messenger ﷺ
  muhammadPart1Story.id: muhammadPart1Story,
  muhammadPart2Story.id: muhammadPart2Story,
  muhammadPart3Story.id: muhammadPart3Story,
  muhammadPart4Story.id: muhammadPart4Story,
  muhammadPart5Story.id: muhammadPart5Story,
  muhammadPart6Story.id: muhammadPart6Story,
  muhammadPart7Story.id: muhammadPart7Story,
};
