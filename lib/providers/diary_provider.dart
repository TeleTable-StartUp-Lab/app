import 'package:flutter/foundation.dart';

import '../services/api_service.dart';

class DiaryEntry {
  static const int maxPreviewCharacters = 90;

  final String id;
  final String? owner;
  final String content;
  final int workingMinutes;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime updatedAt;

  DiaryEntry({
    required this.id,
    this.owner,
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
      content: content ?? this.content,
      workingMinutes: workingMinutes ?? this.workingMinutes,
      isPublic: isPublic ?? this.isPublic,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get title => previewLabel;
  String get previewLabel {
    final heading = _firstMarkdownHeading(content);
    if (heading != null && heading.isNotEmpty) {
      return _truncate(heading, maxPreviewCharacters);
    }

    final plainText = _plainText(content);
    if (plainText.isEmpty) {
      return 'Untitled entry';
    }
    return _truncate(plainText, maxPreviewCharacters);
  }

  String get detailTitle => previewLabel;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner': owner,
      'content': content,
      'workingMinutes': workingMinutes,
      'isPublic': isPublic,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory DiaryEntry.fromJson(
    Map<String, dynamic> json, {
    bool? isPublic,
  }) {
    final rawText = (json['text'] as String?) ?? '';

    return DiaryEntry(
      id: json['id'] as String,
      owner: json['owner'] as String?,
      content: _stripPublicMarker(rawText),
      workingMinutes: json['working_minutes'] as int? ?? 0,
      isPublic: isPublic ?? _hasPublicMarker(rawText),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  static bool _hasPublicMarker(String text) {
    final lines = text.split('\n');
    for (final line in lines) {
      if (line.trim().isEmpty) {
        continue;
      }
      return line.toLowerCase().contains('(public)');
    }
    return false;
  }

  static String _stripPublicMarker(String text) {
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) {
        continue;
      }
      lines[i] = lines[i].replaceAll(RegExp(r'\s*\(public\)\s*', caseSensitive: false), '').trimRight();
      break;
    }
    return lines.join('\n').trim();
  }

  static String? _firstMarkdownHeading(String text) {
    final headingMatch = RegExp(
      r'^\s{0,3}#{1,6}\s+(.+?)\s*$',
      multiLine: true,
    ).firstMatch(text);
    return headingMatch?.group(1)?.trim();
  }

  static String _plainText(String text) {
    final cleaned = text
        .replaceAll(RegExp(r'!\[([^\]]*)\]\([^)]+\)'), r'$1')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1')
        .replaceAll(RegExp(r'[`*_>#-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned;
  }

  static String _truncate(String text, int maxChars) {
    if (text.length <= maxChars) {
      return text;
    }
    if (maxChars <= 3) {
      return text.substring(0, maxChars);
    }
    return '${text.substring(0, maxChars - 3).trimRight()}...';
  }
}

class DiaryProvider with ChangeNotifier {
  final ApiService _apiService;

  List<DiaryEntry> _publicEntries = [];
  List<DiaryEntry> _privateEntries = [];
  bool _isLoading = false;
  String? _error;

  DiaryProvider(this._apiService);

  List<DiaryEntry> get publicEntries => List.unmodifiable(_publicEntries);
  List<DiaryEntry> get privateEntries => List.unmodifiable(_privateEntries);
  List<DiaryEntry> get entries => List.unmodifiable(_privateEntries);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadEntries() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final publicData = await _apiService.getPublicDiaryEntries();
      _publicEntries = publicData
          .map((json) => DiaryEntry.fromJson(json, isPublic: true))
          .toList();
      final publicIds = _publicEntries.map((entry) => entry.id).toSet();

      if (_apiService.isLoggedIn) {
        final privateData = await _apiService.getDiaryEntries();
        _privateEntries = privateData.map((json) {
          final id = json['id'] as String? ?? '';
          return DiaryEntry.fromJson(
            json,
            isPublic: publicIds.contains(id) ? true : null,
          );
        }).toList();
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

  Future<bool> addEntry(
    String value1,
    dynamic value2, [
    dynamic value3,
    dynamic value4,
  ]) async {
    try {
      _error = null;

      final input = _normalizeAddEntryInput(value1, value2, value3, value4);

      final data = await _apiService.createDiaryEntry(
        workingMinutes: input.workingMinutes,
        text: _encodeEntryText(input.content, input.isPublic),
      );

      final newEntry = DiaryEntry.fromJson(data, isPublic: input.isPublic);
      _privateEntries = [newEntry, ..._privateEntries];
      if (newEntry.isPublic) {
        _publicEntries = [newEntry, ..._publicEntries];
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateEntry(DiaryEntry entry) async {
    try {
      _error = null;

      final data = await _apiService.updateDiaryEntry(
        id: entry.id,
        workingMinutes: entry.workingMinutes,
        text: _encodeEntryText(entry.content, entry.isPublic),
      );

      final updatedEntry = DiaryEntry.fromJson(data, isPublic: entry.isPublic);

      final privateIndex = _privateEntries.indexWhere((item) => item.id == entry.id);
      if (privateIndex != -1) {
        _privateEntries[privateIndex] = updatedEntry;
      }

      final publicIndex = _publicEntries.indexWhere((item) => item.id == entry.id);
      if (publicIndex != -1) {
        if (updatedEntry.isPublic) {
          _publicEntries[publicIndex] = updatedEntry;
        } else {
          _publicEntries.removeAt(publicIndex);
        }
      } else if (updatedEntry.isPublic) {
        _publicEntries = [updatedEntry, ..._publicEntries];
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

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

  void clearEntries() {
    _publicEntries = [];
    _privateEntries = [];
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _encodeEntryText(String content, bool isPublic) {
    final trimmed = content.trim();
    if (!isPublic || trimmed.isEmpty) {
      return trimmed;
    }

    final lines = trimmed.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) {
        continue;
      }
      if (!lines[i].toLowerCase().contains('(public)')) {
        lines[i] = '${lines[i].trimRight()} (public)';
      }
      return lines.join('\n');
    }

    return '(public)';
  }

  _AddEntryInput _normalizeAddEntryInput(
    String value1,
    dynamic value2,
    dynamic value3,
    dynamic value4,
  ) {
    if (value2 is int) {
      return _AddEntryInput(
        content: value1.trim(),
        workingMinutes: value2,
        isPublic: value3 is bool ? value3 : false,
      );
    }

    final title = value1.trim();
    final content = value2 is String ? value2.trim() : '';
    final combinedContent = title.isEmpty
        ? content
        : content.isEmpty
            ? title
            : '$title\n$content';

    return _AddEntryInput(
      content: combinedContent,
      workingMinutes: value3 is int ? value3 : 60,
      isPublic: value4 is bool ? value4 : false,
    );
  }
}

class _AddEntryInput {
  final String content;
  final int workingMinutes;
  final bool isPublic;

  const _AddEntryInput({
    required this.content,
    required this.workingMinutes,
    required this.isPublic,
  });
}
