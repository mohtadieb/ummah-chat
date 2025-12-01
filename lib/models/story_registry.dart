
import 'package:ummah_chat/stories/sulayman_story.dart';

import '../models/story_data.dart';
import '../stories/nuh_story.dart';
import '../stories/yunus_story.dart';
import '../stories/yusuf_story.dart';
import '../stories/musa_story.dart';
import '../stories/ibrahim_story.dart';


final Map<String, StoryData> allStoriesById = {
  yunusStory.id: yunusStory,
  yusufStory.id: yusufStory,
  musaStory.id: musaStory,
  ibrahimStory.id: ibrahimStory,
  nuhStory.id: nuhStory,
  sulaymanStory.id: sulaymanStory,
};
