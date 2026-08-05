import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'package:vault/data/models/vault_item.dart';
import 'package:vault/data/services/vault_service.dart';
import 'package:vault/logic/blocs/auth_bloc.dart';
import 'package:vault/logic/blocs/media_bloc.dart';
import 'package:vault/logic/blocs/notes_bloc.dart';
import 'package:vault/logic/blocs/theme_bloc.dart';
import 'package:vault/presentation/screens/backup_screen.dart';
import 'package:vault/presentation/screens/gallery_picker_screen.dart';
import 'package:vault/presentation/screens/media_viewer_screen.dart';
import 'package:vault/presentation/screens/note_editor_screen.dart';
import 'package:vault/presentation/screens/passcode_screen.dart';
import 'package:vault/presentation/widgets/animated_background.dart';
import 'package:vault/presentation/widgets/glass_box.dart';

/// Main Dashboard Screen providing tabs for Photos, Videos, Encrypted Notes, and Security Settings.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  final VaultService _vaultService = VaultService();
  late TabController _tabController;
  bool _biometricSupported = false;

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _clearSelection();
      }
      setState(() {});
    });
    _checkBiometrics();
    _updateFlipToHideSubscription(_vaultService.isFlipToHideEnabled);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  Future<void> _checkBiometrics() async {
    final supported = await _vaultService.canUseBiometrics();
    if (mounted) {
      setState(() {
        _biometricSupported = supported;
      });
    }
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _clearSelection() {
    context.read<VaultMediaBloc>().add(ClearMediaSelectionEvent());
  }

  void _toggleSelection(VaultItem item) {
    context.read<VaultMediaBloc>().add(ToggleMediaSelectionEvent(item));
  }

  Future<void> _refreshData() async {
    context.read<VaultMediaBloc>().add(LoadMediaEvent());
    context.read<VaultNotesBloc>().add(LoadNotesEvent());
  }

  void _restoreSelected() {
    final selected = context.read<VaultMediaBloc>().state.selectedItems;
    if (selected.isEmpty) return;
    context.read<VaultMediaBloc>().add(RestoreMediaEvent(List.from(selected)));
  }

  Future<void> _deleteSelected() async {
    final selected = context.read<VaultMediaBloc>().state.selectedItems;
    if (selected.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Delete Permanently?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will permanently delete the selected files from the vault. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
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
    if (mounted) {
      context.read<VaultMediaBloc>().add(DeleteMediaEvent(List.from(selected)));
    }
  }

  void _lockVault() {
    context.read<VaultAuthBloc>().add(LockVaultEvent());
  }

  void _changeTheme(String themeKey) {
    context.read<VaultThemeBloc>().add(ChangeThemeEvent(themeKey));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<VaultAuthBloc, VaultAuthState>(
      listener: (context, authState) {
        if (authState is VaultAuthLockedState) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const PasscodeScreen()),
          );
        }
      },
      child: BlocConsumer<VaultMediaBloc, VaultMediaState>(
        listener: (context, mediaState) {
          if (mediaState is VaultMediaOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(mediaState.message),
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
            );
          } else if (mediaState is VaultMediaOperationError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(mediaState.error),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        },
        builder: (context, mediaState) {
          final photos = mediaState.items.where((x) => x.type == 'photo').toList();
          final videos = mediaState.items.where((x) => x.type == 'video').toList();
          final isSelectionMode = mediaState.isSelectionMode;
          final selectedItemsCount = mediaState.selectedItems.length;
          final isLoading = mediaState is VaultMediaLoading;

          return AnimatedBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              extendBody: true,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: isSelectionMode
                    ? Text('$selectedItemsCount Selected')
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.primary,
                                const Color(0xFF00E5FF),
                              ],
                            ).createShader(bounds),
                            child: const Text(
                              'Vault Pro',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          if (_vaultService.isDecoySession) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'DECOY',
                                style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                actions: [
                  if (isSelectionMode) ...[
                    IconButton(
                      icon: const Icon(Icons.settings_backup_restore),
                      onPressed: _restoreSelected,
                      tooltip: 'Restore Selected',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: _deleteSelected,
                      tooltip: 'Delete Permanently',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _clearSelection,
                    ),
                  ] else ...[
                    IconButton(
                      icon: const Icon(Icons.lock_outline),
                      onPressed: _lockVault,
                      tooltip: 'Lock Vault',
                    ),
                  ]
                ],
              ),
              body: Stack(
                children: [
                  TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMediaGrid(photos, 'photo', isSelectionMode, mediaState.selectedItems),
                      _buildMediaGrid(videos, 'video', isSelectionMode, mediaState.selectedItems),
                      _buildNotesGrid(),
                      _buildSettingsTab(),
                    ],
                  ),
                  if (isLoading)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Processing files...', style: TextStyle(color: Colors.white, fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              floatingActionButton: _tabController.index < 3 && !isSelectionMode
                  ? Container(
                      margin: const EdgeInsets.only(bottom: 84),
                      child: FloatingActionButton(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.black,
                        onPressed: () async {
                          if (_tabController.index == 2) {
                            final created = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(builder: (context) => const NoteEditorScreen()),
                            );
                            if (created == true) _refreshData();
                          } else {
                            final imported = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(builder: (context) => const GalleryPickerScreen()),
                            );
                            if (imported == true) _refreshData();
                          }
                        },
                        child: const Icon(Icons.add),
                      ),
                    )
                  : null,
              bottomNavigationBar: Container(
                margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SafeArea(
                  child: GlassBox(
                    blur: 20,
                    opacity: 0.05,
                    borderRadius: 24,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      labelColor: Theme.of(context).colorScheme.primary,
                      unselectedLabelColor: Colors.white38,
                      dividerColor: Colors.transparent,
                      indicatorSize: TabBarIndicatorSize.tab,
                      tabs: const [
                        Tab(icon: Icon(Icons.image_outlined, size: 20), text: 'Photos'),
                        Tab(icon: Icon(Icons.videocam_outlined, size: 20), text: 'Videos'),
                        Tab(icon: Icon(Icons.note_alt_outlined, size: 20), text: 'Notes'),
                        Tab(icon: Icon(Icons.settings_outlined, size: 20), text: 'Settings'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMediaGrid(List<VaultItem> items, String type, bool isSelectionMode, List<VaultItem> selectedItems) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: GlassBox(
            blur: 15,
            opacity: 0.03,
            borderRadius: 28,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  type == 'photo' ? Icons.photo_library_outlined : Icons.video_library_outlined,
                  size: 64,
                  color: Colors.white24,
                ),
                const SizedBox(height: 24),
                Text(
                  'No Hidden ${type == 'photo' ? 'Photos' : 'Videos'}',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the + button to safely import and encrypt media from your gallery.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 110),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = selectedItems.contains(item);

        return GestureDetector(
          onLongPress: () {
            HapticFeedback.mediumImpact();
            _toggleSelection(item);
          },
          onTap: () {
            if (isSelectionMode) {
              _toggleSelection(item);
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MediaViewerScreen(item: item),
                ),
              ).then((_) => _refreshData());
            }
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white.withValues(alpha: 0.08),
                width: isSelected ? 3 : 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  item.type == 'photo'
                      ? _DecryptedImageTile(item: item)
                      : Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                              colors: [Color(0xFF1E1737), Color(0xFF0F0B20)],
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_circle_fill_rounded, color: Theme.of(context).colorScheme.primary, size: 36),
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                child: Text(
                                  item.originalName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white60, fontSize: 10),
                                ),
                              ),
                              if (item.duration != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  _formatDuration(item.duration!),
                                  style: const TextStyle(color: Colors.white38, fontSize: 9),
                                ),
                              ]
                            ],
                          ),
                        ),
                  if (isSelectionMode)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black45,
                        ),
                        child: Icon(
                          isSelected ? Icons.check : Icons.add,
                          size: 16,
                          color: isSelected ? Colors.black : Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotesGrid() {
    return BlocBuilder<VaultNotesBloc, VaultNotesState>(
      builder: (context, notesState) {
        final notes = notesState.notes;

        if (notes.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: GlassBox(
                blur: 15,
                opacity: 0.03,
                borderRadius: 28,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.note_alt_outlined,
                      size: 64,
                      color: Colors.white24,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'No Encrypted Notes',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the + button to create a private note. Notes are fully encrypted inside your vault.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.9,
          ),
          itemCount: notes.length,
          itemBuilder: (context, index) {
            final note = notes[index];
            final formattedDate = "${note.dateModified.day}/${note.dateModified.month}/${note.dateModified.year}";

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => NoteEditorScreen(note: note)),
                ).then((_) => _refreshData());
              },
              child: GlassBox(
                blur: 10,
                opacity: 0.04,
                borderRadius: 20,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title.isNotEmpty ? note.title : 'Untitled Note',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(
                        note.content,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.3),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formattedDate,
                          style: const TextStyle(color: Colors.white24, fontSize: 10),
                        ),
                        Icon(Icons.edit_outlined, size: 14, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dynamic Themes',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildThemeSelector(),
          const SizedBox(height: 32),
          const Text(
            'Security Configuration',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildSettingsTile(
            icon: Icons.lock_reset,
            title: 'Change Master PIN',
            subtitle: 'Update your primary passcode',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PasscodeScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildSettingsTile(
            icon: Icons.cloud_done_outlined,
            title: 'Cloud Backup & Recovery',
            subtitle: 'Sync files to cloud and recover data',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BackupScreen()),
              );
            },
          ),
          if (!_vaultService.isDecoySession) ...[
            const SizedBox(height: 12),
            _buildSettingsTile(
              icon: Icons.security_outlined,
              title: _vaultService.isDecoyPinSet ? 'Disable Decoy PIN' : 'Set Decoy PIN',
              subtitle: _vaultService.isDecoyPinSet ? 'Remove the decoy vault gate' : 'Create a secondary fake vault entry',
              iconColor: _vaultService.isDecoyPinSet ? Colors.redAccent : null,
              onTap: () {
                if (_vaultService.isDecoyPinSet) {
                  _disableDecoyPinFlow();
                } else {
                  _enableDecoyPinFlow();
                }
              },
            ),
            if (_biometricSupported) ...[
              const SizedBox(height: 12),
              _buildBiometricsSwitch(),
            ],
          ],
          const SizedBox(height: 32),
          const Text(
            'Next-Gen Security Options',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildSettingsSwitchTile(
            icon: Icons.music_note_outlined,
            title: 'Touch Rhythm Lock',
            subtitle: 'Unlock with a custom rhythmic tap pattern',
            value: _vaultService.isRhythmLockEnabled,
            onChanged: (val) => _toggleRhythmLock(val),
          ),
          const SizedBox(height: 12),
          _buildSettingsSwitchTile(
            icon: Icons.screen_search_desktop_outlined,
            title: 'Search Camouflage Mode',
            subtitle: 'Disguises passcode screen as a Search Engine',
            value: _vaultService.isCamouflageEnabled,
            onChanged: (val) async {
              await _vaultService.setCamouflageEnabled(val);
              setState(() {});
            },
          ),
          const SizedBox(height: 12),
          _buildSettingsTile(
            icon: Icons.bug_report_outlined,
            title: _vaultService.fakeCrashPin.isNotEmpty ? 'Change Fake Crash PIN' : 'Setup Fake Crash PIN',
            subtitle: _vaultService.fakeCrashPin.isNotEmpty 
                ? 'Crash PIN configured: ${_vaultService.fakeCrashPin}' 
                : 'Enter a PIN to trigger a simulated app crash',
            onTap: _setupFakeCrashPinFlow,
          ),
          const SizedBox(height: 12),
          _buildSettingsSwitchTile(
            icon: Icons.screen_rotation_outlined,
            title: 'Flip-to-Hide Panic Lock',
            subtitle: 'Lock vault instantly when screen is flipped face-down',
            value: _vaultService.isFlipToHideEnabled,
            onChanged: (val) async {
              await _vaultService.setFlipToHideEnabled(val);
              _updateFlipToHideSubscription(val);
              setState(() {});
            },
          ),
          const SizedBox(height: 12),
          if (_biometricSupported && _vaultService.isBiometricsEnabled) ...[
            _buildSettingsSwitchTile(
              icon: Icons.gesture_outlined,
              title: 'Biometric Gesture Decoy',
              subtitle: 'Swipe left during biometric scan to enter decoy vault',
              value: _vaultService.isBiometricGestureDecoyEnabled,
              onChanged: (val) async {
                await _vaultService.setBiometricGestureDecoyEnabled(val);
                setState(() {});
              },
            ),
            const SizedBox(height: 12),
          ],
          _buildSettingsSwitchTile(
            icon: Icons.bluetooth_connected_outlined,
            title: 'Bluetooth Proximity Lock',
            subtitle: 'Restrict unlock unless Smart Key device is connected',
            value: _vaultService.isBluetoothKeyEnabled,
            onChanged: (val) => _toggleBluetoothKeyFlow(val),
          ),
          const SizedBox(height: 32),
          const Text(
            'Encryption Information',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          GlassBox(
            blur: 15,
            opacity: 0.03,
            borderRadius: 24,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(Icons.security, 'AES-256 local encryption', 'Notes and photos are encrypted in separate sandbox directories. Decoy session redirects folder links to fake metadata instantly.'),
                const SizedBox(height: 16),
                _buildInfoRow(Icons.cloud_off, 'Offline Storage', 'All files and keys reside completely on device memory. Offline-first security model.'),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildThemeSelector() {
    final activeThemeKey = context.watch<VaultThemeBloc>().state.themeKey;
    final themes = [
      {'key': 'purple', 'color': const Color(0xFF9E8CF4), 'label': 'Violet'},
      {'key': 'cyan', 'color': const Color(0xFF00E5FF), 'label': 'Cyan'},
      {'key': 'emerald', 'color': const Color(0xFF00E676), 'label': 'Emerald'},
      {'key': 'sakura', 'color': const Color(0xFFFF4081), 'label': 'Sakura'},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: themes.map((t) {
        final isSelected = activeThemeKey == t['key'];
        return GestureDetector(
          onTap: () => _changeTheme(t['key'] as String),
          child: Column(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: t['color'] as Color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: (t['color'] as Color).withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 2)]
                      : [],
                ),
                child: isSelected
                    ? const Center(child: Icon(Icons.check, color: Colors.black, size: 24))
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                t['label'] as String,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white38,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBiometricsSwitch() {
    return SwitchListTile.adaptive(
      activeThumbColor: Theme.of(context).colorScheme.primary,
      secondary: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.fingerprint, color: Theme.of(context).colorScheme.primary, size: 24),
      ),
      title: const Text('Biometric Unlock', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      subtitle: const Text('Unlock vault with fingerprint or Face ID', style: TextStyle(color: Colors.white38, fontSize: 12)),
      value: _vaultService.isBiometricsEnabled,
      onChanged: (bool value) {
        if (value) {
          _enableBiometricFlow();
        } else {
          _disableBiometricFlow();
        }
      },
    );
  }

  Future<void> _enableBiometricFlow() async {
    final pin = await _promptPinDialog('Verify Master PIN', 'Enter PIN to enable biometric authentication.');
    if (pin == null) return;

    final success = await _vaultService.enableBiometrics(pin);
    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Biometrics enabled successfully.' : 'Incorrect PIN. Biometrics not enabled.'),
          backgroundColor: success ? Theme.of(context).colorScheme.primary : Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _disableBiometricFlow() async {
    await _vaultService.disableBiometrics();
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biometrics disabled.')),
      );
    }
  }

  Future<void> _enableDecoyPinFlow() async {
    final decoyPin = await _promptPinDialog('Set Decoy PIN', 'Choose a secondary 4-digit PIN for decoy vault gate.');
    if (decoyPin == null) return;

    if (decoyPin.length == 4) {
      final success = await _vaultService.setDecoyPin(decoyPin);
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Decoy PIN configured successfully.' : 'Failed to set Decoy PIN.'),
            backgroundColor: success ? Theme.of(context).colorScheme.primary : Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _disableDecoyPinFlow() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Disable Decoy PIN?', style: TextStyle(color: Colors.white)),
        content: const Text('This will delete the decoy vault gate. Decoy files will not be deleted but will become inaccessible until configured again.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disable', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _vaultService.removeDecoyPin();
      setState(() {});
    }
  }

  Future<String?> _promptPinDialog(String title, String contentText) async {
    String pin = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: Text(title, style: const TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(contentText, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final isActive = index < pin.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive ? Theme.of(context).colorScheme.primary : Colors.white10,
                          border: Border.all(color: isActive ? Theme.of(context).colorScheme.primary : Colors.white30),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ...['1', '2', '3', '4', '5', '6', '7', '8', '9'].map((digit) {
                        return SizedBox(
                          width: 60,
                          height: 60,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              shape: const CircleBorder(),
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            onPressed: () {
                              if (pin.length < 4) {
                                HapticFeedback.lightImpact();
                                setDialogState(() {
                                  pin += digit;
                                });
                                if (pin.length == 4) {
                                  Future.delayed(const Duration(milliseconds: 200), () {
                                    if (ctx.mounted) {
                                      Navigator.pop(ctx, pin);
                                    }
                                  });
                                }
                              }
                            },
                            child: Text(digit, style: const TextStyle(color: Colors.white, fontSize: 20)),
                          ),
                        );
                      }),
                      const SizedBox(width: 60, height: 60),
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: const CircleBorder(),
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          onPressed: () {
                            if (pin.length < 4) {
                              HapticFeedback.lightImpact();
                              setDialogState(() {
                                pin += '0';
                              });
                              if (pin.length == 4) {
                                Future.delayed(const Duration(milliseconds: 200), () {
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx, pin);
                                  }
                                });
                              }
                            }
                          },
                          child: const Text('0', style: TextStyle(color: Colors.white, fontSize: 20)),
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: IconButton(
                          icon: const Icon(Icons.backspace_outlined, color: Colors.white60),
                          onPressed: () {
                            if (pin.isNotEmpty) {
                              HapticFeedback.mediumImpact();
                              setDialogState(() {
                                pin = pin.substring(0, pin.length - 1);
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final activeIconColor = iconColor ?? Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: GlassBox(
        blur: 5,
        opacity: 0.02,
        borderRadius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        glowBorder: false,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: activeIconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: activeIconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white30),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(description, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    String minutes = duration.inMinutes.toString();
    String remainingSeconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  void _updateFlipToHideSubscription(bool enabled) {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    if (enabled) {
      _accelerometerSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
        if (event.z < -8.5) {
          HapticFeedback.heavyImpact();
          _lockVault();
        }
      });
    }
  }

  Future<void> _toggleRhythmLock(bool val) async {
    if (!val) {
      await _vaultService.setRhythmLockEnabled(false);
      setState(() {});
      return;
    }

    final pattern = await _showRhythmSetupDialog();
    if (pattern != null && pattern.isNotEmpty) {
      await _vaultService.setRhythmPattern(pattern);
      await _vaultService.setRhythmLockEnabled(true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Touch Rhythm Lock enabled successfully.'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    }
    setState(() {});
  }

  Future<String?> _showRhythmSetupDialog() {
    List<int> tapTimestamps = [];

    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final tapCount = tapTimestamps.length;
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: const Text('Record Tap Rhythm', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Tap the touchpad below exactly 4 times in your desired rhythm/pattern.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final isDone = index < tapCount;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDone ? Theme.of(context).colorScheme.primary : Colors.white10,
                          border: Border.all(color: isDone ? Theme.of(context).colorScheme.primary : Colors.white30),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      final now = DateTime.now().millisecondsSinceEpoch;
                      setDialogState(() {
                        tapTimestamps.add(now);
                      });

                      if (tapTimestamps.length == 4) {
                        final List<int> intervals = [];
                        for (int i = 0; i < tapTimestamps.length - 1; i++) {
                          intervals.add(tapTimestamps[i + 1] - tapTimestamps[i]);
                        }
                        final patternStr = intervals.join(',');
                        Future.delayed(const Duration(milliseconds: 300), () {
                          if (ctx.mounted) {
                            Navigator.pop(ctx, patternStr);
                          }
                        });
                      }
                    },
                    child: GlassBox(
                      blur: 10,
                      opacity: 0.05,
                      borderRadius: 20,
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                      child: const Center(
                        child: Icon(Icons.touch_app_outlined, size: 48, color: Colors.white70),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _setupFakeCrashPinFlow() async {
    final pin = await _promptPinDialog('Set Fake Crash PIN', 'Enter a 4-digit PIN that triggers a simulated app crash.');
    if (pin != null && pin.length == 4) {
      await _vaultService.setFakeCrashPin(pin);
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fake Crash PIN set to $pin'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    }
  }

  Future<void> _toggleBluetoothKeyFlow(bool val) async {
    if (!val) {
      await _vaultService.setBluetoothKeyEnabled(false);
      setState(() {});
      return;
    }

    final controller = TextEditingController(text: _vaultService.bluetoothKeyDeviceName);
    final deviceName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Bluetooth Smart Key', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the exact bluetooth name of your key device (smartwatch, earbud, key tag) that must be connected.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'e.g., Galaxy Watch, Buds Pro',
                hintStyle: TextStyle(color: Colors.white38),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (ctx.mounted) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (deviceName != null && deviceName.isNotEmpty) {
      await _vaultService.setBluetoothKeyDeviceName(deviceName);
      await _vaultService.setBluetoothKeyEnabled(true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bluetooth proximity lock set for device: $deviceName'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    }
    setState(() {});
  }

  Widget _buildSettingsSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GlassBox(
      blur: 5,
      opacity: 0.02,
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      glowBorder: false,
      child: SwitchListTile.adaptive(
        activeThumbColor: Theme.of(context).colorScheme.primary,
        contentPadding: EdgeInsets.zero,
        secondary: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class _DecryptedImageTile extends StatefulWidget {
  final VaultItem item;
  const _DecryptedImageTile({required this.item});

  @override
  State<_DecryptedImageTile> createState() => _DecryptedImageTileState();
}

class _DecryptedImageTileState extends State<_DecryptedImageTile> {
  final VaultService _vaultService = VaultService();
  Future<Uint8List>? _decryptFuture;

  @override
  void initState() {
    super.initState();
    _decryptFuture = _vaultService.decryptItemBytes(widget.item);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _decryptFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: const Color(0xFF130E26),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        } else if (snapshot.hasError || !snapshot.hasData) {
          return Container(
            color: Colors.black38,
            child: const Icon(Icons.broken_image, color: Colors.white38),
          );
        }
        return Image.memory(
          snapshot.data!,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        );
      },
    );
  }
}
