import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flick_video_player/flick_video_player.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';

const String apiKey = 'AIzaSyDG1K6tv_R-kArXgfTWRuA-NWR1jPjYmZ8';
 final FlutterFFmpeg _flutterFFmpeg = FlutterFFmpeg();

Future<List<Map<String, String>>> searchYouTube(String query) async {
  final response = await http.get(Uri.parse(
      'https://www.googleapis.com/youtube/v3/search?part=snippet&q=$query&type=video&key=$apiKey'));

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final videos = data['items'];
    List<Map<String, String>> videoDetails = [];
    for (var video in videos) {
      videoDetails.add({
        'title': video['snippet']['title'],
        'videoId': video['id']['videoId']
      });
    }
    return videoDetails;
  } else {
    print('Failed to fetch videos: ${response.statusCode} ${response.body}');
    return [];
  }
}

Future<File> convertToMP3(File videoFile, String videoTitle, Directory directory) async {
  var mp3FilePath = '${directory.path}/${videoTitle.replaceAll('.mp4', '.mp3')}';
  var mp3File = File(mp3FilePath);
  var command = '-i ${videoFile.path} -q:a 0 -map a $mp3FilePath';
   int result = await _flutterFFmpeg.execute(command);
  if (result == 0) {
    print('Conversion successful: $mp3FilePath');
  } else {
    print('Conversion failed with code: $result');
  }
  return mp3File;
}


Future<void> downloadVideo(String videoId, String videoTitle, ValueNotifier<bool> isDownloading, ValueNotifier<bool> isDownloaded) async {
  var yt = YoutubeExplode();
  var isDownloadedSuccessfully = false;

  try {
    isDownloading.value = true;
    isDownloaded.value = false;

    // Get the video metadata.
    var video = await yt.videos.get(videoId);
    var manifest = await yt.videos.streamsClient.getManifest(videoId);

    // Choose the best audio-only stream if available, else fallback to the best video stream.
    var streamInfo = manifest.audioOnly.withHighestBitrate();

    // Get the application documents directory.
    var directory = await getApplicationDocumentsDirectory();
    var downloadsDirectory = Directory('${directory.path}/downloads');

    // Create the downloads directory if it does not exist.
    if (!downloadsDirectory.existsSync()) {
      downloadsDirectory.createSync();
    }

    // Open the file to write the video/audio.
    var file = File('${downloadsDirectory.path}/${videoTitle}.mp4');
    var fileStream = file.openWrite();

    // Download the video/audio.
    var stream = yt.videos.streamsClient.get(streamInfo);
    await stream.pipe(fileStream);

    // Close the file.
    await fileStream.flush();
    await fileStream.close();

    print('Video/audio downloaded to ${file.path}');

    //Convert to MP3 if necessary
    if (!videoTitle.endsWith('.mp3') && streamInfo is MuxedStreamInfo) {
      var mp3FilePath = '${downloadsDirectory.path}/${videoTitle.replaceAll('.mp4', '.mp3')}';
      var mp3File = File(mp3FilePath);
      var command = '-i ${file.path} -q:a 0 -map a $mp3FilePath';
       int result = await _flutterFFmpeg.execute(command);
      if (result == 0) {
        print('Conversion successful: $mp3FilePath');
        file = mp3File;
        videoTitle = videoTitle.replaceAll('.mp4', '.mp3');
      } else {
        print('Conversion failed with code: $result');
      }
    }

    // Ensure the file exists before uploading
    if (file.existsSync()) {
      // Upload the video/audio to Firebase Storage.
      var storageRef = FirebaseStorage.instance.ref().child('videos/$videoTitle');
      var uploadTask = storageRef.putFile(file);
      var snapshot = await uploadTask.whenComplete(() => {});

      // Get the download URL of the uploaded video/audio.
      var downloadUrl = await snapshot.ref.getDownloadURL();

      // Add video/audio metadata to Firebase Firestore.
      await FirebaseFirestore.instance.collection('downloadedVideos').add({
        'title': videoTitle,
        'path': file.path,
        'url': 'https://www.youtube.com/watch?v=$videoId',
        'author': video.author,
        'duration': video.duration?.toString() ?? 'Unknown',
        'storageUrl': downloadUrl,
      });

      print('Video/audio downloaded and metadata stored in Firebase Firestore');
      isDownloadedSuccessfully = true;
      isDownloaded.value = true;
    } else {
      print('File does not exist: ${file.path}');
    }
  } catch (e) {
    print('An error occurred: $e');
  } finally {
    // Dispose of the YoutubeExplode instance.
    yt.close();
    isDownloading.value = false;

    if (!isDownloadedSuccessfully) {
      // Handle unsuccessful download
      print('Download unsuccessful for $videoTitle');
    }
  }
}

class MediaVaultHomePage extends StatefulWidget {
  @override
  _MediaVaultHomePageState createState() => _MediaVaultHomePageState();
}

