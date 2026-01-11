import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:memor/services/completion_service.dart';

enum AutocompleteStatus {
  idle, // 대기 중
  disabled, // 비활성화됨 (API 설정 안됨)
  waiting, // debounce 대기 중
  loading, // API 요청 중
  ready, // 제안 준비됨
  error, // 오류 발생
}

class AutocompleteTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ScrollController? scrollController;
  final CompletionService? completionService;
  final ValueChanged<String>? onChanged;
  final TextStyle? style;
  final InputDecoration? decoration;
  final bool autofocus;
  final int? maxLines;
  final Duration debounceDuration;
  final bool showStatusIndicator;

  const AutocompleteTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.scrollController,
    this.completionService,
    this.onChanged,
    this.style,
    this.decoration,
    this.autofocus = false,
    this.maxLines,
    this.debounceDuration = const Duration(milliseconds: 1200),
    this.showStatusIndicator = true,
  });

  @override
  State<AutocompleteTextField> createState() => _AutocompleteTextFieldState();
}

class _AutocompleteTextFieldState extends State<AutocompleteTextField> {
  String? _suggestion;
  Timer? _debounceTimer;
  AutocompleteStatus _status = AutocompleteStatus.idle;
  String? _errorMessage;
  FocusNode? _internalFocusNode;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _updateStatus();
  }

  @override
  void didUpdateWidget(AutocompleteTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.completionService != widget.completionService) {
      _updateStatus();
    }
  }

  void _updateStatus() {
    if (widget.completionService == null) {
      setState(() {
        _status = AutocompleteStatus.disabled;
      });
    } else if (!widget.completionService!.settings.isConfigured) {
      setState(() {
        _status = AutocompleteStatus.disabled;
      });
    } else if (!widget.completionService!.settings.enabled) {
      setState(() {
        _status = AutocompleteStatus.disabled;
      });
    } else if (_status == AutocompleteStatus.disabled) {
      setState(() {
        _status = AutocompleteStatus.idle;
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _debounceTimer?.cancel();
    _internalFocusNode?.dispose(); // 내부에서 생성한 FocusNode만 dispose
    super.dispose();
  }

  void _onTextChanged() {
    // 타이핑 중에는 제안 즉시 제거 (작성 방해 안되게)
    if (_suggestion != null || _status == AutocompleteStatus.ready) {
      setState(() {
        _suggestion = null;
        _status = AutocompleteStatus.idle;
      });
    }

    // 비활성화 상태면 무시
    if (_status == AutocompleteStatus.disabled) return;

    // 이전 타이머 취소 (연속 타이핑 시 요청 안함)
    _debounceTimer?.cancel();

    // 너무 자주 상태 변경 안하도록 - 타이핑 끝나고 잠시 후에만 waiting 표시
    if (_status != AutocompleteStatus.waiting &&
        _status != AutocompleteStatus.loading) {
      // 바로 waiting으로 안 바꾸고, 짧은 딜레이 후에 바꿈
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _debounceTimer?.isActive == true) {
          setState(() {
            _status = AutocompleteStatus.waiting;
            _errorMessage = null;
          });
        }
      });
    }

    // Debounce 타이머 설정 (타이핑 멈춘 후 1.2초 뒤에 요청)
    _debounceTimer = Timer(widget.debounceDuration, _requestCompletion);
  }

  Future<void> _requestCompletion() async {
    debugPrint('📝 [Editor] _requestCompletion called');

    if (widget.completionService == null) {
      debugPrint('📝 [Editor] ❌ completionService is null');
      return;
    }
    if (!widget.completionService!.settings.isConfigured) {
      debugPrint('📝 [Editor] ❌ settings not configured (no API token)');
      return;
    }
    if (!widget.completionService!.settings.enabled) {
      debugPrint('📝 [Editor] ❌ autocomplete is disabled');
      return;
    }
    if (!_focusNode.hasFocus) {
      debugPrint('📝 [Editor] ❌ text field not focused');
      setState(() {
        _status = AutocompleteStatus.idle;
      });
      return;
    }

    final text = widget.controller.text;
    final cursorPosition = widget.controller.selection.baseOffset;

    // 커서 위치가 유효하지 않으면 무시
    if (cursorPosition < 0 || cursorPosition > text.length) {
      debugPrint('📝 [Editor] ❌ invalid cursor position: $cursorPosition');
      return;
    }

    // 커서 앞/뒤 텍스트 분리
    final textBefore = text.substring(0, cursorPosition);
    final textAfter = text.substring(cursorPosition);

    debugPrint(
        '📝 [Editor] text length: ${text.length}, cursor: $cursorPosition');
    debugPrint(
        '📝 [Editor] before: ${textBefore.length} chars, after: ${textAfter.length} chars');

    // 커서 앞 텍스트가 너무 짧으면 제안하지 않음
    if (textBefore.trim().length < 3) {
      debugPrint(
          '📝 [Editor] ❌ text before cursor too short (${textBefore.trim().length} < 3)');
      setState(() {
        _status = AutocompleteStatus.idle;
      });
      return;
    }

    debugPrint('📝 [Editor] ✅ All checks passed, loading...');
    setState(() {
      _status = AutocompleteStatus.loading;
    });

    // 현재 커서 위치 저장 (나중에 비교용)
    final savedCursorPosition = cursorPosition;
    final savedText = text;

    try {
      debugPrint('📝 [Editor] Requesting completion...');
      final suggestion = await widget.completionService!.getCompletion(
        textBefore,
        textAfter: textAfter,
      );

      // 텍스트나 커서 위치가 변경되었으면 제안 무시
      if (widget.controller.text != savedText ||
          widget.controller.selection.baseOffset != savedCursorPosition) {
        debugPrint('📝 [Editor] Text or cursor changed, ignoring suggestion');
        return;
      }

      debugPrint('📝 [Editor] Suggestion received: "$suggestion"');

      if (mounted) {
        setState(() {
          _suggestion = suggestion;
          _status = suggestion != null
              ? AutocompleteStatus.ready
              : AutocompleteStatus.idle;
        });
        debugPrint(
            '📝 [Editor] Status updated to: $_status, suggestion set: ${_suggestion != null}');
      }
    } catch (e) {
      debugPrint('📝 [Editor] Error: $e');
      if (mounted) {
        setState(() {
          _status = AutocompleteStatus.error;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _acceptSuggestion() {
    if (_suggestion == null) return;

    final text = widget.controller.text;
    final cursorPosition = widget.controller.selection.baseOffset;

    // 커서 위치에 제안 텍스트 삽입
    final textBefore = text.substring(0, cursorPosition);
    final textAfter = text.substring(cursorPosition);
    final newText = textBefore + _suggestion! + textAfter;
    final newCursorPosition = cursorPosition + _suggestion!.length;

    widget.controller.text = newText;
    widget.controller.selection =
        TextSelection.collapsed(offset: newCursorPosition);

    widget.onChanged?.call(newText);

    setState(() {
      _suggestion = null;
      _status = AutocompleteStatus.idle;
    });
  }

  void _dismissSuggestion() {
    if (_suggestion != null) {
      setState(() {
        _suggestion = null;
        _status = AutocompleteStatus.idle;
      });
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      // Tab 키로 제안 수락
      if (event.logicalKey == LogicalKeyboardKey.tab && _suggestion != null) {
        _acceptSuggestion();
        return KeyEventResult.handled;
      }

      // Escape 키로 제안 취소
      if (event.logicalKey == LogicalKeyboardKey.escape &&
          _suggestion != null) {
        _dismissSuggestion();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = widget.style ??
        TextStyle(
          color: Theme.of(context).colorScheme.inversePrimary,
          fontSize: 14,
        );

    final ghostTextStyle = textStyle.copyWith(
      color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.5),
      fontStyle: FontStyle.italic,
      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
    );

    final textFieldWidget = Focus(
      onKeyEvent: _handleKeyEvent,
      child: Stack(
        children: [
          // Ghost text 레이어 (제안 표시)
          if (_suggestion != null)
            Positioned.fill(
              child: IgnorePointer(
                child: _buildGhostTextOverlay(textStyle, ghostTextStyle),
              ),
            ),

          // 실제 TextField
          TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            scrollController: widget.scrollController,
            style: textStyle,
            strutStyle: StrutStyle(
              fontSize: textStyle.fontSize ?? 14,
              height: textStyle.height ?? 1.5,
              forceStrutHeight: true, // 모든 문자에 동일한 높이 강제
            ),
            selectionHeightStyle:
                ui.BoxHeightStyle.strut, // strut 기준으로 selection 높이
            decoration: widget.decoration ??
                const InputDecoration(border: InputBorder.none),
            autofocus: widget.autofocus,
            maxLines: widget.maxLines,
            onChanged: widget.onChanged,
          ),

          // 로딩 인디케이터 (개선됨)
          if (_status == AutocompleteStatus.loading)
            Positioned(
              right: 8,
              top: 8,
              child: _buildLoadingIndicator(context),
            ),
        ],
      ),
    );

    // If no status indicator, just return the text field (works in ListView)
    if (!widget.showStatusIndicator) {
      return textFieldWidget;
    }

    // With status indicator, use Column+Expanded (requires parent with bounded height)
    return Column(
      children: [
        Expanded(child: textFieldWidget),
        _buildStatusIndicator(context),
      ],
    );
  }

  Widget _buildLoadingIndicator(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'AI',
            style: TextStyle(
              fontSize: 10,
              color:
                  Theme.of(context).colorScheme.inversePrimary.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    IconData icon;
    Color color;
    String text;

    switch (_status) {
      case AutocompleteStatus.idle:
        icon = Icons.auto_awesome_outlined;
        color = colorScheme.inversePrimary.withOpacity(0.4);
        text = 'AI Ready';
        break;
      case AutocompleteStatus.disabled:
        icon = Icons.block;
        color = colorScheme.inversePrimary.withOpacity(0.3);
        text = 'AI Off';
        break;
      case AutocompleteStatus.waiting:
        icon = Icons.more_horiz;
        color = colorScheme.inversePrimary.withOpacity(0.5);
        text = 'Waiting...';
        break;
      case AutocompleteStatus.loading:
        icon = Icons.sync;
        color = colorScheme.primary;
        text = 'Thinking...';
        break;
      case AutocompleteStatus.ready:
        icon = Icons.lightbulb;
        color = Colors.amber;
        text =
            'Tab to accept: "${_suggestion != null && _suggestion!.length > 30 ? '${_suggestion!.substring(0, 30)}...' : _suggestion ?? ''}"';
        break;
      case AutocompleteStatus.error:
        icon = Icons.error_outline;
        color = Colors.red;
        text = 'Error';
        break;
    }

    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colorScheme.inversePrimary.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          if (_status == AutocompleteStatus.loading)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            )
          else
            Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: color,
            ),
          ),
          if (_status == AutocompleteStatus.ready) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: colorScheme.inversePrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                'Tab',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.inversePrimary.withOpacity(0.6),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: colorScheme.inversePrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                'Esc',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.inversePrimary.withOpacity(0.6),
                ),
              ),
            ),
          ],
          if (_status == AutocompleteStatus.error && _errorMessage != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.red.withOpacity(0.7),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGhostTextOverlay(TextStyle textStyle, TextStyle ghostTextStyle) {
    final text = widget.controller.text;

    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _GhostTextPainter(
            text: text,
            suggestion: _suggestion ?? '',
            textStyle: textStyle,
            ghostTextStyle: ghostTextStyle,
            textDirection: Directionality.of(context),
            padding: widget.decoration?.contentPadding ?? EdgeInsets.zero,
          ),
        );
      },
    );
  }
}

