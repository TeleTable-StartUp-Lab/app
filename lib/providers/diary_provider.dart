import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class DiaryEntry {
  final String id;
  final String title;
  final String content;
  final int workingMinutes;
  final DateTime createdAt;
  final DateTime updatedAt;

  DiaryEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.workingMinutes,
    required this.createdAt,
    required this.updatedAt,
  });

  DiaryEntry copyWith({
    String? id,
    String? title,
    String? content,
    int? workingMinutes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DiaryEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      workingMinutes: workingMinutes ?? this.workingMinutes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'workingMinutes': workingMinutes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    // Parse title and content from backend's "text" field
    // Backend stores everything in "text", we split it into title and content
    final text = json['text'] as String? ?? '';
    final lines = text.split('\n');
    final title = lines.isNotEmpty ? lines.first : 'No title';
    final content = lines.length > 1 ? lines.sublist(1).join('\n') : '';
    
    return DiaryEntry(
      id: json['id'] as String,
      title: title,
      content: content,
      workingMinutes: json['working_minutes'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class DiaryProvider with ChangeNotifier {
  final ApiService _apiService;
  
  List<DiaryEntry> _entries = [];
  bool _isLoading = false;
  String? _error;

  DiaryProvider(this._apiService);

  List<DiaryEntry> get entries => _entries;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Load entries from server
  Future<void> loadEntries() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _apiService.getDiaryEntries();
      _entries = data.map((json) => DiaryEntry.fromJson(json)).toList();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add new entry
  Future<bool> addEntry(String title, String content, int workingMinutes) async {
    try {
      _error = null;
      
      // Combine title and content for backend's "text" field
      final text = '$title\n$content';
      
      final data = await _apiService.createDiaryEntry(
        workingMinutes: workingMinutes,
        text: text,
      );
      
      final newEntry = DiaryEntry.fromJson(data);
      _entries.insert(0, newEntry);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // Update entry
  Future<bool> updateEntry(DiaryEntry entry) async {
    try {
      _error = null;
      
      // Combine title and content for backend's "text" field
      final text = '${entry.title}\n${entry.content}';
      
      final data = await _apiService.updateDiaryEntry(
        id: entry.id,
        workingMinutes: entry.workingMinutes,
        text: text,
      );
      
      final updatedEntry = DiaryEntry.fromJson(data);
      final index = _entries.indexWhere((e) => e.id == entry.id);
      if (index != -1) {
        _entries[index] = updatedEntry;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // Delete entry
  Future<bool> deleteEntry(String id) async {
    try {
      _error = null;
      await _apiService.deleteDiaryEntry(id);
      _entries.removeWhere((entry) => entry.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}