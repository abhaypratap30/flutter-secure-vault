import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import 'package:vault/data/services/vault_service.dart';

/// Screen enabling users to browse system gallery, select photos/videos, encrypt them with AES-256, and import into vault.
class GalleryPickerScreen extends StatefulWidget {
  const GalleryPickerScreen({super.key});

  @override
  State<GalleryPickerScreen> createState() => _GalleryPickerScreenState();
}

class _GalleryPickerScreenState extends State<GalleryPickerScreen> {
  final VaultService _vaultService = VaultService();
  final List<AssetEntity> _assets = [];
  final List<AssetEntity> _selectedAssets = [];
  bool _isLoading = true;
  bool _isImporting = false;
  int _importProgress = 0;
  int _totalToImport = 0;

  // Pagination fields
  int _currentPage = 0;
  final int _pageSize = 60;
  bool _hasMoreToLoad = true;
  bool _isLoadingMore = false;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _requestPermissionAndLoad();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreAssets();
    }
  }

  Future<void> _requestPermissionAndLoad() async {
    setState(() => _isLoading = true);

    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps.isAuth || ps.hasAccess) {
      await _loadFirstPage();
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        _showPermissionDeniedDialog();
      }
    }
  }

  Future<void> _loadFirstPage() async {
    _currentPage = 0;
    _assets.clear();

    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
    );

    if (albums.isNotEmpty) {
      final recentAlbum = albums[0];
      final int assetCount = await recentAlbum.assetCountAsync;

      final List<AssetEntity> pageAssets = await recentAlbum.getAssetListRange(
        start: 0,
        end: _pageSize,
      );

      setState(() {
        _assets.addAll(pageAssets);
        _hasMoreToLoad = _assets.length < assetCount;
        _isLoading = false;
      });
    } else {
      setState(() {
        _hasMoreToLoad = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreAssets() async {
    if (_isLoadingMore || !_hasMoreToLoad) return;

    setState(() => _isLoadingMore = true);
    _currentPage++;

    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
    );

    if (albums.isNotEmpty) {
      final recentAlbum = albums[0];
      final int assetCount = await recentAlbum.assetCountAsync;

      final start = _currentPage * _pageSize;
      final end = (start + _pageSize) > assetCount ? assetCount : (start + _pageSize);

      final List<AssetEntity> pageAssets = await recentAlbum.getAssetListRange(
        start: start,
        end: end,
      );

      setState(() {
        _assets.addAll(pageAssets);
        _hasMoreToLoad = _assets.length < assetCount;
        _isLoadingMore = false;
      });
    } else {
      setState(() => _isLoadingMore = false);
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF140E28),
        title: const Text('Permission Required', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Vault requires access to your photos and videos to import and hide them. Please enable this in system settings.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9E8CF4)),
            onPressed: () {
              PhotoManager.openSetting();
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Open Settings', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _toggleSelection(AssetEntity asset) {
    setState(() {
      if (_selectedAssets.contains(asset)) {
        _selectedAssets.remove(asset);
      } else {
        _selectedAssets.add(asset);
      }
    });
  }

  Future<void> _importSelected() async {
    if (_selectedAssets.isEmpty) return;

    setState(() {
      _isImporting = true;
      _totalToImport = _selectedAssets.length;
      _importProgress = 0;
    });

    int successfullyImported = 0;
    for (var asset in _selectedAssets) {
      final success = await _vaultService.importAsset(asset);
      if (success) {
        successfullyImported++;
      }
      setState(() {
        _importProgress++;
      });
    }

    setState(() => _isImporting = false);

    if (mounted) {
      if (successfullyImported > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully encrypted & hid $successfullyImported items.'),
            backgroundColor: const Color(0xFF9E8CF4),
          ),
        );
      }
      Navigator.pop(context, successfullyImported > 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0B1C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0B1C),
        elevation: 0,
        title: const Text('Select Media to Hide', style: TextStyle(color: Colors.white)),
        actions: [
          if (_selectedAssets.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                onPressed: _importSelected,
                icon: const Icon(Icons.lock, color: Color(0xFF9E8CF4)),
                label: Text(
                  'Hide (${_selectedAssets.length})',
                  style: const TextStyle(color: Color(0xFF9E8CF4), fontWeight: FontWeight.bold),
                ),
              ),
            )
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFF9E8CF4))),
                )
              : _assets.isEmpty
                  ? const Center(
                      child: Text('No media found in your gallery.', style: TextStyle(color: Colors.white54)),
                    )
                  : Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          color: const Color(0xFF9E8CF4).withValues(alpha: 0.08),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Color(0xFF9E8CF4), size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Importing will encrypt files and prompt your phone to delete the original copies from the public library.',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: GridView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(8),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 4,
                              mainAxisSpacing: 4,
                            ),
                            itemCount: _assets.length + (_hasMoreToLoad ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _assets.length) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Color(0xFF9E8CF4))),
                                    ),
                                  ),
                                );
                              }

                              final asset = _assets[index];
                              final isSelected = _selectedAssets.contains(asset);
                              final isVideo = asset.type == AssetType.video;

                              return GestureDetector(
                                onTap: () => _toggleSelection(asset),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    AssetThumbnail(asset: asset),
                                    if (isVideo)
                                      const Positioned(
                                        bottom: 4,
                                        right: 4,
                                        child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                                      ),
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      color: isSelected ? const Color(0xFF9E8CF4).withValues(alpha: 0.3) : Colors.transparent,
                                      child: isSelected
                                          ? const Center(
                                              child: Icon(Icons.check_circle, color: Color(0xFF9E8CF4), size: 28),
                                            )
                                          : null,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
          if (_isImporting)
            Container(
              color: Colors.black87,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFF9E8CF4))),
                      const SizedBox(height: 24),
                      const Text(
                        'Encrypting & Deleting Original Files...',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please approve the system dialogue to delete the original files from your public gallery.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Imported $_importProgress of $_totalToImport files',
                        style: const TextStyle(color: Color(0xFF9E8CF4), fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Asynchronously loads and renders gallery thumbnail image.
class AssetThumbnail extends StatelessWidget {
  final AssetEntity asset;
  const AssetThumbnail({super.key, required this.asset});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
          );
        }
        return Container(
          color: Colors.white.withValues(alpha: 0.04),
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Color(0xFF9E8CF4)),
              ),
            ),
          ),
        );
      },
    );
  }
}
