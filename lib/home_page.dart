import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flick_video_player/flick_video_player.dart';
import 'package:video_player/video_player.dart';

const String apiKey = 'AIzaSyDG1K6tv_R-kArXgfTWRuA-NWR1jPjYmZ8';

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

Future<void> downloadVideo(String videoId, String videoTitle, ValueNotifier<bool> isDownloading, ValueNotifier<bool> isDownloaded) async {
  var yt = YoutubeExplode();
  var isDownloadedSuccessfully = false;

  try {
    isDownloading.value = true;
    isDownloaded.value = false;

    // Get the video metadata.
    var video = await yt.videos.get(videoId);
    var manifest = await yt.videos.streamsClient.getManifest(videoId);
    var streamInfo = manifest.muxed.withHighestBitrate();

    // Get the application documents directory.
    var directory = await getApplicationDocumentsDirectory();
    var downloadsDirectory = Directory('${directory.path}/downloads');

    // Create the downloads directory if it does not exist.
    if (!downloadsDirectory.existsSync()) {
      downloadsDirectory.createSync();
    }

    // Open the file to write the video.
    var file = File('${downloadsDirectory.path}/${videoTitle}.mp4');
    var fileStream = file.openWrite();

    // Download the video.
    var stream = yt.videos.streamsClient.get(streamInfo);
    await stream.pipe(fileStream);

    // Close the file.
    await fileStream.flush();
    await fileStream.close();

    // Convert to MP3 if necessary
    if (!videoTitle.endsWith('.mp3')) {
      var mp3File = await convertToMP3(file, videoTitle, downloadsDirectory);
      file = mp3File;
      videoTitle = videoTitle.replaceAll('.mp4', '.mp3');
    }

    // Ensure the file exists before uploading
    if (file.existsSync()) {
      // Upload the video to Firebase Storage.
      var storageRef = FirebaseStorage.instance.ref().child('videos/${videoTitle}');
      var uploadTask = storageRef.putFile(file);
      var snapshot = await uploadTask.whenComplete(() => {});

      // Get the download URL of the uploaded video.
      var downloadUrl = await snapshot.ref.getDownloadURL();

      // Add video metadata to Firebase Firestore.
      await FirebaseFirestore.instance.collection('downloadedVideos').add({
        'title': videoTitle,
        'path': file.path,
        'url': 'https://www.youtube.com/watch?v=$videoId',
        'author': video.author,
        'duration': video.duration?.toString() ?? 'Unknown',
        'storageUrl': downloadUrl,
      });

      print('Video downloaded and metadata stored in Firebase Firestore');
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


Future<File> convertToMP3(File videoFile, String videoTitle, Directory directory) async {
  var mp3FilePath = '${directory.path}/${videoTitle}.mp3';
  var mp3File = File(mp3FilePath);

  return mp3File;
}

class MediaVaultHomePage extends StatefulWidget {
  @override
  _MediaVaultHomePageState createState() => _MediaVaultHomePageState();
}

class _MediaVaultHomePageState extends State<MediaVaultHomePage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, String>> _videos = [];
  ScaffoldMessengerState? scaffoldMessenger;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    scaffoldMessenger = ScaffoldMessenger.of(context);
  }

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
                                scaffoldMessenger?.showSnackBar(SnackBar(
                                  content: Text(
                                      'Downloading ${video['title']}'),
                                ));
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


class DownloadedVideosPage extends StatefulWidget {
  @override
  _DownloadedVideosPageState createState() => _DownloadedVideosPageState();
}

class _DownloadedVideosPageState extends State<DownloadedVideosPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Downloaded Videos'),
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('downloadedVideos').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error loading videos: ${snapshot.error}'));
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
                        builder: (context) => VideoPlayerScreen(
                          videoUrl: video['storageUrl'],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          }
        },
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
      videoPlayerController: VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl)),
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
