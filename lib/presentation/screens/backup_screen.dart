import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:vault/logic/blocs/backup_bloc.dart';
import 'package:vault/presentation/widgets/animated_background.dart';
import 'package:vault/presentation/widgets/glass_box.dart';

/// Screen managing Firebase cloud backups, auto-backup settings, and data loss recovery.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VaultBackupBloc>().add(LoadBackupStatusEvent());
    });
  }

  Future<void> _simulateDataLoss() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF140E28),
        title: const Text('Simulate Local Data Loss?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'WARNING: This will delete all encrypted media files and metadata from the local app directory, simulating an app uninstall or phone transfer.\n\nYour backups stored in cloud storage will NOT be deleted.',
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
            child: const Text('Simulate Loss', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      context.read<VaultBackupBloc>().add(SimulateBackupDataLossEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VaultBackupBloc, VaultBackupState>(
      listener: (context, state) {
        if (state is VaultBackupOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: const Color(0xFF9E8CF4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (state is VaultBackupError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        final totalLocal = state.totalLocal;
        final backedUpCount = state.backedUpCount;
        final isAutoBackup = state.isAutoBackup;
        final isProcessing = state is VaultBackupLoading;
        final statusMessage = isProcessing ? (state.message ?? 'Processing...') : '';

        return AnimatedBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text('Cloud Backup & Recovery'),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            body: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GlassBox(
                        blur: 15,
                        opacity: 0.05,
                        borderRadius: 24,
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF9E8CF4).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.cloud_done_outlined, color: Color(0xFF9E8CF4), size: 32),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Device Vault Backup',
                                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '$backedUpCount of $totalLocal files encrypted in cloud',
                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Backup Preferences',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      GlassBox(
                        blur: 10,
                        opacity: 0.03,
                        borderRadius: 16,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: SwitchListTile(
                          activeThumbColor: const Color(0xFF9E8CF4),
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Auto-Backup', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                          subtitle: const Text('Automatically upload files when they are encrypted', style: TextStyle(color: Colors.white38, fontSize: 12)),
                          value: isAutoBackup,
                          onChanged: isProcessing ? null : (val) {
                            context.read<VaultBackupBloc>().add(ToggleAutoBackupEvent(val));
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Backup & Recovery Actions',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: (isProcessing || totalLocal == backedUpCount) ? null : () {
                          context.read<VaultBackupBloc>().add(SyncBackupEvent());
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: GlassBox(
                          blur: 10,
                          opacity: (isProcessing || totalLocal == backedUpCount) ? 0.01 : 0.03,
                          borderRadius: 16,
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.cloud_upload_outlined, color: Color(0xFF9E8CF4), size: 28),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Sync Vault to Cloud Now',
                                      style: TextStyle(
                                        color: (isProcessing || totalLocal == backedUpCount) ? Colors.white30 : Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      totalLocal == backedUpCount
                                          ? 'All files backed up'
                                          : '${totalLocal - backedUpCount} unsynced files remaining',
                                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.sync,
                                color: (isProcessing || totalLocal == backedUpCount) ? Colors.white12 : const Color(0xFF9E8CF4),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: isProcessing ? null : () {
                          context.read<VaultBackupBloc>().add(RecoverBackupEvent());
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: GlassBox(
                          blur: 10,
                          opacity: isProcessing ? 0.01 : 0.03,
                          borderRadius: 16,
                          padding: const EdgeInsets.all(16),
                          child: const Row(
                            children: [
                              Icon(Icons.cloud_download_outlined, color: Color(0xFF9E8CF4), size: 28),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Recover Vault from Cloud',
                                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Download missing vault items and restore metadata',
                                      style: TextStyle(color: Colors.white38, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.download_rounded, color: Color(0xFF9E8CF4)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),
                      const Text(
                        'Diagnostic Tool (Simulate Data Loss)',
                        style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      GlassBox(
                        blur: 15,
                        opacity: 0.03,
                        borderRadius: 16,
                        padding: const EdgeInsets.all(16),
                        color: Colors.redAccent,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Simulate Device Data Loss',
                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Use this button to delete local app storage as if the app was uninstalled. You can then use "Recover Vault" above to restore everything from your cloud backups.',
                              style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.4),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                                  side: const BorderSide(color: Colors.redAccent, width: 1),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: isProcessing ? null : _simulateDataLoss,
                                icon: const Icon(Icons.phonelink_erase, color: Colors.white, size: 20),
                                label: const Text('Simulate Local Data Loss', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isProcessing)
                  Container(
                    color: Colors.black87,
                    child: Center(
                      child: GlassBox(
                        blur: 15,
                        opacity: 0.1,
                        borderRadius: 24,
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFF9E8CF4))),
                            const SizedBox(height: 20),
                            Text(
                              statusMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
