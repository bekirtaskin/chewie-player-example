import 'package:chewie/chewie.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hls_parser/flutter_hls_parser.dart';
import 'package:flutter_subtitle/flutter_subtitle.dart' hide Subtitle;
import 'package:video_player/video_player.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final Uri playlistUri = Uri.parse('https://api.castify.me/media/4b722411-3221-40d1-84f5-bedbad7ab140/292b22ed-a6d6-4576-8c66-eb4aca979009.m3u8');

  //Uri.parse('https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4')

  late final VideoPlayerController videoPlayerController = VideoPlayerController.networkUrl(playlistUri);
  final dio = Dio();

  late final ChewieController chewieController;
  SubtitleController? _subtitleController;
  bool isVideoReady = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
    // try {
    //   _controller = VideoPlayerController.network('https://api.castify.me/media/4b722411-3221-40d1-84f5-bedbad7ab140/292b22ed-a6d6-4576-8c66-eb4aca979009.m3u8')
    //     ..initialize().then((_) {
    //       // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
    //       setState(() {});
    //     });
    //   _controller.setVolume(0.0);
    // } catch (e) {
    //   print(e);
    // }
  }

  _initVideo() async {
    await videoPlayerController.initialize();

    // init subtitles
    List<Subtitle> subtitles = [];
    final playlistResponse = await dio.get(playlistUri.toString());
    HlsPlaylist playList = await HlsPlaylistParser.create().parseString(playlistUri, playlistResponse.data);
    if (playList is HlsMasterPlaylist && playList.subtitles.isNotEmpty) {
      var sub1 = playList.subtitles[0];
      final subtitlePlaylistResponse = await dio.get(sub1.url.toString());
      HlsPlaylist subtitlePlaylist = await HlsPlaylistParser.create().parseString(sub1.url!, subtitlePlaylistResponse.data);
      if (subtitlePlaylist is HlsMediaPlaylist && subtitlePlaylist.segments.isNotEmpty) {
        List subtitleUriList = subtitlePlaylist.segments.map((e) {
          var relativeSubtitleURL = e.url;
          Uri subPLUri = Uri.parse(sub1.url!.toString());
          List<String> paths = List.from(sub1.url!.pathSegments, growable: true);
          paths.removeLast();
          paths.add(relativeSubtitleURL!);
          subPLUri = subPLUri.replace(pathSegments: paths);
          return subPLUri.toString();
        }).toList();
        String subtitleAsString = await Stream.fromIterable(subtitleUriList)
            .asyncMap((subtitleUri) => dio.get(subtitleUri))
            .map((subtitleResponse) => subtitleResponse.data as String)
            .join();
        _subtitleController = SubtitleController.string(subtitleAsString, format: SubtitleFormat.webvtt);
        subtitles = _subtitleController!.subtitles.map(
          (e) {
            return Subtitle(
              index: e.number,
              start: Duration(milliseconds: e.start),
              end: Duration(milliseconds: e.end),
              text: e.text,
            );
          },
        ).toList();
      }
    }

    chewieController = ChewieController(
      videoPlayerController: videoPlayerController,
      autoPlay: true,
      looping: true,
      showControls: false,
      showOptions: false,
      subtitle: Subtitles(subtitles),
      subtitleBuilder: (context, subtitle) {
        return IgnorePointer(
          child: SubtitleView(
            text: subtitle,
            subtitleStyle: SubtitleStyle(
              fontSize: chewieController.isFullScreen ? 20 : 16,
            ),
          ),
        );
      },
    );
    videoPlayerController.setVolume(0.0);
    videoPlayerController.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: SizedBox(
          height: 600,
          width: 600,
          child: Stack(
            children: [
              SizedBox(
                height: 600,
                width: 600,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: !videoPlayerController.value.isInitialized
                      ? Container(color: Colors.black)
                      : AspectRatio(
                          aspectRatio: videoPlayerController.value.aspectRatio,
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                                width: videoPlayerController.value.size.width,
                                height: videoPlayerController.value.size.height,
                                child: Chewie(controller: chewieController)),
                          ),
                        ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    videoPlayerController.value.isPlaying ? videoPlayerController.pause() : videoPlayerController.play();
                  });
                },
                child: Container(
                  width: 600,
                  height: 600,
                  color: Colors.transparent,
                ),
              ),
              if (videoPlayerController.value.isInitialized && _subtitleController != null)
                Positioned(
                  bottom: 24,
                  left: 2,
                  right: 2,
                  child: SubtitleControllView(
                    subtitleController: _subtitleController!,
                    inMilliseconds: chewieController.videoPlayerController.value.position.inMilliseconds,
                    backgroundColor: Colors.white,
                    // padding: const EdgeInsets.all(4),
                    subtitleStyle: const SubtitleStyle(
                        bordered: true,
                        fontSize: 20,
                        textColor: Colors.black,
                        borderStyle: SubtitleBorderStyle(strokeWidth: 0.2, style: PaintingStyle.fill)),
                  ),
                ),
              Positioned(
                bottom: 2,
                left: 12,
                right: 12,
                child: VideoProgressIndicator(
                  videoPlayerController,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    backgroundColor: Colors.white10,
                    bufferedColor: Colors.white24,
                    playedColor: Colors.white,
                  ),
                ),
              ),
              if (videoPlayerController.value.isInitialized)
                Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        if (videoPlayerController.value.volume == 0) {
                          videoPlayerController.setVolume(1);
                        } else {
                          videoPlayerController.setVolume(0);
                        }
                        setState(() {});
                      },
                      child: videoPlayerController.value.volume == 0
                          ? const Icon(
                              Icons.volume_off,
                              color: Colors.white,
                            )
                          : const Icon(
                              Icons.volume_up,
                              color: Colors.white,
                            ),
                    ))
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            videoPlayerController.value.isPlaying ? videoPlayerController.pause() : videoPlayerController.play();
          });
        },
        tooltip: 'Increment',
        child: videoPlayerController.value.isPlaying ? const Icon(Icons.pause_circle) : const Icon(Icons.play_circle),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
