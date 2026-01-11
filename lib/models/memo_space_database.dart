import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:memor/models/memo.dart';
import 'package:memor/models/memo_annotation.dart';
import 'package:memor/models/memo_space.dart';
import 'package:memor/objectbox.g.dart';

class MemoSpaceDatabase extends ChangeNotifier {
  static late Store store;
  static late Box<MemoSpace> memoSpaceBox;
  static late Box<Memo> memoBox;
  static late Box<MemoAnnotation> annotationBox;

  // Initialize the database
  static Future<void> init() async {
    // Get the application support directory for ObjectBox (works better with macOS sandbox)
    final appSupportDir = await getApplicationSupportDirectory();
    final objectBoxDir = '${appSupportDir.path}/objectbox';

    store = await openStore(directory: objectBoxDir);
    memoSpaceBox = store.box<MemoSpace>();
    memoBox = store.box<Memo>();
    annotationBox = store.box<MemoAnnotation>();
  }

  final List<MemoSpace> memoSpaces = [];

  // Create a new memo space with an initial empty memo
  Future<MemoSpace> createMemoSpace() async {
    final memoSpace = MemoSpace.create(name: 'New Memospace');

    // Put the memo space first to get its ID
    memoSpaceBox.put(memoSpace);

    // Create an initial empty memo
    final initialMemo = Memo.create(content: '', order: 0);
    initialMemo.memoSpace.target = memoSpace;
    memoBox.put(initialMemo);

    await readMemoSpaces();
    return memoSpace;
  }

  // Read all memo spaces (excluding soft-deleted ones)
  Future<void> readMemoSpaces() async {
    final query = memoSpaceBox.query(MemoSpace_.deletedAt.isNull()).build();
    final allMemoSpaces = query.find();
    query.close();

    memoSpaces.clear();
    memoSpaces.addAll(allMemoSpaces);
    notifyListeners();
  }

  // Update a memo space name
  Future<void> updateMemoSpaceName(int id, String name) async {
    final memoSpace = memoSpaceBox.get(id);
    if (memoSpace == null) return;

    memoSpace.name = name;
    memoSpace.updatedAt = DateTime.now();
    memoSpace.version += 1;
    memoSpaceBox.put(memoSpace);
    await readMemoSpaces();
  }

  // Update opened state only (no full refresh)
  Future<void> updateOpenedState(int id, bool opened) async {
    final memoSpace = memoSpaceBox.get(id);
    if (memoSpace == null) return;

    memoSpace.opened = opened;
    memoSpace.updatedAt = DateTime.now();
    memoSpaceBox.put(memoSpace);
  }

  // Delete a memo space and all its memos (soft delete)
  Future<void> deleteMemoSpace(int id) async {
    final memoSpace = memoSpaceBox.get(id);
    if (memoSpace == null) return;

    final now = DateTime.now();

    // Soft delete all memos belonging to this memo space
    final query = memoBox.query(Memo_.memoSpace.equals(id)).build();
    final memos = query.find();
    query.close();

    for (final memo in memos) {
      memo.deletedAt = now;
      memo.updatedAt = now;
      memoBox.put(memo);
    }

    // Soft delete the memo space
    memoSpace.deletedAt = now;
    memoSpace.updatedAt = now;
    memoSpaceBox.put(memoSpace);

    await readMemoSpaces();
  }

  // ==================== Memo CRUD ====================

  // Get all memos for a memo space, ordered by 'order' field (excluding soft-deleted)
  Future<List<Memo>> getMemosBySpace(int memoSpaceId) async {
    final query = memoBox
        .query(Memo_.memoSpace.equals(memoSpaceId) & Memo_.deletedAt.isNull())
        .order(Memo_.order)
        .build();
    final memos = query.find();
    query.close();
    return memos;
  }

  // Create a new memo in a memo space
  Future<Memo> createMemo({
    required int memoSpaceId,
    required String content,
    required int order,
  }) async {
    final memoSpace = memoSpaceBox.get(memoSpaceId);
    if (memoSpace == null) {
      throw Exception('MemoSpace not found');
    }

    final memo = Memo.create(content: content, order: order);
    memo.memoSpace.target = memoSpace;
    memoBox.put(memo);

    return memo;
  }

  // Update memo content
  Future<void> updateMemoContent(int memoId, String content) async {
    final memo = memoBox.get(memoId);
    if (memo == null) return;

    memo.content = content;
    memo.updatedAt = DateTime.now();
    memo.version += 1;
    memoBox.put(memo);
  }

  // Update memo order
  Future<void> updateMemoOrder(int memoId, int newOrder) async {
    final memo = memoBox.get(memoId);
    if (memo == null) return;

    memo.order = newOrder;
    memo.updatedAt = DateTime.now();
    memoBox.put(memo);
  }

