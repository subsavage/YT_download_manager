// lib/services/youtube_service.dart
import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';

class YouTubeService {
  static final YoutubeExplode _yt = YoutubeExplode();

  /// Fetches video title, thumbnail URL, and available MP4 resolutions.
  static Future<VideoInfo> fetchVideoInfo(String url) async {
    final video = await _yt.videos.get(url);
    final manifest = await _yt.videos.streamsClient.getManifest(url);

    final muxed = manifest.muxed
        .where((stream) => stream.container == StreamContainer.mp4)
        .toList();

    final resolutions = muxed.map((s) => s.qualityLabel).toList();

    return VideoInfo(
      title: video.title,
      thumbnailUrl: video.thumbnails.standardResUrl,
      resolutions: resolutions,
    );
  }

  /// Downloads the video at the chosen [resolution], reporting progress.
  static Future<void> downloadVideo(
    String url,
    String resolution,
    void Function(int received, int total) onProgress,
  ) async {
    try {
      // 1. Refresh the manifest to get stream URLs
      final manifest = await _yt.videos.streamsClient.getManifest(url);

      // 2. Pick the matching MP4 stream
      final streamInfo = manifest.muxed.firstWhere(
        (s) => s.qualityLabel == resolution,
      );

      // 3. Prepare output file in app documents directory
      final dir = await _getAppDocDir();
      final filePath =
          '${dir.path}/${DateTime.now().millisecondsSinceEpoch}-$resolution.mp4';
      final file = File(filePath);
      final fileStream = file.openWrite();

      // 4. Stream data into the file and report progress
      final stream = _yt.videos.streams.get(streamInfo);
      final totalBytes = streamInfo.size.totalBytes;
      int receivedBytes = 0;

      await for (final chunk in stream) {
        fileStream.add(chunk);
        receivedBytes += chunk.length;
        onProgress(receivedBytes, totalBytes);
      }

      // 5. Finalize
      await fileStream.flush();
      await fileStream.close();
    } catch (e) {
      throw Exception("Download failed: $e");
    }
  }

  /// Helper function to get application documents directory
  static Future<Directory> _getAppDocDir() async {
    final dir = await getExternalStorageDirectory();
    if (dir == null) {
      throw Exception("Cannot access external storage directory.");
    }
    return dir;
  }
}
