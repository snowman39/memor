import 'package:objectbox/objectbox.dart';
import 'package:uuid/uuid.dart';
import 'package:memor/models/memo.dart';

/// Annotation types for rich text styling
class AnnotationType {
  static const String bold = 'bold';
  static const String italic = 'italic';
  static const String strikethrough = 'strikethrough';
  static const String underline = 'underline';
  static const String link = 'link';
}

@Entity()
class MemoAnnotation {
  @Id()
  int id = 0;

  @Unique()
  String uuid = '';

  /// Start offset in the memo content (inclusive)
  int startOffset = 0;

  /// End offset in the memo content (exclusive)
  int endOffset = 0;

  /// Type of annotation (bold, italic, strikethrough, underline, link)
  String type = '';

  /// Additional metadata (e.g., URL for links)
  String? metadata;

  @Property(type: PropertyType.date)
  DateTime createdAt = DateTime.now();

  @Property(type: PropertyType.date)
  DateTime updatedAt = DateTime.now();

  /// Link to the parent Memo
  final memo = ToOne<Memo>();

  MemoAnnotation();

  /// Factory constructor for creating a new MemoAnnotation
  static MemoAnnotation create({
    required int startOffset,
    required int endOffset,
    required String type,
    String? metadata,
  }) {
    final now = DateTime.now();
    return MemoAnnotation()
      ..uuid = const Uuid().v4()
      ..startOffset = startOffset
      ..endOffset = endOffset
      ..type = type
      ..metadata = metadata
      ..createdAt = now
      ..updatedAt = now;
  }

  /// Check if this annotation overlaps with a range
  bool overlaps(int start, int end) {
    return startOffset < end && endOffset > start;
  }

  /// Check if this annotation contains a position
  bool contains(int position) {
    return startOffset <= position && position < endOffset;
  }

  /// Adjust offsets when text is inserted
  void adjustForInsertion(int position, int length) {
    if (position <= startOffset) {
      // Insertion before annotation - shift both
      startOffset += length;
      endOffset += length;
    } else if (position < endOffset) {
      // Insertion inside annotation - extend end
      endOffset += length;
    }
    // Insertion after annotation - no change
  }

  /// Adjust offsets when text is deleted
  /// Returns true if annotation should be kept, false if it should be deleted
  bool adjustForDeletion(int position, int length) {
    final deleteEnd = position + length;

    if (deleteEnd <= startOffset) {
      // Deletion before annotation - shift both
      startOffset -= length;
      endOffset -= length;
      return true;
    } else if (position >= endOffset) {
      // Deletion after annotation - no change
      return true;
    } else if (position <= startOffset && deleteEnd >= endOffset) {
      // Deletion covers entire annotation - delete it
      return false;
    } else if (position <= startOffset) {
      // Deletion overlaps start
      final overlap = deleteEnd - startOffset;
      startOffset = position;
      endOffset -= overlap + (startOffset - position);
      return startOffset < endOffset;
    } else if (deleteEnd >= endOffset) {
      // Deletion overlaps end
      endOffset = position;
      return startOffset < endOffset;
    } else {
      // Deletion inside annotation - shrink
      endOffset -= length;
      return startOffset < endOffset;
    }
  }
}
