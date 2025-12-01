// lib/models/profile_song.dart

class ProfileSong {
  final String id;        // what we store in the DB (e.g. "calm_1")
  final String title;     // display name in the UI
  final String artist;    // e.g. "Ummah Chat"
  final String assetPath; // path used by just_audio

  const ProfileSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.assetPath,
  });
}

/// All available profile songs.
/// For now, all 3 map to the *same working file* to verify playback.
const List<ProfileSong> kProfileSongs = [
  ProfileSong(
    id: 'calm_1',
    title: 'Ambient',
    artist: 'Sufi Sama',
    assetPath: 'assets/audio/profile_song_1.wav',
  ),
  ProfileSong(
    id: 'soft_2',
    title: 'Nasheed',
    artist: 'Abdul Miah',
    assetPath: 'assets/audio/profile_song_2.mp3',
  ),
  ProfileSong(
    id: 'uplift_3',
    title: 'Sacred Echo',
    artist: 'Makrifat',
    assetPath: 'assets/audio/profile_song_3.mp3',
  ),
  ProfileSong(
    id: 'arabic_4',
    title: 'Islamic Background',
    artist: 'Omar Faruque',
    assetPath: 'assets/audio/profile_song_4.mp3',
  ),
  ProfileSong(
    id: 'arabic_5',
    title: 'Arabic Islamic',
    artist: 'Mykola Odnoroh',
    assetPath: 'assets/audio/profile_song_5.mp3',
  ),
  ProfileSong(
    id: 'arabic_6',
    title: 'Arabic Islamic 2',
    artist: 'Mykola Odnoroh',
    assetPath: 'assets/audio/profile_song_6.mp3',
  ),
  ProfileSong(
    id: 'islamic_7',
    title: 'Islamic beats',
    artist: 'Omar Faruque',
    assetPath: 'assets/audio/profile_song_7.mp3',
  ),
];