  // Delete a memo (soft delete)
  Future<void> deleteMemo(int memoId) async {
    final memo = memoBox.get(memoId);
    if (memo == null) return;

    memo.deletedAt = DateTime.now();
    memo.updatedAt = DateTime.now();
    memoBox.put(memo);
  }

  // Split a memo at a position (for --- divider creation)
  // Returns the newly created memo (the second part)
  Future<Memo> splitMemo({
    required int memoId,
    required String firstPart,
    required String secondPart,
  }) async {
    final memo = memoBox.get(memoId);
    if (memo == null) {
      throw Exception('Memo not found');
    }

    final memoSpace = memo.memoSpace.target;
    if (memoSpace == null) {
      throw Exception('MemoSpace not found');
    }

    // Get all memos after this one and increment their order
    final query = memoBox
        .query(Memo_.memoSpace.equals(memoSpace.id) &
            Memo_.order.greaterThan(memo.order) &
            Memo_.deletedAt.isNull())
        .build();
    final memosAfter = query.find();
    query.close();

    // Update original memo with first part
    memo.content = firstPart;
    memo.updatedAt = DateTime.now();
    memo.version += 1;

    // Increment order of all memos after this one
    for (final m in memosAfter) {
      m.order += 1;
    }

    // Create the new memo
    final newMemo = Memo.create(content: secondPart, order: memo.order + 1);
    newMemo.memoSpace.target = memoSpace;

    // Batch put all changes
    memoBox.putMany([memo, ...memosAfter, newMemo]);

    return newMemo;
  }

  // Merge two adjacent memos (for divider deletion)
  // Keeps the older createdAt
  Future<Memo> mergeMemos({
    required int firstMemoId,
    required int secondMemoId,
  }) async {
    final firstMemo = memoBox.get(firstMemoId);
    final secondMemo = memoBox.get(secondMemoId);

    if (firstMemo == null || secondMemo == null) {
      throw Exception('Memo not found');
    }

    final memoSpace = firstMemo.memoSpace.target;
    if (memoSpace == null) {
      throw Exception('MemoSpace not found');
    }

    // Keep the older createdAt
    final olderCreatedAt = firstMemo.createdAt.isBefore(secondMemo.createdAt)
        ? firstMemo.createdAt
        : secondMemo.createdAt;

    // Merge content
    final mergedContent = '${firstMemo.content}${secondMemo.content}';

    // Get all memos after the second one and decrement their order
    final query = memoBox
        .query(Memo_.memoSpace.equals(memoSpace.id) &
            Memo_.order.greaterThan(secondMemo.order) &
            Memo_.deletedAt.isNull())
        .build();
    final memosAfter = query.find();
    query.close();

    // Update first memo with merged content
    firstMemo.content = mergedContent;
    firstMemo.createdAt = olderCreatedAt;
    firstMemo.updatedAt = DateTime.now();
    firstMemo.version += 1;

    // Soft delete second memo
    secondMemo.deletedAt = DateTime.now();
    secondMemo.updatedAt = DateTime.now();

    // Decrement order of all memos after the deleted one
    for (final m in memosAfter) {
      m.order -= 1;
    }

    // Batch put all changes
    memoBox.putMany([firstMemo, secondMemo, ...memosAfter]);

    return firstMemo;
  }

  // ==================== Annotation CRUD ====================

  /// Get all annotations for a memo
  Future<List<MemoAnnotation>> getAnnotationsByMemo(int memoId) async {
    final query = annotationBox
        .query(MemoAnnotation_.memo.equals(memoId))
        .order(MemoAnnotation_.startOffset)
        .build();
    final annotations = query.find();
    query.close();
    return annotations;
  }

  /// Add an annotation to a memo
  Future<MemoAnnotation> addAnnotation({
    required int memoId,
    required int startOffset,
    required int endOffset,
    required String type,
    String? metadata,
  }) async {
    final memo = memoBox.get(memoId);
    if (memo == null) {
      throw Exception('Memo not found');
    }

    final annotation = MemoAnnotation.create(
      startOffset: startOffset,
      endOffset: endOffset,
      type: type,
      metadata: metadata,
    );
    annotation.memo.target = memo;
    annotationBox.put(annotation);

    return annotation;
  }

