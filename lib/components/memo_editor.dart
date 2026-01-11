import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:memor/components/autocomplete_text_field.dart';
import 'package:memor/components/styled_text_controller.dart';
import 'package:memor/models/memo.dart';
import 'package:memor/models/memo_annotation.dart';
import 'package:memor/services/completion_service.dart';
import 'package:memor/theme/theme.dart';
import 'package:intl/intl.dart';

/// A rich text editor that supports memo sections separated by dividers.
/// When user types '---' followed by Enter, a new memo section is created.
class MemoEditor extends StatefulWidget {
  final List<Memo> memos;
  final Map<int, List<MemoAnnotation>> annotations; // memoId -> annotations
  final CompletionService? completionService;
  final Function(int memoId, String content) onMemoChanged;
  final Function(int memoId, String firstPart, String secondPart) onSplitMemo;
  final Function(int firstMemoId, int secondMemoId) onMergeMemos;
  final Function(int memoId, int start, int end, String type)? onToggleStyle;
  final TextStyle? style;

  const MemoEditor({
    super.key,
    required this.memos,
    this.annotations = const {},
    required this.onMemoChanged,
    required this.onSplitMemo,
    required this.onMergeMemos,
    this.onToggleStyle,
    this.completionService,
    this.style,
  });

  @override
  State<MemoEditor> createState() => _MemoEditorState();
}

class _MemoEditorState extends State<MemoEditor> {
  final Map<int, StyledTextController> _controllers =
      <int, StyledTextController>{};
  final Map<int, FocusNode> _focusNodes = <int, FocusNode>{};
  final Map<int, ScrollController> _scrollControllers =
      <int, ScrollController>{};
  final ScrollController _mainScrollController = ScrollController();
  Timer? _debounceTimer;

