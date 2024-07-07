import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:memor/models/memo_space.dart';

class MemoSpaceDatabase extends ChangeNotifier {
  static late Isar isar;

  // Initialize the database
  static Future<void> init() async {
    final directory = await getApplicationDocumentsDirectory();
    isar = await Isar.open(
      [MemoSpaceSchema],
      directory: directory.path,
    );
  }

  final List<MemoSpace> memoSpaces = [];

  // Create a new memo space
  Future<void> createMemoSpace() async {
    final memoSpace = MemoSpace()
      ..name = 'New Memo Space'
      ..memo = 'type here';

    await isar.writeTxn(() => isar.memoSpaces.put(memoSpace));
    await readMemoSpaces();
  }

  // Read all memo spaces
  Future<void> readMemoSpaces() async {
    List<MemoSpace> allMemoSpaces = await isar.memoSpaces.where().findAll();
    memoSpaces.clear();
    memoSpaces.addAll(allMemoSpaces);
    notifyListeners();
  }

  // Update a memo space
  Future<void> updateMemoSpace(int id, String name, String memo) async {
    final memoSpace = await isar.memoSpaces.get(id);
    if (memoSpace == null) {
      return;
    }

    memoSpace.name = name;
    memoSpace.memo = memo;
    await isar.writeTxn(() => isar.memoSpaces.put(memoSpace));
    await readMemoSpaces();
  }

  // Delete a memo space
  Future<void> deleteMemoSpace(int id) async {
    await isar.writeTxn(() => isar.memoSpaces.delete(id));
    await readMemoSpaces();
  }
}
