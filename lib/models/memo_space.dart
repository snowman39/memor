import 'package:isar/isar.dart';

part 'memo_space.g.dart';

@Collection()
class MemoSpace {
  Id id = Isar.autoIncrement;

  late String name;
  late String memo;

  // late Position location (latitude, longitude)
  // late List<Task> tasks
}
