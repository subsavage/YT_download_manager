import 'package:flutter/material.dart';
import 'package:youtube_download_manager/services/services.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  TextEditingController _urlController = TextEditingController();
  String? _videoTitle = '';
  String? _videoThumbnail = '';
  List<String>? _resolutions = [];
  double _downloadProgress = 0.0;
  bool _isDownloading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "YouTube Download Manager",
          style: TextStyle(
            fontSize: 18,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  hintText: 'Enter video URL',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  String url = _urlController.text.trim();
                  if (url.isNotEmpty) {
                    var videoInfo = await YouTubeService.fetchVideoInfo(url);
                    setState(() {
                      _videoTitle = videoInfo.title;
                      _videoThumbnail = videoInfo.thumbnailUrl;
                      _resolutions = videoInfo.resolutions;
                    });
                  }
                },
                child: const Text("Fetch Info"),
              ),
              SizedBox(height: 20),
              _videoTitle != null && _videoTitle!.isNotEmpty
                  ? Column(
                      children: [
                        Image.network(_videoThumbnail!),
                        const SizedBox(height: 10),
                        Text(
                          "Title: $_videoTitle",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _isDownloading
                              ? null
                              : () async {
                                  String url = _urlController.text.trim();
                                  if (url.isNotEmpty) {
                                    setState(() {
                                      _isDownloading = true;
                                      _downloadProgress = 0.0;
                                    });

                                    await YouTubeService.downloadVideo(
                                      url,
                                      context,
                                      onProgress: (progress) {
                                        setState(() {
                                          _downloadProgress = progress;
                                        });
                                      },
                                    );

                                    setState(() {
                                      _isDownloading = false;
                                    });
                                  }
                                },
                          child: const Text("Download Video"),
                        ),
                        if (_isDownloading) ...[
                          const SizedBox(height: 20),
                          LinearProgressIndicator(
                            value: _downloadProgress,
                          ),
                          const SizedBox(height: 10),
                          Text(
                              "${(_downloadProgress * 100).toStringAsFixed(0)}% Downloaded"),
                          const Text(
                              "(the video will be saved in your gallery)")
                        ]
                      ],
                    )
                  : Container(),
            ],
          ),
        ),
      ),
    );
  }
}
