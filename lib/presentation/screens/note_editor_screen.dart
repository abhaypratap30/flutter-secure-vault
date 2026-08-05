import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:vault/data/models/vault_note.dart';
import 'package:vault/logic/blocs/notes_bloc.dart';
import 'package:vault/presentation/widgets/animated_background.dart';
import 'package:vault/presentation/widgets/glass_box.dart';

/// Screen providing encrypted text note creation and editing with automatic save-on-exit semantics.
class NoteEditorScreen extends StatefulWidget {
  final VaultNote? note;
  const NoteEditorScreen({super.key, this.note});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) return;

    if (widget.note == null) {
      context.read<VaultNotesBloc>().add(AddNoteEvent(title: title, content: content));
    } else {
      context.read<VaultNotesBloc>().add(UpdateNoteEvent(id: widget.note!.id, title: title, content: content));
    }
  }

  Future<void> _deleteNote() async {
    if (widget.note == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Delete Note?', style: TextStyle(color: Colors.white)),
        content: const Text('This will delete this note permanently. It cannot be undone.', style: TextStyle(color: Colors.white70)),
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

    if (confirm == true && mounted) {
      context.read<VaultNotesBloc>().add(DeleteNoteEvent(widget.note!.id));
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (bool didPop, dynamic result) async {
          if (didPop) {
            await _saveNote();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(widget.note == null ? 'New Note' : 'Edit Note'),
            actions: [
              if (widget.note != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: _deleteNote,
                  tooltip: 'Delete Note',
                ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: GlassBox(
                blur: 15,
                opacity: 0.04,
                borderRadius: 24,
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _titleController,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        hintText: 'Note Title',
                        hintStyle: TextStyle(color: Colors.white24, fontSize: 22),
                        border: InputBorder.none,
                      ),
                    ),
                    const Divider(color: Colors.white10, height: 24),
                    Expanded(
                      child: TextField(
                        controller: _contentController,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
                        decoration: const InputDecoration(
                          hintText: 'Type your note here...',
                          hintStyle: TextStyle(color: Colors.white12, fontSize: 16),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _contentController,
                          builder: (context, value, _) {
                            final charCount = value.text.length;
                            return Text(
                              '$charCount characters',
                              style: const TextStyle(color: Colors.white38, fontSize: 12),
                            );
                          },
                        ),
                        BlocBuilder<VaultNotesBloc, VaultNotesState>(
                          builder: (context, state) {
                            if (state is VaultNotesLoading) {
                              return const Text(
                                'Saving note...',
                                style: TextStyle(color: Colors.white38, fontSize: 12),
                              );
                            }
                            return const Text(
                              'Auto-saves on exit',
                              style: TextStyle(color: Colors.white24, fontSize: 11),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
