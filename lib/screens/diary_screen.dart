import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../providers/diary_provider.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  bool _showPublic = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DiaryProvider>().loadEntries();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Diary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showEntryDialog(context),
          ),
        ],
      ),
      body: Consumer<DiaryProvider>(
        builder: (context, diary, _) {
          if (diary.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (diary.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 54),
                    const SizedBox(height: 10),
                    Text(diary.error!, textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () => diary.loadEntries(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final displayedEntries = _showPublic ? diary.publicEntries : diary.privateEntries;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: SegmentedButton<bool>(
                  style: ButtonStyle(
                    fixedSize: MaterialStateProperty.all(const Size.fromHeight(40)),
                  ),
                  segments: const [
                    ButtonSegment(
                      value: true,
                      label: Text('Public'),
                      icon: Icon(Icons.public),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text('Private'),
                      icon: Icon(Icons.lock_outline),
                    ),
                  ],
                  selected: {_showPublic},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _showPublic = selection.first;
                    });
                  },
                ),
              ),
              Expanded(
                child: displayedEntries.isEmpty
                    ? const Center(child: Text('No diary entries yet.'))
                    : RefreshIndicator(
                        onRefresh: () => context.read<DiaryProvider>().loadEntries(),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: displayedEntries.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final entry = displayedEntries[index];
                            return Card(
                              child: ListTile(
                                title: Text(entry.title),
                                subtitle: Text(
                                  'By ${entry.owner ?? 'Unknown'} on ${entry.createdAt.toLocal().toString().substring(0, 10)}',
                                ),
                                onTap: () => _showEntryDetails(context, entry),
                                trailing: !_showPublic
                                    ? PopupMenuButton<String>(
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _showEntryDialog(context, entry: entry);
                                          }
                                          if (value == 'delete') {
                                            _confirmDelete(context, entry.id, entry.title);
                                          }
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                                        ],
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showEntryDialog(BuildContext context, {DiaryEntry? entry}) async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: entry?.title ?? '');
    final contentController = TextEditingController(text: entry?.content ?? '');
    final minutesController = TextEditingController(text: (entry?.workingMinutes ?? 60).toString());
    final isPublic = entry?.isPublic ?? false;

    final save = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(entry == null ? 'New Entry' : 'Edit Entry'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        icon: const Icon(Icons.title),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      validator: (value) => (value?.isEmpty ?? true) ? 'Title is required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: minutesController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Working Minutes',
                        icon: const Icon(Icons.timer_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: contentController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: 'Content (Markdown)',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      validator: (value) => (value?.isEmpty ?? true) ? 'Content is required' : null,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.of(ctx).pop(true);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ) ??
        false;

    if (!save) {
      return;
    }

    final title = titleController.text.trim();
    final content = contentController.text.trim();
    final minutes = int.tryParse(minutesController.text.trim()) ?? 60;

    if (title.isEmpty || content.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and content are required.')),
      );
      return;
    }

    final diary = context.read<DiaryProvider>();
    bool ok;
    if (entry == null) {
      ok = await diary.addEntry(title, content, minutes, isPublic);
    } else {
      ok = await diary.updateEntry(entry.copyWith(
        title: title,
        content: content,
        workingMinutes: minutes,
        isPublic: isPublic,
      ));
    }

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Saved' : (diary.error ?? 'Failed to save entry'))),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String id, String title) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Entry'),
            content: Text('Delete "$title"?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
            ],
          ),
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    final diary = context.read<DiaryProvider>();
    final ok = await diary.deleteEntry(id);

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Entry deleted' : (diary.error ?? 'Delete failed'))),
    );
  }

  void _showEntryDetails(BuildContext context, DiaryEntry entry) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(entry.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MarkdownBody(data: entry.content),
              const SizedBox(height: 10),
              Text('Working Minutes: ${entry.workingMinutes}'),
              Text('Created: ${_formatDate(entry.createdAt)}'),
              Text('Updated: ${_formatDate(entry.updatedAt)}'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
        ],
      ),
    );
  }
}