  /// Toggle an annotation for a range (add if not exists, remove if exists)
  Future<void> toggleAnnotation({
    required int memoId,
    required int startOffset,
    required int endOffset,
    required String type,
  }) async {
    final memo = memoBox.get(memoId);
    if (memo == null) return;

    // Find existing annotations of this type that overlap with the range
    final query = annotationBox
        .query(MemoAnnotation_.memo.equals(memoId) &
            MemoAnnotation_.type.equals(type))
        .build();
    final existingAnnotations = query.find();
    query.close();

    // Check if the entire range is already covered by this type
    final overlapping = existingAnnotations
        .where((a) => a.overlaps(startOffset, endOffset))
        .toList();

    if (overlapping.isNotEmpty) {
      // Check if selection is fully covered
      bool fullyCovered = false;
      for (final a in overlapping) {
        if (a.startOffset <= startOffset && a.endOffset >= endOffset) {
          fullyCovered = true;
          break;
        }
      }

      if (fullyCovered) {
        // Remove/split the annotation
        for (final a in overlapping) {
          if (a.startOffset < startOffset && a.endOffset > endOffset) {
            // Split: create two annotations
            final newAnnotation = MemoAnnotation.create(
              startOffset: endOffset,
              endOffset: a.endOffset,
              type: type,
              metadata: a.metadata,
            );
            newAnnotation.memo.target = memo;
            a.endOffset = startOffset;
            a.updatedAt = DateTime.now();
            annotationBox.putMany([a, newAnnotation]);
          } else if (a.startOffset >= startOffset && a.endOffset <= endOffset) {
            // Fully covered - delete
            annotationBox.remove(a.id);
          } else if (a.startOffset < startOffset) {
            // Trim end
            a.endOffset = startOffset;
            a.updatedAt = DateTime.now();
            annotationBox.put(a);
          } else {
            // Trim start
            a.startOffset = endOffset;
            a.updatedAt = DateTime.now();
            annotationBox.put(a);
          }
        }
      } else {
        // Extend existing or add new to cover the range
        await _mergeOrAddAnnotation(
          memoId: memoId,
          startOffset: startOffset,
          endOffset: endOffset,
          type: type,
          existingAnnotations: overlapping,
        );
      }
    } else {
      // No overlapping - add new annotation
      await addAnnotation(
        memoId: memoId,
        startOffset: startOffset,
        endOffset: endOffset,
        type: type,
      );
    }
  }

  /// Helper to merge overlapping annotations or add new one
  Future<void> _mergeOrAddAnnotation({
    required int memoId,
    required int startOffset,
    required int endOffset,
    required String type,
    required List<MemoAnnotation> existingAnnotations,
  }) async {
    final memo = memoBox.get(memoId);
    if (memo == null) return;

    // Calculate the merged range
    int mergedStart = startOffset;
    int mergedEnd = endOffset;

    for (final a in existingAnnotations) {
      mergedStart = mergedStart < a.startOffset ? mergedStart : a.startOffset;
      mergedEnd = mergedEnd > a.endOffset ? mergedEnd : a.endOffset;
    }

    // Delete all overlapping annotations
    annotationBox.removeMany(existingAnnotations.map((a) => a.id).toList());

    // Create merged annotation
    final merged = MemoAnnotation.create(
      startOffset: mergedStart,
      endOffset: mergedEnd,
      type: type,
    );
    merged.memo.target = memo;
    annotationBox.put(merged);
  }

  /// Update annotation offsets when text changes
  Future<void> updateAnnotationsForTextChange({
    required int memoId,
    required int position,
    required int oldLength,
    required int newLength,
  }) async {
    final annotations = await getAnnotationsByMemo(memoId);
    final toUpdate = <MemoAnnotation>[];
    final toDelete = <int>[];

    for (final annotation in annotations) {
      if (oldLength > 0 && newLength == 0) {
        // Deletion
        if (!annotation.adjustForDeletion(position, oldLength)) {
          toDelete.add(annotation.id);
        } else {
          toUpdate.add(annotation);
        }
      } else if (oldLength == 0 && newLength > 0) {
        // Insertion
        annotation.adjustForInsertion(position, newLength);
        toUpdate.add(annotation);
      } else if (oldLength > 0 && newLength > 0) {
        // Replacement: delete then insert
        if (!annotation.adjustForDeletion(position, oldLength)) {
          toDelete.add(annotation.id);
        } else {
          annotation.adjustForInsertion(position, newLength);
          toUpdate.add(annotation);
        }
      }
    }

    if (toDelete.isNotEmpty) {
      annotationBox.removeMany(toDelete);
    }
    if (toUpdate.isNotEmpty) {
      annotationBox.putMany(toUpdate);
    }
  }

  /// Delete an annotation
  Future<void> deleteAnnotation(int annotationId) async {
    annotationBox.remove(annotationId);
  }

  /// Clear all annotations for a memo
  Future<void> clearAnnotations(int memoId) async {
    final query = annotationBox
        .query(MemoAnnotation_.memo.equals(memoId))
        .build();
    final annotations = query.find();
    query.close();
    annotationBox.removeMany(annotations.map((a) => a.id).toList());
  }
}
