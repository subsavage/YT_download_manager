import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_download_manager/models/models.dart';
import 'package:youtube_download_manager/services/services.dart';
import 'dart:io' show Platform;

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

  Future<bool> _ensurePermissions() async {
    if (Platform.isAndroid) {
      // Legacy storage (API ≤29)
      if (await Permission.storage.isDenied) {
        await Permission.storage.request();
      }
      // All-files access (API ≥30)
      if (await Permission.manageExternalStorage.isDenied) {
        // This DOES NOT show a dialog on Android 11+ —
        // you must send users to Settings:
        bool opened = await openAppSettings();
        return false;
      }
      return await Permission.manageExternalStorage.isGranted ||
          await Permission.storage.isGranted;
    } else if (Platform.isIOS) {
      // Request photo-library permission
      PermissionStatus status = await Permission.photos.request();
      return status.isGranted;
    }
    return false;
  }

  Future<void> _fetchVideoInfo() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Please paste a YouTube URL.')));
      return;
    }

    try {
      final videoInfo = await YouTubeService.fetchVideoInfo(url);
      print("Fetched video info: ${videoInfo.title}");
      setState(() {
        _videoInfo = videoInfo;
        _selectedResolution = videoInfo.resolutions.isNotEmpty
            ? videoInfo.resolutions.first
            : null;
        _errorMessage = null;
      });
    } catch (e) {
      print("Error fetching video info: $e");
      setState(() {
        _errorMessage = 'Failed to fetch video info. Please check the URL.';
        _videoInfo = null;
      });
    }
  }

  Future<void> _startDownload() async {
    // Request permissions properly based on platform
    bool hasPermission = false;

    if (Platform.isAndroid) {
      if (await Permission.storage.isDenied ||
          await Permission.storage.isRestricted) {
        await Permission.storage.request();
      }

      // On Android 11+ (API 30+), we must also check manageExternalStorage
      if (await Permission.manageExternalStorage.isDenied ||
          await Permission.manageExternalStorage.isRestricted) {
        await Permission.manageExternalStorage.request();
      }

      hasPermission = await Permission.manageExternalStorage.isGranted ||
          await Permission.storage.isGranted;

      // If still not granted, open settings
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please allow storage permissions in Settings.'),
            action: SnackBarAction(
              label: 'Open Settings',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
        return;
      }
    } else if (Platform.isIOS) {
      PermissionStatus status = await Permission.photos.request();
      hasPermission = status.isGranted;

      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Photos permission is required to save videos.'),
          ),
        );
        return;
      }
    } else {
      // Unsupported platform
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unsupported platform')),
      );
      return;
    }

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