class _MediaVaultHomePageState extends State<MediaVaultHomePage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, String>> _videos = [];

  void _search() async {
    final query = _searchController.text;
    if (query.isNotEmpty) {
      final results = await searchYouTube(query);
      setState(() {
        _videos = results;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Media Vault'),
        actions: [
          IconButton(
            icon: Icon(Icons.video_library),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DownloadedVideosPage()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Media Vault',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32.0,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: Icon(Icons.search, color: Theme.of(context).hintColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              onSubmitted: (value) => _search(),
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _videos.length,
                itemBuilder: (context, index) {
                  final video = _videos[index];
                  final isDownloading = ValueNotifier<bool>(false);
                  final isDownloaded = ValueNotifier<bool>(false);

                  return ListTile(
                    title: Text(video['title']!),
                    trailing: ValueListenableBuilder<bool>(
                      valueListenable: isDownloading,
                      builder: (context, downloading, child) {
                        return downloading
                            ? CircularProgressIndicator()
                            : ValueListenableBuilder<bool>(
                          valueListenable: isDownloaded,
                          builder: (context, downloaded, child) {
                            return downloaded
                                ? Icon(Icons.check, color: Colors.green)
                                : IconButton(
                              icon: Icon(Icons.download),
                              onPressed: () async {
                                await downloadVideo(
                                    video['videoId']!,
                                    video['title']!,
                                    isDownloading,
                                    isDownloaded);
                              },
                            );
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class DownloadedVideosPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Downloaded Videos'),
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('downloadedVideos')
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
                child: Text('Error loading videos: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No videos found'));
          } else {
            var videos = snapshot.data!.docs;
            return ListView.builder(
              itemCount: videos.length,
              itemBuilder: (context, index) {
                var video = videos[index];
                return ListTile(
                  title: Text(video['title']),
                  subtitle: Text(video['author']),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            VideoPlayerScreen(
                              videoUrl: video['storageUrl'],
                            ),
                      ),
                    );
                  },
                  trailing: IconButton(
                    icon: Icon(Icons.delete),
                    onPressed: () async {
                      await _deleteVideo(video.reference.id, video['title']);
                    },
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }

  Future<void> _deleteVideo(String docId, String videoTitle) async {
    try {
      // Delete from Firebase Storage
      await FirebaseStorage.instance.ref().child('videos/$videoTitle').delete();

      // Delete from Firestore
      await FirebaseFirestore.instance.collection('downloadedVideos')
          .doc(docId)
          .delete();

      print('Video $videoTitle deleted successfully');
    } catch (e) {
      print('Error deleting video: $e');
      // Handle error
    }
  }

}



  class JustAudio extends StatefulWidget {
  const JustAudio({Key? key}) : super(key: key);

  @override
  State<JustAudio> createState() => _JustAudioState();
}

class _JustAudioState extends State<JustAudio> {
  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playAudio(String audioUrl) async {
    try {
      await _audioPlayer.setUrl(audioUrl);
      await _audioPlayer.play();
    } catch (e) {
      // Handle errors
      print('Failed to play audio: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Just Audio'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // Replace with your downloaded video's audio URL
            String audioUrl = 'https://www.example.com/path/to/downloaded_audio.mp3';
            _playAudio(audioUrl);
          },
          child: Text('Play Audio'),
        ),
      ),
    );
  }
}



class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;

  VideoPlayerScreen({required this.videoUrl});

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late FlickManager flickManager;

  @override
  void initState() {
    super.initState();
    flickManager = FlickManager(
      videoPlayerController: VideoPlayerController.network(widget.videoUrl),
    );
  }

  @override
  void dispose() {
    flickManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Video Player'),
      ),
      body: Center(
        child: FlickVideoPlayer(
          flickManager: flickManager,
        ),
      ),
    );
  }
}





class AudioPlayerScreen extends StatefulWidget {
  final String audioUrl;

  AudioPlayerScreen({required this.audioUrl});

  @override
  _AudioPlayerScreenState createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initAudioPlayer();
  }

  void _initAudioPlayer() async {
    try {
      await _audioPlayer.setUrl(widget.audioUrl);
      _audioPlayer.playerStateStream.listen((state) {
        if (state.playing) {
          setState(() {
            _isPlaying = true;
          });
        } else {
          setState(() {
            _isPlaying = false;
          });
        }
      });
    } catch (e) {
      // Handle errors
      print('Failed to play audio: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Audio Player'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(_isPlaying ? 'Playing Audio' : 'Audio Paused'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (_isPlaying) {
                  await _audioPlayer.pause();
                } else {
                  await _audioPlayer.play();
                }
              },
              child: Text(_isPlaying ? 'Pause' : 'Play'),
            ),
          ],
        ),
      ),
    );
  }
}