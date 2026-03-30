import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class DiaryEntry {
  final String id;
  final String? owner;
  final String title;
  final String content;
  final int workingMinutes;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime updatedAt;

  DiaryEntry({
    required this.id,
    this.owner,
    required this.title,
    required this.content,
    required this.workingMinutes,
    required this.isPublic,
    required this.createdAt,
    required this.updatedAt,
  });

  DiaryEntry copyWith({
    String? id,
    String? owner,
    String? title,
    String? content,
    int? workingMinutes,
    bool? isPublic,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DiaryEntry(
      id: id ?? this.id,
      owner: owner ?? this.owner,
      title: title ?? this.title,
      content: content ?? this.content,
      workingMinutes: workingMinutes ?? this.workingMinutes,
      isPublic: isPublic ?? this.isPublic,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner': owner,
      'title': title,
      'content': content,
      'workingMinutes': workingMinutes,
      'isPublic': isPublic,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    // Parse title and content from backend's "text" field
    // Backend stores everything in "text", we split it into title and content
    final text = json['text'] as String? ?? '';
    final lines = text.split('\n');
    final rawTitle = lines.isNotEmpty ? lines.first : 'No title';
    final content = lines.length > 1 ? lines.sublist(1).join('\n') : '';

    final isPublic = rawTitle.toLowerCase().contains('(public)');
    final title = rawTitle.replaceAll(RegExp(r'\s*\(public\)\s*', caseSensitive: false), '').trim();

    return DiaryEntry(
      id: json['id'] as String,
      owner: json['owner'] as String?,
      title: title.isEmpty ? 'No title' : title,
      content: content,
      workingMinutes: json['working_minutes'] as int? ?? 0,
      isPublic: isPublic,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class DiaryProvider with ChangeNotifier {
  final ApiService _apiService;

  List<DiaryEntry> _publicEntries = [];
  List<DiaryEntry> _privateEntries = [];
  bool _isLoading = false;
  String? _error;

  DiaryProvider(this._apiService);

  List<DiaryEntry> get publicEntries => _publicEntries;
  List<DiaryEntry> get privateEntries => _privateEntries;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadEntries() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Fetch all public entries
      final publicData = await _apiService.getPublicDiaryEntries();
      _publicEntries = publicData.map((json) => DiaryEntry.fromJson(json)).toList();

      // If logged in, fetch user's private entries
      if (_apiService.isLoggedIn) {
        final privateData = await _apiService.getDiaryEntries();
        _privateEntries = privateData.map((json) => DiaryEntry.fromJson(json)).toList();
      } else {
        _privateEntries = [];
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add new entry
  Future<bool> addEntry(String title, String content, int workingMinutes, bool isPublic) async {
    try {
      _error = null;

      // Combine title and content for backend's "text" field
      final finalTitle = isPublic ? '$title (public)' : title;
      final text = '$finalTitle\n$content';

      final data = await _apiService.createDiaryEntry(
        workingMinutes: workingMinutes,
        text: text,
      );

      final newEntry = DiaryEntry.fromJson(data);
      // Add to private list and public if it's public
      _privateEntries.insert(0, newEntry);
      if (newEntry.isPublic) {
        _publicEntries.insert(0, newEntry);
      }
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
      final finalTitle = entry.isPublic ? '${entry.title} (public)' : entry.title;
      final text = '$finalTitle\n${entry.content}';

      final data = await _apiService.updateDiaryEntry(
        id: entry.id,
        workingMinutes: entry.workingMinutes,
        text: text,
      );

      final updatedEntry = DiaryEntry.fromJson(data);
      
      final privateIndex = _privateEntries.indexWhere((e) => e.id == entry.id);
      if (privateIndex != -1) {
        _privateEntries[privateIndex] = updatedEntry;
      }

      final publicIndex = _publicEntries.indexWhere((e) => e.id == entry.id);
      if (publicIndex != -1) {
        if (updatedEntry.isPublic) {
          _publicEntries[publicIndex] = updatedEntry;
        } else {
          _publicEntries.removeAt(publicIndex);
        }
      } else if (updatedEntry.isPublic) {
        _publicEntries.insert(0, updatedEntry);
      }

      notifyListeners();
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
      _privateEntries.removeWhere((entry) => entry.id == id);
      _publicEntries.removeWhere((entry) => entry.id == id);
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