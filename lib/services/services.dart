import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:youtube_download_manager/models/models.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

class YouTubeService {
  static final YoutubeExplode _yt = YoutubeExplode();

  static Future<VideoInfo> fetchVideoInfo(String url) async {
    final video = await _yt.videos.get(url);
    final manifest = await _yt.videos.streamsClient.getManifest(url);

    final muxed = manifest.muxed
        .where((stream) => stream.container == StreamContainer.mp4)
        .toList();

    final resolutions = muxed.map((s) => s.qualityLabel ?? 'Unknown').toList();

    return VideoInfo(
      title: video.title,
      thumbnailUrl: video.thumbnails.standardResUrl ?? '',
      resolutions: resolutions,
    );
  }

  static Future<void> downloadVideo(
    String youtubeUrl,
    BuildContext context, {
    required void Function(double) onProgress,
  }) async {
    final yt = YoutubeExplode();
    File? tempFile;

    try {
      if (!await _requestPermissions(context)) return;

      final manifest = await yt.videos.streamsClient.getManifest(
        youtubeUrl,
        fullManifest: true,
      );

      final muxedStreams = manifest.videoOnly
          .where((s) => s.container == StreamContainer.mp4)
          .toList();

      if (muxedStreams.isEmpty) {
        throw Exception(
            'No downloadable MP4 streams available for this video.');
      }

      muxedStreams.sort((a, b) => b.bitrate.compareTo(a.bitrate));
      final streamInfo = muxedStreams.first;

      final appDocDir = await getApplicationDocumentsDirectory();
      final tempPath = p.join(
        appDocDir.path,
        'video_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );
      tempFile = File(tempPath);
      final fileStream = tempFile.openWrite();
      final stream = yt.videos.streamsClient.get(streamInfo);

      final totalSize = streamInfo.size.totalBytes;
      int downloaded = 0;

      await for (final data in stream) {
        downloaded += data.length;
        fileStream.add(data);
        onProgress(downloaded / totalSize);
      }
      await fileStream.close();

      if (!(await tempFile.exists())) {
        throw Exception('Failed to write video file to disk.');
      }

      final asset = await PhotoManager.editor
          .saveVideo(tempFile, title: "Downloaded Video");
      if (asset == null) {
        throw Exception('Failed to save video to gallery.');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Video saved to gallery!')),
      );
    } catch (e, stack) {
      debugPrint('Download error: $e\n$stack');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      yt.close();
      if (tempFile != null && await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  static Future<bool> _requestPermissions(BuildContext context) async {
    if (Platform.isAndroid) {
      final pmState = await PhotoManager.requestPermissionExtend(
        requestOption: const PermissionRequestOption(
          androidPermission: AndroidPermission(
            type: RequestType.video,
            mediaLocation: true,
          ),
        ),
      );
      if (!pmState.isAuth) {
        await _showPermissionDialog(context, 'media library');
        return false;
      }
    }
    if (Platform.isIOS) {
      final status = await Permission.photos.request();
      if (!status.isGranted) {
        await _showPermissionDialog(context, 'photos');
        return false;
      }
    }
    return true;
  }

  static Future<void> _showPermissionDialog(
      BuildContext context, String permission) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Permission Required'),
        content: Text('Please grant $permission permission in settings'),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text('Open Settings'),
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
          ),
        ],
      ),
    );
  }
}