  // Track which memo is currently focused and its selection
  int? _focusedMemoId;
  TextSelection? _currentSelection;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    // Auto-focus the first memo after build (without scroll animation)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Jump to top instantly before focusing to prevent scroll animation
      if (_mainScrollController.hasClients) {
        _mainScrollController.jumpTo(0);
      }
      _focusFirstMemo();
    });
  }

  @override
  void didUpdateWidget(MemoEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reinitialize if memos changed
    if (oldWidget.memos.length != widget.memos.length) {
      _initializeControllers();
      // Auto-focus the first memo after rebuild
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusFirstMemo();
      });
    }

    // Update annotations if changed
    _updateAnnotations();
  }

  void _focusFirstMemo() {
    if (widget.memos.isNotEmpty) {
      final firstMemoId = widget.memos.first.id;
      _focusNodes[firstMemoId]?.requestFocus();
    }
  }

  void _initializeControllers() {
    // Clean up old controllers for memos that no longer exist
    final currentMemoIds = widget.memos.map((m) => m.id).toSet();
    _controllers.keys
        .where((id) => !currentMemoIds.contains(id))
        .toList()
        .forEach((id) {
      _controllers[id]?.dispose();
      _controllers.remove(id);
      _focusNodes[id]?.dispose();
      _focusNodes.remove(id);
      _scrollControllers[id]?.dispose();
      _scrollControllers.remove(id);
    });

    // Initialize controllers for new memos
    for (final memo in widget.memos) {
      if (!_controllers.containsKey(memo.id)) {
        final controller = StyledTextController(text: memo.content);
        controller.addListener(() => _onSelectionChanged(memo.id));
        _controllers[memo.id] = controller;
        _focusNodes[memo.id] = FocusNode();
        _scrollControllers[memo.id] = ScrollController();

        // Set initial annotations
        final annotations = widget.annotations[memo.id] ?? [];
        controller.setAnnotations(annotations);
      } else {
        // Update text if it changed externally
        if (_controllers[memo.id]!.text != memo.content) {
          _controllers[memo.id]!.text = memo.content;
        }
      }
    }
  }

  void _updateAnnotations() {
    for (final memo in widget.memos) {
      final controller = _controllers[memo.id];
      if (controller != null) {
        final annotations = widget.annotations[memo.id] ?? [];
        controller.setAnnotations(annotations);
      }
    }
  }

  void _onSelectionChanged(int memoId) {
    final controller = _controllers[memoId];
    if (controller == null) return;

    final selection = controller.selection;

    // Track selection for style shortcuts
    if (selection.isValid && !selection.isCollapsed) {
      _focusedMemoId = memoId;
      _currentSelection = selection;
    }
  }

  @override
  void dispose() {
    _mainScrollController.dispose();
    _debounceTimer?.cancel();
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    for (var scrollController in _scrollControllers.values) {
      scrollController.dispose();
    }
    super.dispose();
  }

  void _onMemoTextChanged(int memoId, String text) {
    // Check for divider pattern at the end: "---\n" or just "---" followed by newline
    final dividerPattern = RegExp(r'---\n');
    final match = dividerPattern.firstMatch(text);

    if (match != null) {
      // Found divider pattern - split the memo
      final beforeDivider = text.substring(0, match.start);
      final afterDivider = text.substring(match.end);

      // Call split callback
      widget.onSplitMemo(memoId, beforeDivider, afterDivider);
      return;
    }

    // Normal text change - debounce and save
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      widget.onMemoChanged(memoId, text);
    });
  }

  void _toggleStyle(String type) {
    if (_focusedMemoId == null || _currentSelection == null) return;
    if (_currentSelection!.isCollapsed) return;

    final start = _currentSelection!.start;
    final end = _currentSelection!.end;

    widget.onToggleStyle?.call(_focusedMemoId!, start, end, type);
  }

  KeyEventResult _handleKeyEvent(
      int memoIndex, FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Let Cmd+Shift combinations pass through to parent (for tab switching)
    if (HardwareKeyboard.instance.isMetaPressed &&
        HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    }

    final memo = widget.memos[memoIndex];
    final controller = _controllers[memo.id];
    if (controller == null) return KeyEventResult.ignored;

    // Handle Cmd+B for bold
    if (HardwareKeyboard.instance.isMetaPressed &&
        event.logicalKey == LogicalKeyboardKey.keyB) {
      _toggleStyle(AnnotationType.bold);
      return KeyEventResult.handled;
    }

    // Handle Cmd+I for italic
    if (HardwareKeyboard.instance.isMetaPressed &&
        event.logicalKey == LogicalKeyboardKey.keyI) {
      _toggleStyle(AnnotationType.italic);
      return KeyEventResult.handled;
    }

    // Handle Cmd+U for underline
    if (HardwareKeyboard.instance.isMetaPressed &&
        event.logicalKey == LogicalKeyboardKey.keyU) {
      _toggleStyle(AnnotationType.underline);
      return KeyEventResult.handled;
    }

    // Handle Cmd+S for strikethrough
    if (HardwareKeyboard.instance.isMetaPressed &&
        event.logicalKey == LogicalKeyboardKey.keyS) {
      _toggleStyle(AnnotationType.strikethrough);
      return KeyEventResult.handled;
    }

    // Handle Backspace at the beginning of a memo (not the first one)
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      if (memoIndex > 0 &&
          controller.selection.baseOffset == 0 &&
          controller.selection.extentOffset == 0) {
        // Merge with previous memo
        final prevMemo = widget.memos[memoIndex - 1];
        widget.onMergeMemos(prevMemo.id, memo.id);

        // Focus the previous memo at the end of its content
        Future.microtask(() {
          final prevController = _controllers[prevMemo.id];
          final prevFocusNode = _focusNodes[prevMemo.id];
          if (prevController != null && prevFocusNode != null) {
            prevFocusNode.requestFocus();
            prevController.selection = TextSelection.collapsed(
              offset: prevController.text.length,
            );
          }
        });

        return KeyEventResult.handled;
      }
    }

    // Handle Down arrow at the end of memo content - move to next memo
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (memoIndex < widget.memos.length - 1 &&
          controller.selection.baseOffset == controller.text.length) {
        final nextMemo = widget.memos[memoIndex + 1];
        final nextFocusNode = _focusNodes[nextMemo.id];
        final nextController = _controllers[nextMemo.id];
        if (nextFocusNode != null && nextController != null) {
          nextFocusNode.requestFocus();
          nextController.selection = const TextSelection.collapsed(offset: 0);
          return KeyEventResult.handled;
        }
      }
    }

    // Handle Up arrow at the beginning of memo content - move to previous memo
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (memoIndex > 0 && controller.selection.baseOffset == 0) {
        final prevMemo = widget.memos[memoIndex - 1];
        final prevFocusNode = _focusNodes[prevMemo.id];
        final prevController = _controllers[prevMemo.id];
        if (prevFocusNode != null && prevController != null) {
          prevFocusNode.requestFocus();
          prevController.selection = TextSelection.collapsed(
            offset: prevController.text.length,
          );
          return KeyEventResult.handled;
        }
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.memos.isEmpty) {
      return const Center(child: Text('No content'));
    }

    // Ensure controllers are initialized
    _initializeControllers();

    final textStyle = widget.style ??
        TextStyle(
          color: Theme.of(context).colorScheme.inversePrimary,
          fontSize: 14,
          height: 1.5,
        );

    final itemCount = widget.memos.length * 2 - 1;

    return ListView.builder(
      controller: _mainScrollController,
      physics:
          const NativeScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      cacheExtent:
          2000, // Keep more items in memory to prevent scrollbar jitter
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: itemCount, // memos + dividers between them
      itemBuilder: (context, index) {
        // Odd indices are dividers
        if (index.isOdd) {
          return _buildDivider(context, index ~/ 2);
        }

        // Even indices are memo sections
        final memoIndex = index ~/ 2;
        final memo = widget.memos[memoIndex];
        return _buildMemoSection(context, memo, memoIndex, textStyle);
      },
    );
  }

  Widget _buildDivider(BuildContext context, int afterMemoIndex) {
    final colorScheme = Theme.of(context).colorScheme;
    final nextMemo = widget.memos[afterMemoIndex + 1];
    final dateFormat = DateFormat('yyyy.MM.dd HH:mm');
    final lineColor = colorScheme.inversePrimary.withOpacity(0.2);

    // Fade-in animation for new dividers
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, opacity, child) {
        return Opacity(
          opacity: opacity,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 1,
                    color: lineColor,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    dateFormat.format(nextMemo.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.inversePrimary.withOpacity(0.4),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 1,
                    color: lineColor,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMemoSection(
    BuildContext context,
    Memo memo,
    int memoIndex,
    TextStyle textStyle,
  ) {
    if (!_controllers.containsKey(memo.id)) {
      return const Text('Error: No controller');
    }

    final controller = _controllers[memo.id]!;
    final focusNode = _focusNodes[memo.id]!;
    final scrollController = _scrollControllers[memo.id]!;

    return Focus(
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          _focusedMemoId = memo.id;
        }
      },
      onKeyEvent: (node, event) => _handleKeyEvent(memoIndex, node, event),
      child: AutocompleteTextField(
        controller: controller,
        focusNode: focusNode,
        scrollController: scrollController,
        completionService: widget.completionService,
        style: textStyle,
        maxLines: null,
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          hintText: 'New memo...',
          hintStyle: textStyle.copyWith(
            color: textStyle.color?.withOpacity(0.3),
          ),
        ),
        showStatusIndicator: false, // Don't show in ListView items
        onChanged: (text) => _onMemoTextChanged(memo.id, text),
      ),
    );
  }
}
