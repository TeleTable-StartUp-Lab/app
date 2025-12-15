import 'package:flutter/foundation.dart';

class DiaryEntry {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;

  DiaryEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
  });

  DiaryEntry copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
  }) {
    return DiaryEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'tags': tags,
    };
  }

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    return DiaryEntry(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      tags: List<String>.from(json['tags'] ?? []),
    );
  }
}

class DiaryProvider with ChangeNotifier {
  List<DiaryEntry> _entries = [];
  bool _isLoading = false;
  String? _error;

  List<DiaryEntry> get entries => _entries;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Load entries from server
  Future<void> loadEntries() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // TODO: Implement actual API call to fetch entries from server
      await Future.delayed(const Duration(seconds: 1)); // Mock delay
      
      // Mock data for now
      _entries = [
        DiaryEntry(
          id: '1',
          title: 'Robot Setup Day 1',
          content: 'Today we started setting up the robot. Everything went smoothly.',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          updatedAt: DateTime.now().subtract(const Duration(days: 2)),
          tags: ['setup', 'hardware'],
        ),
        DiaryEntry(
          id: '2',
          title: 'Testing Movement Controls',
          content: 'Tested the joystick controls. The robot responds well to manual commands.',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          updatedAt: DateTime.now().subtract(const Duration(days: 1)),
          tags: ['testing', 'controls'],
        ),
      ];
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add new entry
  Future<void> addEntry(String title, String content, List<String> tags) async {
    try {
      final newEntry = DiaryEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        content: content,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        tags: tags,
      );

      // TODO: Send to server
      _entries.insert(0, newEntry);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Update entry
  Future<void> updateEntry(DiaryEntry updatedEntry) async {
    try {
      final index = _entries.indexWhere((entry) => entry.id == updatedEntry.id);
      if (index != -1) {
        _entries[index] = updatedEntry.copyWith(updatedAt: DateTime.now());
        notifyListeners();
        // TODO: Send update to server
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Delete entry
  Future<void> deleteEntry(String id) async {
    try {
      _entries.removeWhere((entry) => entry.id == id);
      notifyListeners();
      // TODO: Send delete request to server
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}