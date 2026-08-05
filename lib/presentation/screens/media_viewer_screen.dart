import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:vault/data/models/vault_item.dart';
import 'package:vault/data/services/vault_service.dart';

/// Screen handling decrypted viewing of photos (InteractiveViewer) and video playback (VideoPlayerController) with automatic cleanup.
class MediaViewerScreen extends StatefulWidget {
  final VaultItem item;
  const MediaViewerScreen({super.key, required this.item});

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  final VaultService _vaultService = VaultService();

  // Video fields
  VideoPlayerController? _videoController;
  File? _tempVideoFile;
  bool _isVideoLoading = true;
  bool _isPlaying = false;
  bool _showControls = true;

  // Photo future
  Future<Uint8List>? _photoFuture;

  @override
  void initState() {
    super.initState();
    if (widget.item.type == 'photo') {
      _photoFuture = _vaultService.decryptItemBytes(widget.item);
    } else {
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    try {
      _tempVideoFile = await _vaultService.getDecryptedTempFile(widget.item);
      _videoController = VideoPlayerController.file(_tempVideoFile!);
      await _videoController!.initialize();
      _videoController!.play();
      _videoController!.setLooping(true);

      setState(() {
        _isVideoLoading = false;
        _isPlaying = true;
      });

      _videoController!.addListener(() {
        if (mounted) {
          setState(() {
            _isPlaying = _videoController!.value.isPlaying;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load video player.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();

    if (_tempVideoFile != null && _tempVideoFile!.existsSync()) {
      try {
        _tempVideoFile!.deleteSync();
      } catch (e) {
        // Handle temporary file deletion errors gracefully
      }
    }
    super.dispose();
  }

  void _togglePlay() {
    if (_videoController == null) return;
    setState(() {
      if (_isPlaying) {
        _videoController!.pause();
      } else {
        _videoController!.play();
      }
    });
  }

  Future<void> _unhideItem() async {
    setState(() => _isVideoLoading = true);
    final success = await _vaultService.restoreItem(widget.item);
    setState(() => _isVideoLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Restored to gallery successfully!' : 'Failed to restore.'),
          backgroundColor: success ? const Color(0xFF9E8CF4) : Colors.redAccent,
        ),
      );
      if (success) {
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _deleteItem() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF140E28),
        title: const Text('Delete Permanently?', style: TextStyle(color: Colors.white)),
        content: const Text('This will delete the file permanently. It cannot be undone.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await _vaultService.deleteItem(widget.item);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Deleted permanently.' : 'Failed to delete.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      if (success) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPhoto = widget.item.type == 'photo';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black38,
        elevation: 0,
        title: Text(
          widget.item.originalName,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_backup_restore, color: Colors.white),
            onPressed: _unhideItem,
            tooltip: 'Unhide (Restore to Gallery)',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: _deleteItem,
            tooltip: 'Delete Permanently',
          ),
        ],
      ),
      body: Center(
        child: isPhoto ? _buildPhotoViewer() : _buildVideoViewer(),
      ),
    );
  }

  Widget _buildPhotoViewer() {
    return FutureBuilder<Uint8List>(
      future: _photoFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFF9E8CF4)));
        } else if (snapshot.hasError || !snapshot.hasData) {
          return const Icon(Icons.broken_image, color: Colors.white38, size: 64);
        }
        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.memory(
            snapshot.data!,
            fit: BoxFit.contain,
          ),
        );
      },
    );
  }

  Widget _buildVideoViewer() {
    if (_isVideoLoading) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFF9E8CF4))),
          SizedBox(height: 16),
          Text('Decrypting video...', style: TextStyle(color: Colors.white70)),
        ],
      );
    }

    if (_videoController == null || !_videoController!.value.isInitialized) {
      return const Icon(Icons.error_outline, color: Colors.white38, size: 64);
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _showControls = !_showControls;
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _videoController!.value.aspectRatio,
            child: VideoPlayer(_videoController!),
          ),
          if (_showControls) ...[
            Container(
              color: Colors.black38,
            ),
            IconButton(
              iconSize: 64,
              icon: Icon(
                _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                color: Colors.white,
              ),
              onPressed: _togglePlay,
            ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: VideoProgressIndicator(
                _videoController!,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Color(0xFF9E8CF4),
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.white10,
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }
}
