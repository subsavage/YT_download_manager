// lib/services/youtube_service.dart
import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';

class YouTubeService {
  static final YoutubeExplode _yt =
      YoutubeExplode(); // Library entry point :contentReference[oaicite:2]{index=2}

  /// Fetches video title, thumbnail URL, and available MP4 resolutions.
  static Future<VideoInfo> fetchVideoInfo(String url) async {
    // 1. Get video metadata (supports URL or ID strings)
    final video = await _yt.videos
        .get(url); // Metadata API :contentReference[oaicite:3]{index=3}

    // 2. Retrieve the stream manifest for all available streams
    final manifest = await _yt.videos.streamsClient.getManifest(
        url); // getManifest usage :contentReference[oaicite:4]{index=4}

    // 3. Filter for MP4 muxed streams (contain both audio + video)
    final muxed = manifest.muxed
        .where((stream) => stream.container == StreamContainer.mp4)
        .toList(); // Use StreamContainer.mp4, not Container.mp4 :contentReference[oaicite:5]{index=5}

    // 4. Extract resolution labels
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
    // 1. Refresh the manifest to get stream URLs
    final manifest = await _yt.videos.streamsClient
        .getManifest(url); // :contentReference[oaicite:6]{index=6}

    // 2. Pick the matching MP4 stream
    final streamInfo = manifest.muxed.firstWhere(
      (s) => s.qualityLabel == resolution,
    ); // :contentReference[oaicite:7]{index=7}

    // 3. Prepare output file in app documents directory
    final dir =
        await getApplicationDocumentsDirectory(); // path_provider API :contentReference[oaicite:8]{index=8}
    final filePath =
        '${dir.path}/${DateTime.now().millisecondsSinceEpoch}-$resolution.mp4';
    final file = File(filePath);
    final fileStream =
        file.openWrite(); // Dart IO :contentReference[oaicite:9]{index=9}

    // 4. Stream data into the file and report progress
    final stream = _yt.videos.streams.get(
        streamInfo); // Download stream :contentReference[oaicite:10]{index=10}
    final totalBytes = streamInfo.size.totalBytes;
    int receivedBytes = 0;
    await for (final chunk in stream) {
      fileStream.add(chunk);
      receivedBytes += chunk.length;
      onProgress(receivedBytes, totalBytes);
    }

    // 5. Finalize
    await fileStream.flush();
    await fileStream.close(); // :contentReference[oaicite:11]{index=11}
  }
}
