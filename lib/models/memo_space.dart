import 'package:objectbox/objectbox.dart';
import 'package:uuid/uuid.dart';
import 'package:memor/models/memo.dart';

@Entity()
class MemoSpace {
  @Id()
  int id = 0;

  @Unique()
  String uuid = '';

  String name = '';

  /// Legacy memo field - kept for migration from Isar
  String? legacyMemo;

  bool opened = true;

  @Property(type: PropertyType.date)
  DateTime createdAt = DateTime.now();

  @Property(type: PropertyType.date)
  DateTime updatedAt = DateTime.now();

  @Property(type: PropertyType.date)
  DateTime? deletedAt; // soft delete

  int version = 0; // for conflict detection

  /// Backlink to all Memos belonging to this MemoSpace
  @Backlink('memoSpace')
  final memos = ToMany<Memo>();

  MemoSpace();

  /// Factory constructor for creating a new MemoSpace
  static MemoSpace create({required String name}) {
    final now = DateTime.now();
    return MemoSpace()
      ..uuid = const Uuid().v4()
      ..name = name
      ..createdAt = now
      ..updatedAt = now;
  }
}
