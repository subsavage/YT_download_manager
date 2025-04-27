import 'package:flutter/material.dart';
import 'package:youtube_download_manager/models/models.dart';
import 'package:youtube_download_manager/services/services.dart';

class Homepage extends StatefulWidget {
  @override
  _HomepageState createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  final TextEditingController _urlController = TextEditingController();
  VideoInfo? _videoInfo;
  String? _selectedResolution;
  double _progress = 0;
  bool _isDownloading = false;
  String? _errorMessage;

  Future<void> _fetchVideoInfo() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Please paste a YouTube URL.')));
      return;
    }

    try {
      final videoInfo = await YouTubeService.fetchVideoInfo(url);
      setState(() {
        _videoInfo = videoInfo;
        _selectedResolution = videoInfo.resolutions.first;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to fetch video info. Please check the URL.';
        _videoInfo = null;
      });
    }
  }

  Future<void> _startDownload() async {
    if (_videoInfo == null || _selectedResolution == null) return;

    setState(() {
      _isDownloading = true;
      _progress = 0;
    });

    try {
      await YouTubeService.downloadVideo(
        _urlController.text.trim(),
        _selectedResolution!,
        (received, total) {
          setState(() {
            _progress = received / total;
          });
        },
      );
      setState(() {
        _isDownloading = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Download completed!')));
    } catch (e) {
      setState(() {
        _isDownloading = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Download failed.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('YouTube Downloader')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'YouTube Video URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchVideoInfo,
              child: Text('Fetch Video Info'),
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null) ...[
              Text(_errorMessage!, style: TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
            ],
            if (_videoInfo != null) ...[
              Text(_videoInfo!.title,
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Image.network(_videoInfo!.thumbnailUrl, height: 150),
              const SizedBox(height: 16),
              DropdownButton<String>(
                value: _selectedResolution,
                items: _videoInfo!.resolutions
                    .map((res) => DropdownMenuItem<String>(
                          value: res,
                          child: Text(res),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedResolution = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              _isDownloading
                  ? Column(
                      children: [
                        LinearProgressIndicator(value: _progress),
                        const SizedBox(height: 8),
                        Text(
                            '${(_progress * 100).toStringAsFixed(0)}% downloaded'),
                      ],
                    )
                  : ElevatedButton(
                      onPressed: _startDownload,
                      child: Text('Download Video'),
                    ),
            ],
          ],
        ),
      ),
    );
  }
}