class _GhostTextPainter extends CustomPainter {
  final String text;
  final String suggestion;
  final TextStyle textStyle;
  final TextStyle ghostTextStyle;
  final TextDirection textDirection;
  final EdgeInsetsGeometry padding;

  _GhostTextPainter({
    required this.text,
    required this.suggestion,
    required this.textStyle,
    required this.ghostTextStyle,
    required this.textDirection,
    required this.padding,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (suggestion.isEmpty) return;

    final resolvedPadding = padding.resolve(textDirection);

    // 실제 텍스트의 위치 계산
    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: textDirection,
      maxLines: null,
    );
    textPainter.layout(maxWidth: size.width - resolvedPadding.horizontal);

    // 텍스트 끝 위치 계산
    final lastPosition = textPainter.getOffsetForCaret(
      TextPosition(offset: text.length),
      Rect.zero,
    );

    // Ghost text 그리기
    final ghostSpan = TextSpan(text: suggestion, style: ghostTextStyle);
    final ghostPainter = TextPainter(
      text: ghostSpan,
      textDirection: textDirection,
      maxLines: null,
    );

    // 남은 공간에 맞게 레이아웃
    final remainingWidth =
        size.width - lastPosition.dx - resolvedPadding.horizontal;
    ghostPainter.layout(
        maxWidth: remainingWidth > 50 ? remainingWidth : size.width);

    // Ghost text 위치 결정
    double offsetX = lastPosition.dx + resolvedPadding.left;
    double offsetY = lastPosition.dy + resolvedPadding.top;

    // 만약 같은 줄에 공간이 부족하면 다음 줄로
    if (remainingWidth < 50) {
      offsetX = resolvedPadding.left;
      offsetY = lastPosition.dy +
          textPainter.preferredLineHeight +
          resolvedPadding.top;
    }

    ghostPainter.paint(canvas, Offset(offsetX, offsetY));
  }

  @override
  bool shouldRepaint(covariant _GhostTextPainter oldDelegate) {
    return text != oldDelegate.text ||
        suggestion != oldDelegate.suggestion ||
        textStyle != oldDelegate.textStyle ||
        ghostTextStyle != oldDelegate.ghostTextStyle;
  }
}
