import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/diary_provider.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DiaryProvider>(context, listen: false).loadEntries();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              Provider.of<DiaryProvider>(context, listen: false).loadEntries();
            },
          ),
        ],
      ),
      body: Consumer<DiaryProvider>(
        builder: (context, diaryProvider, child) {
          if (diaryProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (diaryProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${diaryProvider.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      diaryProvider.clearError();
                      diaryProvider.loadEntries();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (diaryProvider.entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.book_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No diary entries yet',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start by adding your first entry',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showAddEntryDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Entry'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Summary card
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.book,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${diaryProvider.entries.length} Entries',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            'Last updated: ${_formatDate(diaryProvider.entries.first.updatedAt)}',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => _showAddEntryDialog(context),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
              ),

              // Entries list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: diaryProvider.entries.length,
                  itemBuilder: (context, index) {
                    final entry = diaryProvider.entries[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          entry.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              entry.content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  _formatDate(entry.createdAt),
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                if (entry.tags.isNotEmpty)
                                  Expanded(
                                    child: Wrap(
                                      spacing: 4,
                                      children: entry.tags
                                          .take(3)
                                          .map((tag) => Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                      .withOpacity(0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  tag,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primary,
                                                  ),
                                                ),
                                              ))
                                          .toList(),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton(
                          onSelected: (value) {
                            switch (value) {
                              case 'edit':
                                _showEditEntryDialog(context, entry, index);
                                break;
                              case 'delete':
                                _showDeleteConfirmation(context, entry);
                                break;
                            }
                          },
                          itemBuilder: (BuildContext context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                leading: Icon(Icons.edit, size: 20),
                                title: Text('Edit'),
                                dense: true,
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(Icons.delete, size: 20),
                                title: Text('Delete'),
                                dense: true,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          _showEntryDetails(context, entry);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEntryDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showAddEntryDialog(BuildContext context) {
    String title = '';
    String content = '';
    String tagsText = '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Entry'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => title = value,
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Content',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 5,
                  onChanged: (value) => content = value,
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Tags (comma separated)',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., setup, testing, hardware',
                  ),
                  onChanged: (value) => tagsText = value,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (title.isNotEmpty && content.isNotEmpty) {
                  final tags = tagsText
                      .split(',')
                      .map((tag) => tag.trim())
                      .where((tag) => tag.isNotEmpty)
                      .toList();
                  
                  Provider.of<DiaryProvider>(context, listen: false)
                      .addEntry(title, content, tags);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showEditEntryDialog(BuildContext context, DiaryEntry entry, int index) {
    String title = entry.title;
    String content = entry.content;
    String tagsText = entry.tags.join(', ');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Entry'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  controller: TextEditingController(text: title),
                  onChanged: (value) => title = value,
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Content',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 5,
                  controller: TextEditingController(text: content),
                  onChanged: (value) => content = value,
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Tags (comma separated)',
                    border: OutlineInputBorder(),
                  ),
                  controller: TextEditingController(text: tagsText),
                  onChanged: (value) => tagsText = value,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (title.isNotEmpty && content.isNotEmpty) {
                  final tags = tagsText
                      .split(',')
                      .map((tag) => tag.trim())
                      .where((tag) => tag.isNotEmpty)
                      .toList();
                  
                  final updatedEntry = entry.copyWith(
                    title: title,
                    content: content,
                    tags: tags,
                  );
                  
                  Provider.of<DiaryProvider>(context, listen: false)
                      .updateEntry(updatedEntry);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, DiaryEntry entry) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Entry'),
          content: Text('Are you sure you want to delete "${entry.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Provider.of<DiaryProvider>(context, listen: false)
                    .deleteEntry(entry.id);
                Navigator.of(context).pop();
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showEntryDetails(BuildContext context, DiaryEntry entry) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(entry.title),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(entry.content),
                const SizedBox(height: 16),
                if (entry.tags.isNotEmpty) ...[
                  const Text(
                    'Tags:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: entry.tags
                        .map((tag) => Chip(
                              label: Text(tag),
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.2),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Created: ${_formatDate(entry.createdAt)}',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                if (entry.createdAt != entry.updatedAt)
                  Text(
                    'Updated: ${_formatDate(entry.updatedAt)}',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}