import 'package:flutter_test/flutter_test.dart';
import 'package:teletable_app/providers/diary_provider.dart';

void main() {
  test('preview uses the first markdown heading when present', () {
    final entry = DiaryEntry.fromJson({
      'id': 'entry-1',
      'owner': 'Lukas',
      'text': 'Intro paragraph\n\n## Sprint Review\nMore notes here',
      'working_minutes': 45,
      'created_at': '2026-04-01T10:00:00Z',
      'updated_at': '2026-04-01T10:00:00Z',
    });

    expect(entry.previewLabel, 'Sprint Review');
    expect(entry.content, 'Intro paragraph\n\n## Sprint Review\nMore notes here');
  });

  test('preview falls back to a truncated plain-text snippet when no heading exists', () {
    final entry = DiaryEntry.fromJson({
      'id': 'entry-2',
      'owner': 'Lukas',
      'text': 'This is a very long diary entry without any markdown heading, so the preview should be truncated before the whole content is shown.',
      'working_minutes': 30,
      'created_at': '2026-04-01T10:00:00Z',
      'updated_at': '2026-04-01T10:00:00Z',
    });

    expect(entry.previewLabel.endsWith('...'), isTrue);
    expect(entry.previewLabel.length, lessThanOrEqualTo(DiaryEntry.maxPreviewCharacters));
  });

  test('public marker is stripped from rendered content', () {
    final entry = DiaryEntry.fromJson({
      'id': 'entry-3',
      'owner': 'Lukas',
      'text': '# Public heading (public)\nBody',
      'working_minutes': 15,
      'created_at': '2026-04-01T10:00:00Z',
      'updated_at': '2026-04-01T10:00:00Z',
    });

    expect(entry.isPublic, isTrue);
    expect(entry.content, '# Public heading\nBody');
    expect(entry.previewLabel, 'Public heading');
  });
}
