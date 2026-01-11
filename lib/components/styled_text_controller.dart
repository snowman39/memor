import 'package:flutter/material.dart';
import 'package:memor/models/memo_annotation.dart';

/// A TextEditingController that renders text with styles based on annotations
class StyledTextController extends TextEditingController {
  List<MemoAnnotation> _annotations = [];
  final TextStyle? baseStyle;

  StyledTextController({
    String? text,
    this.baseStyle,
  }) : super(text: text);

  /// Update the annotations to apply
  void setAnnotations(List<MemoAnnotation> annotations) {
    _annotations = List.from(annotations);
    // Trigger rebuild of text spans
    notifyListeners();
  }

  List<MemoAnnotation> get annotations => _annotations;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final effectiveStyle = style ?? baseStyle ?? const TextStyle();

    if (_annotations.isEmpty) {
      return TextSpan(text: text, style: effectiveStyle);
    }

    // Sort annotations by start offset
    final sortedAnnotations = List<MemoAnnotation>.from(_annotations)
      ..sort((a, b) => a.startOffset.compareTo(b.startOffset));

    final spans = <TextSpan>[];
    int currentIndex = 0;

    for (final annotation in sortedAnnotations) {
      // Skip invalid annotations
      if (annotation.startOffset >= text.length ||
          annotation.endOffset <= 0 ||
          annotation.startOffset >= annotation.endOffset) {
        continue;
      }

      // Clamp to valid range
      final start = annotation.startOffset.clamp(0, text.length);
      final end = annotation.endOffset.clamp(0, text.length);

      // Add unstyled text before this annotation
      if (start > currentIndex) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, start),
          style: effectiveStyle,
        ));
      }

      // Add styled text for this annotation
      if (end > start) {
        spans.add(TextSpan(
          text: text.substring(start, end),
          style: _applyAnnotationStyle(effectiveStyle, annotation),
        ));
      }

      currentIndex = end;
    }

    // Add remaining unstyled text
    if (currentIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentIndex),
        style: effectiveStyle,
      ));
    }

    // Handle overlapping annotations by merging spans
    return TextSpan(children: _mergeOverlappingSpans(spans, effectiveStyle));
  }

  /// Apply annotation style to base style
  TextStyle _applyAnnotationStyle(TextStyle base, MemoAnnotation annotation) {
    switch (annotation.type) {
      case AnnotationType.bold:
        return base.copyWith(fontWeight: FontWeight.bold);
      case AnnotationType.italic:
        return base.copyWith(fontStyle: FontStyle.italic);
      case AnnotationType.strikethrough:
        return base.copyWith(decoration: TextDecoration.lineThrough);
      case AnnotationType.underline:
        return base.copyWith(decoration: TextDecoration.underline);
      case AnnotationType.link:
        return base.copyWith(
          color: Colors.blue,
          decoration: TextDecoration.underline,
        );
      default:
        return base;
    }
  }

  /// Merge overlapping spans to handle multiple annotations on same text
  List<TextSpan> _mergeOverlappingSpans(
    List<TextSpan> spans,
    TextStyle baseStyle,
  ) {
    if (spans.isEmpty || _annotations.length <= 1) {
      return spans;
    }

    // Build a map of character index -> list of annotation types
    final charStyles = <int, Set<String>>{};
    for (final annotation in _annotations) {
      final start = annotation.startOffset.clamp(0, text.length);
      final end = annotation.endOffset.clamp(0, text.length);
      for (int i = start; i < end; i++) {
        charStyles.putIfAbsent(i, () => {});
        charStyles[i]!.add(annotation.type);
      }
    }

    // Build spans with merged styles
    final mergedSpans = <TextSpan>[];
    int currentIndex = 0;
    Set<String>? currentStyles;

    for (int i = 0; i < text.length; i++) {
      final styles = charStyles[i] ?? {};

      if (currentStyles == null) {
        currentStyles = styles;
        currentIndex = i;
      } else if (!_setsEqual(styles, currentStyles)) {
        // Style changed, emit previous span
        mergedSpans.add(TextSpan(
          text: text.substring(currentIndex, i),
          style: _applyMultipleStyles(baseStyle, currentStyles),
        ));
        currentStyles = styles;
        currentIndex = i;
      }
    }

    // Emit final span
    if (currentIndex < text.length) {
      mergedSpans.add(TextSpan(
        text: text.substring(currentIndex),
        style: _applyMultipleStyles(baseStyle, currentStyles ?? {}),
      ));
    }

    return mergedSpans;
  }

  /// Apply multiple annotation types to a style
  TextStyle _applyMultipleStyles(TextStyle base, Set<String> types) {
    var result = base;
    for (final type in types) {
      switch (type) {
        case AnnotationType.bold:
          result = result.copyWith(fontWeight: FontWeight.bold);
          break;
        case AnnotationType.italic:
          result = result.copyWith(fontStyle: FontStyle.italic);
          break;
        case AnnotationType.strikethrough:
          result = result.copyWith(
            decoration: _combineDecorations(
              result.decoration,
              TextDecoration.lineThrough,
            ),
          );
          break;
        case AnnotationType.underline:
          result = result.copyWith(
            decoration: _combineDecorations(
              result.decoration,
              TextDecoration.underline,
            ),
          );
          break;
        case AnnotationType.link:
          result = result.copyWith(
            color: Colors.blue,
            decoration: _combineDecorations(
              result.decoration,
              TextDecoration.underline,
            ),
          );
          break;
      }
    }
    return result;
  }

  /// Combine text decorations
  TextDecoration _combineDecorations(
    TextDecoration? existing,
    TextDecoration toAdd,
  ) {
    if (existing == null || existing == TextDecoration.none) {
      return toAdd;
    }
    return TextDecoration.combine([existing, toAdd]);
  }

  /// Check if two sets are equal
  bool _setsEqual(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    for (final item in a) {
      if (!b.contains(item)) return false;
    }
    return true;
  }
}
