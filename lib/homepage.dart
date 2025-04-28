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
      appBar: AppBar(title: Text("YouTube Video Downloader")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  hintText: 'Enter YouTube video URL',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
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
                child: Text("Fetch Video Info"),
              ),
              SizedBox(height: 20),
              _videoTitle != null && _videoTitle!.isNotEmpty
                  ? Column(
                      children: [
                        Image.network(_videoThumbnail!),
                        Text("Title: $_videoTitle"),
                        Text("Available Resolutions:"),
                        for (var resolution in _resolutions!)
                          Text("- $resolution"),
                        SizedBox(height: 20),
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
                          child: Text("Download Video"),
                        ),
                        if (_isDownloading) ...[
                          SizedBox(height: 20),
                          LinearProgressIndicator(
                            value: _downloadProgress,
                          ),
                          SizedBox(height: 10),
                          Text(
                              "${(_downloadProgress * 100).toStringAsFixed(0)}% Downloaded"),
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
