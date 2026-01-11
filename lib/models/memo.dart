import 'package:objectbox/objectbox.dart';
import 'package:uuid/uuid.dart';
import 'package:memor/models/memo_space.dart';
import 'package:memor/models/memo_annotation.dart';

@Entity()
class Memo {
  @Id()
  int id = 0;

  @Unique()
  String uuid = '';

  String content = '';

  /// Order index within the MemoSpace (0-based)
  int order = 0;

  @Property(type: PropertyType.date)
  DateTime createdAt = DateTime.now();

  @Property(type: PropertyType.date)
  DateTime updatedAt = DateTime.now();

  @Property(type: PropertyType.date)
  DateTime? deletedAt; // soft delete

  int version = 0; // for conflict detection

  /// Link to the parent MemoSpace
  final memoSpace = ToOne<MemoSpace>();

  /// Backlink to all annotations for this Memo
  @Backlink('memo')
  final annotations = ToMany<MemoAnnotation>();

  Memo();

  /// Factory constructor for creating a new Memo
  static Memo create({
    required String content,
    required int order,
  }) {
    final now = DateTime.now();
    return Memo()
      ..uuid = const Uuid().v4()
      ..content = content
      ..createdAt = now
      ..updatedAt = now
      ..order = order;
  }
}
