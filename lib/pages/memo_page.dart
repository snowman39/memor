import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:memor/components/drawer.dart';
import 'package:memor/components/memo_editor.dart';
import 'package:memor/models/memo.dart';
import 'package:memor/models/memo_annotation.dart';
import 'package:memor/models/memo_space.dart';
import 'package:memor/models/memo_space_database.dart';
import 'package:memor/services/completion_service.dart';
import 'package:provider/provider.dart';

class MemoPage extends StatefulWidget {
  const MemoPage({super.key});

  @override
  State<MemoPage> createState() => _MemoPageState();
}

class _MemoPageState extends State<MemoPage> {
  List<MemoSpace> openedMemoSpaces = [];
  List<bool> hovered = [];

  MemoSpace? focusedMemoSpace;

  // Memos for the currently focused MemoSpace
  List<Memo> _currentMemos = [];
  Map<int, List<MemoAnnotation>> _annotations = {}; // memoId -> annotations
  bool _memosLoading = false;

  int? editingTabId;
  final ScrollController _tabScrollController = ScrollController();

  // 더블탭 감지를 위한 변수
  int? _lastTappedTabId;
  DateTime? _lastTapTime;

  // Autocomplete service
  CompletionService? _completionService;

  // 검색 기능
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<SearchMatch> _searchMatches = [];
  int _currentMatchIndex = -1;

  @override
  void initState() {
    super.initState();
    // Delay readMemoSpaces to avoid calling notifyListeners during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      readMemoSpaces();
    });
    _initCompletionService();
  }

  Future<void> _initCompletionService() async {
    final settings = await CompletionSettings.load();
    if (mounted) {
      setState(() {
        _completionService = CompletionService(settings);
      });
    }
  }

  /// Settings 페이지에서 돌아온 후 호출하여 completion service를 다시 로드
  void reloadCompletionService() {
    _initCompletionService();
  }

  // Load memos for the currently focused MemoSpace
  Future<void> _loadMemosForFocusedSpace() async {
    if (focusedMemoSpace == null) {
      setState(() {
        _currentMemos = [];
        _annotations = {};
      });
      return;
    }

    setState(() {
      _memosLoading = true;
    });

    final db = context.read<MemoSpaceDatabase>();
    final memos = await db.getMemosBySpace(focusedMemoSpace!.id);

    // Load annotations for each memo
    final annotations = <int, List<MemoAnnotation>>{};
    for (final memo in memos) {
      final memoAnnotations = await db.getAnnotationsByMemo(memo.id);
      annotations[memo.id] = memoAnnotations;
    }

    if (mounted) {
      setState(() {
        _currentMemos = memos;
        _annotations = annotations;
        _memosLoading = false;
      });
    }
  }

  // 검색 기능 메서드들
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (_isSearching) {
        _searchFocusNode.requestFocus();
      } else {
        _searchController.clear();
        _searchMatches.clear();
        _currentMatchIndex = -1;
      }
    });
  }

  void _performSearch(String query) {
    if (_currentMemos.isEmpty || query.isEmpty) {
      setState(() {
        _searchMatches.clear();
        _currentMatchIndex = -1;
      });
      return;
    }

    final searchQuery = query.toLowerCase();
    final matches = <SearchMatch>[];

    for (int memoIdx = 0; memoIdx < _currentMemos.length; memoIdx++) {
      final memo = _currentMemos[memoIdx];
      final text = memo.content.toLowerCase();

      int index = 0;
      while (true) {
        index = text.indexOf(searchQuery, index);
        if (index == -1) break;
        matches.add(SearchMatch(memoIndex: memoIdx, position: index));
        index += 1;
      }
    }

    setState(() {
      _searchMatches = matches;
      _currentMatchIndex = matches.isNotEmpty ? 0 : -1;
    });
  }

  void _nextMatch() {
    if (_searchMatches.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _searchMatches.length;
    });
    // TODO: Implement highlight in MemoEditor
  }

  void _previousMatch() {
    if (_searchMatches.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex - 1 + _searchMatches.length) %
          _searchMatches.length;
    });
    // TODO: Implement highlight in MemoEditor
  }

  @override
  void dispose() {
    _tabScrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void setFocusedMemoSpace(MemoSpace memoSpace) {
    if (!memoSpace.opened) {
      memoSpace.opened = true;
      updateOpenedState(memoSpace);
    }
    setState(() {
      focusedMemoSpace = memoSpace;
    });
    _loadMemosForFocusedSpace();
  }

  void dragMemoSpace(int from, int to) {
    final MemoSpace item = openedMemoSpaces.removeAt(from);
    openedMemoSpaces.insert(to, item);
    setFocusedMemoSpace(openedMemoSpaces[to]);
  }

  void openMemoSpace(MemoSpace memoSpace) {
    // 이미 열려있는 탭이면 해당 인스턴스로 포커스 이동
    final existingTab =
        openedMemoSpaces.where((m) => m.id == memoSpace.id).firstOrNull;
    if (existingTab != null) {
      setFocusedMemoSpace(existingTab);
      return;
    }
    openedMemoSpaces.add(memoSpace);
    hovered.add(false);
    memoSpace.opened = true;
    updateOpenedState(memoSpace);
    setFocusedMemoSpace(memoSpace);
  }

  void closeMemoSpace(MemoSpace memoSpace) {
    int index = openedMemoSpaces.indexOf(memoSpace);
    if (focusedMemoSpace != null && memoSpace.id == focusedMemoSpace!.id) {
      if (index == 0 && openedMemoSpaces.length > 1) {
        setFocusedMemoSpace(openedMemoSpaces[1]);
      } else if (index > 0) {
        setFocusedMemoSpace(openedMemoSpaces[index - 1]);
      } else {
        focusedMemoSpace = null;
        _currentMemos = [];
      }
    }
    memoSpace.opened = false;
    updateOpenedState(memoSpace);
    openedMemoSpaces.remove(memoSpace);
    hovered.removeAt(index);
  }

  void createMemoSpace() async {
    final newMemoSpace =
        await context.read<MemoSpaceDatabase>().createMemoSpace();
    openMemoSpace(newMemoSpace);
  }

  void readMemoSpaces() {
    context.read<MemoSpaceDatabase>().readMemoSpaces();
  }

  void updateMemoSpaceName(MemoSpace memoSpace) {
    context.read<MemoSpaceDatabase>().updateMemoSpaceName(
          memoSpace.id,
          memoSpace.name,
        );
  }

  void updateOpenedState(MemoSpace memoSpace) {
    context.read<MemoSpaceDatabase>().updateOpenedState(
          memoSpace.id,
          memoSpace.opened,
        );
  }

  void deleteMemoSpace(MemoSpace memoSpace) {
    // 열려있는 탭이면 닫기
    final openedTab =
        openedMemoSpaces.where((m) => m.id == memoSpace.id).firstOrNull;
    if (openedTab != null) {
      int index = openedMemoSpaces.indexOf(openedTab);
      if (focusedMemoSpace != null && openedTab.id == focusedMemoSpace!.id) {
        if (index == 0 && openedMemoSpaces.length > 1) {
          setFocusedMemoSpace(openedMemoSpaces[1]);
        } else if (index > 0) {
          setFocusedMemoSpace(openedMemoSpaces[index - 1]);
        } else {
          focusedMemoSpace = null;
          _currentMemos = [];
        }
      }
      openedMemoSpaces.remove(openedTab);
      if (index >= 0 && index < hovered.length) {
        hovered.removeAt(index);
      }
    }
    context.read<MemoSpaceDatabase>().deleteMemoSpace(memoSpace.id);
  }

  // Memo operations
  Future<void> _onMemoChanged(int memoId, String content) async {
    await context.read<MemoSpaceDatabase>().updateMemoContent(memoId, content);
    // Update local state
    final idx = _currentMemos.indexWhere((m) => m.id == memoId);
    if (idx != -1) {
      setState(() {
        _currentMemos[idx].content = content;
        _currentMemos[idx].updatedAt = DateTime.now();
      });
    }
  }

  Future<void> _onSplitMemo(
      int memoId, String firstPart, String secondPart) async {
    final db = context.read<MemoSpaceDatabase>();
    await db.splitMemo(
      memoId: memoId,
      firstPart: firstPart,
      secondPart: secondPart,
    );

    // Reload memos without showing loading indicator (prevents flicker)
    if (focusedMemoSpace != null) {
      final memos = await db.getMemosBySpace(focusedMemoSpace!.id);
      if (mounted) {
        setState(() {
          _currentMemos = memos;
        });
      }
    }
  }

  Future<void> _onMergeMemos(int firstMemoId, int secondMemoId) async {
    final db = context.read<MemoSpaceDatabase>();
    await db.mergeMemos(
      firstMemoId: firstMemoId,
      secondMemoId: secondMemoId,
    );

    // Reload memos without showing loading indicator (prevents flicker)
    if (focusedMemoSpace != null) {
      final memos = await db.getMemosBySpace(focusedMemoSpace!.id);
      if (mounted) {
        setState(() {
          _currentMemos = memos;
        });
      }
    }
  }

  // Toggle annotation style (bold, italic, etc.)
  Future<void> _onToggleStyle(
      int memoId, int start, int end, String type) async {
    final db = context.read<MemoSpaceDatabase>();
    await db.toggleAnnotation(
      memoId: memoId,
      startOffset: start,
      endOffset: end,
      type: type,
    );

    // Reload annotations for this memo
    final updatedAnnotations = await db.getAnnotationsByMemo(memoId);
    if (mounted) {
      setState(() {
        _annotations[memoId] = updatedAnnotations;
      });
    }
  }

  Widget openedMemoSpaceTabs(
      List<MemoSpace> openedMemoSpaces, MemoSpace? focusedMemoSpace) {
    if (openedMemoSpaces.isEmpty) {
      final borderColor =
          Theme.of(context).colorScheme.inversePrimary.withOpacity(0.08);
      final inactiveColor = Color.lerp(
        Theme.of(context).colorScheme.surface,
        Theme.of(context).colorScheme.primary,
        0.4,
      )!;
      return SizedBox(
        height: 32,
        child: _buildAddButtonArea(borderColor, inactiveColor),
      );
    }

    // 노션 스타일: 선택된 탭은 에디터와 같은 색, 선택 안된 탭은 살짝 다른 색
    final surfaceColor = Theme.of(context).colorScheme.surface;
    // 더 옅은 비활성 탭 색상 (surface와 primary 중간, surface에 가깝게)
    final inactiveTabColor = Color.lerp(
      Theme.of(context).colorScheme.surface,
      Theme.of(context).colorScheme.primary,
      0.4,
    )!;
    // hover 시 약간 더 진한 색상
    final hoveredTabColor = Color.lerp(
      Theme.of(context).colorScheme.surface,
      Theme.of(context).colorScheme.primary,
      0.65,
    )!;
    final borderColor =
        Theme.of(context).colorScheme.inversePrimary.withOpacity(0.08);

    // 탭 decoration을 함수로 생성
    BoxDecoration getTabDecoration({
      required bool isFirst,
      required bool isFocused,
      required bool isHovered,
    }) {
      Color bgColor;
      if (isFocused) {
        bgColor = surfaceColor;
      } else if (isHovered) {
        bgColor = hoveredTabColor;
      } else {
        bgColor = inactiveTabColor;
      }

      if (isFirst) {
        return BoxDecoration(
          color: bgColor,
          border: isFocused
              ? null
              : Border(
                  bottom: BorderSide(color: borderColor, width: 1),
                ),
        );
      } else {
        return BoxDecoration(
          color: bgColor,
          border: Border(
            left: BorderSide(color: borderColor, width: 1),
            bottom: isFocused
                ? BorderSide.none
                : BorderSide(color: borderColor, width: 1),
          ),
        );
      }
    }

    BoxDecoration draggedTab = BoxDecoration(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(4),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );

    const double minTabWidth = 120; // 탭 최소 너비
    const double maxTabWidth = 200; // 탭 최대 너비
    const double addButtonWidth = 40; // + 버튼 영역 최소 너비

    return SizedBox(
      height: 32,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, outerConstraints) {
          final totalWidth = outerConstraints.maxWidth;
          final availableForTabs = totalWidth - addButtonWidth;
          final tabCount = openedMemoSpaces.length;

          // 탭 너비 계산: 200px에서 시작해서 100px까지 줄어들 수 있음
          double tabWidth =
              (availableForTabs / tabCount).clamp(minTabWidth, maxTabWidth);

          // 스크롤 필요 여부: 모든 탭이 minTabWidth일 때도 공간이 부족하면
          final needsScroll = tabCount * minTabWidth > availableForTabs;
          if (needsScroll) {
            tabWidth = minTabWidth;
          }

          // 탭 영역의 실제 너비
          final tabAreaWidth = needsScroll
              ? availableForTabs // 스크롤 시 가용 공간 전체 사용
              : tabWidth * tabCount; // 스크롤 없을 때 탭들의 총 너비

          return Row(
            children: [
              // 탭 영역
              SizedBox(
                width: tabAreaWidth,
                child: Stack(
                  children: [
                    // Top border
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: Container(
                        height: 1,
                        color: borderColor,
                      ),
                    ),
                    // Bottom border
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        height: 1,
                        color: borderColor,
                      ),
                    ),
                    // 탭 영역
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 1,
                      bottom: 0,
                      child: Scrollbar(
                        controller: _tabScrollController,
                        thumbVisibility: false,
                        thickness: 3,
                        radius: const Radius.circular(2),
                        child: ListView.builder(
                          controller: _tabScrollController,
                          scrollDirection: Axis.horizontal,
                          shrinkWrap: true,
                          physics: const BouncingScrollPhysics(),
                          itemCount: openedMemoSpaces.length,
                          itemBuilder: (context, i) {
                            bool isFocused =
                                openedMemoSpaces.indexOf(focusedMemoSpace!) ==
                                    i;
                            return Align(
                              alignment: Alignment.topLeft,
                              child: DragTarget<int>(
                                onAcceptWithDetails: (from) {
                                  dragMemoSpace(from.data, i);
                                },
                                builder: (context, candidateData, __) {
                                  final isDropTarget =
                                      candidateData.isNotEmpty &&
                                          candidateData.first != i &&
                                          candidateData.first != i - 1;
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // 드롭 위치 하이라이트 (왼쪽)
                                      AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 150),
                                        width: isDropTarget ? 3 : 0,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: isDropTarget
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                      Draggable<int>(
                                        data: i,
                                        feedback: Material(
                                          child: Container(
                                            height: 32,
                                            width: tabWidth,
                                            decoration: draggedTab,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                if (isFocused)
                                                  Expanded(
                                                    child: TextField(
                                                      controller:
                                                          TextEditingController(
                                                              text:
                                                                  openedMemoSpaces[
                                                                          i]
                                                                      .name),
                                                      decoration:
                                                          const InputDecoration(
                                                        border:
                                                            InputBorder.none,
                                                        isDense: true,
                                                        contentPadding:
                                                            EdgeInsets
                                                                .symmetric(
                                                                    vertical:
                                                                        9),
                                                      ),
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .inversePrimary,
                                                      ),
                                                    ),
                                                  )
                                                else
                                                  TextButton(
                                                    onPressed: () {
                                                      setFocusedMemoSpace(
                                                          openedMemoSpaces[i]);
                                                    },
                                                    child: Text(
                                                      openedMemoSpaces[i].name,
                                                      style: TextStyle(
                                                          color: Theme.of(
                                                                  context)
                                                              .colorScheme
                                                              .inversePrimary),
                                                    ),
                                                  ),
                                                IconButton(
                                                  icon: Icon(Icons.close,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .inversePrimary),
                                                  onPressed: () {},
                                                  iconSize: 16,
                                                  splashRadius: 20,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        childWhenDragging: Container(
                                          height: 32,
                                          width: tabWidth,
                                          decoration: BoxDecoration(
                                            color: inactiveTabColor
                                                .withOpacity(0.5),
                                            border: Border(
                                              left: i == 0
                                                  ? BorderSide.none
                                                  : BorderSide(
                                                      color: borderColor,
                                                      width: 1,
                                                    ),
                                            ),
                                          ),
                                        ),
                                        child: MouseRegion(
                                          onEnter: (event) {
                                            setState(() {
                                              hovered[i] = true;
                                            });
                                          },
                                          onExit: (event) {
                                            setState(() {
                                              hovered[i] = false;
                                            });
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 150),
                                            curve: Curves.easeOutCubic,
                                            width: tabWidth,
                                            height: 31,
                                            decoration: getTabDecoration(
                                              isFirst: i == 0,
                                              isFocused: isFocused,
                                              isHovered: hovered[i],
                                            ),
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                // 탭 제목 (편집 모드)
                                                if (editingTabId ==
                                                    openedMemoSpaces[i].id)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            left: 17,
                                                            right: 32),
                                                    child: Focus(
                                                      onFocusChange:
                                                          (hasFocus) {
                                                        if (!hasFocus) {
                                                          updateMemoSpaceName(
                                                              openedMemoSpaces[
                                                                  i]);
                                                          setState(() {
                                                            editingTabId = null;
                                                          });
                                                        }
                                                      },
                                                      child: TextField(
                                                        controller:
                                                            TextEditingController(
                                                                text:
                                                                    openedMemoSpaces[
                                                                            i]
                                                                        .name),
                                                        autofocus: true,
                                                        onChanged: (text) {
                                                          openedMemoSpaces[i]
                                                              .name = text;
                                                        },
                                                        onSubmitted: (text) {
                                                          updateMemoSpaceName(
                                                              openedMemoSpaces[
                                                                  i]);
                                                          setState(() {
                                                            editingTabId = null;
                                                          });
                                                        },
                                                        decoration:
                                                            const InputDecoration(
                                                          border:
                                                              InputBorder.none,
                                                          isDense: true,
                                                          contentPadding:
                                                              EdgeInsets
                                                                  .symmetric(
                                                                      vertical:
                                                                          9),
                                                        ),
                                                        textAlign:
                                                            TextAlign.left,
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: Theme.of(
                                                                  context)
                                                              .colorScheme
                                                              .inversePrimary,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                // 탭 제목 (일반 모드)
                                                else
                                                  Positioned.fill(
                                                    child: GestureDetector(
                                                      onTap: () {
                                                        final now =
                                                            DateTime.now();
                                                        final tabId =
                                                            openedMemoSpaces[i]
                                                                .id;

                                                        // 더블탭 감지 (300ms 이내 같은 탭 클릭)
                                                        if (_lastTappedTabId ==
                                                                tabId &&
                                                            _lastTapTime !=
                                                                null &&
                                                            now
                                                                    .difference(
                                                                        _lastTapTime!)
                                                                    .inMilliseconds <
                                                                300) {
                                                          // 더블탭 - 편집 모드
                                                          setState(() {
                                                            editingTabId =
                                                                tabId;
                                                          });
                                                          _lastTappedTabId =
                                                              null;
                                                          _lastTapTime = null;
                                                        } else {
                                                          // 싱글탭 - 포커스 이동
                                                          setFocusedMemoSpace(
                                                              openedMemoSpaces[
                                                                  i]);
                                                          _lastTappedTabId =
                                                              tabId;
                                                          _lastTapTime = now;
                                                        }
                                                      },
                                                      child: Container(
                                                        color:
                                                            Colors.transparent,
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                left: 17,
                                                                right: 32),
                                                        alignment: Alignment
                                                            .centerLeft,
                                                        child: Text(
                                                          openedMemoSpaces[i]
                                                              .name,
                                                          textAlign:
                                                              TextAlign.left,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                isFocused
                                                                    ? FontWeight
                                                                        .w700
                                                                    : FontWeight
                                                                        .normal,
                                                            color: Theme.of(
                                                                    context)
                                                                .colorScheme
                                                                .inversePrimary,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                // X 버튼 (오른쪽 고정)
                                                Positioned(
                                                  right: 0,
                                                  child: Opacity(
                                                    opacity: (isFocused ||
                                                            hovered[i])
                                                        ? 1.0
                                                        : 0.0,
                                                    child: closeMemoSpaceButton(
                                                        openedMemoSpaces[i]),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // + 버튼 영역 - 나머지 공간 차지 (노션 스타일)
              Expanded(
                child: _buildAddButtonArea(borderColor, inactiveTabColor),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAddButtonArea(Color borderColor, Color backgroundColor) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          top: BorderSide(color: borderColor, width: 1),
          bottom: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: _AddTabButton(
          onTap: createMemoSpace,
          borderColor: borderColor,
        ),
      ),
    );
  }

  Widget closeMemoSpaceButton(MemoSpace memoSpace) {
    return _HoverScaleButton(
      onTap: () => closeMemoSpace(memoSpace),
      child: const Icon(Icons.close, size: 14),
    );
  }

  Widget _buildSearchBar() {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = colorScheme.inversePrimary.withOpacity(0.08);

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          // 검색 아이콘
          Icon(
            Icons.search,
            size: 16,
            color: colorScheme.inversePrimary.withOpacity(0.5),
          ),
          const SizedBox(width: 8),
          // 검색 입력
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.inversePrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(
                  color: colorScheme.inversePrimary.withOpacity(0.4),
                  fontSize: 13,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: _performSearch,
              onSubmitted: (_) {
                if (HardwareKeyboard.instance.isShiftPressed) {
                  _previousMatch();
                } else {
                  _nextMatch();
                }
              },
            ),
          ),
          // 결과 카운트
          if (_searchMatches.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '${_currentMatchIndex + 1}/${_searchMatches.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.inversePrimary.withOpacity(0.5),
                ),
              ),
            ),
          // 이전/다음 버튼
          if (_searchMatches.isNotEmpty) ...[
            _buildSearchNavButton(Icons.keyboard_arrow_up, _previousMatch),
            _buildSearchNavButton(Icons.keyboard_arrow_down, _nextMatch),
          ],
          // 닫기 버튼
          _buildSearchNavButton(Icons.close, _toggleSearch),
        ],
      ),
    );
  }

  Widget _buildSearchNavButton(IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onTap,
          child: Center(
            child: Icon(
              icon,
              size: 16,
              color:
                  Theme.of(context).colorScheme.inversePrimary.withOpacity(0.6),
            ),
          ),
        ),
      ),
    );
  }

  Widget focusedMemoEditor(MemoSpace? focusedMemoSpace) {
    if (focusedMemoSpace == null) {
      return const Expanded(
        child: Center(
          child: Text('No memospace opened'),
        ),
      );
    }

    if (_memosLoading) {
      return const Expanded(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_currentMemos.isEmpty) {
      // Trigger load if memos are empty
      Future.microtask(_loadMemosForFocusedSpace);
      return const Expanded(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Expanded(
      flex: 10,
      child: Container(
        color: Colors.transparent,
        child: MemoEditor(
          key: ValueKey('memo_editor_${focusedMemoSpace.id}'),
          memos: _currentMemos,
          annotations: _annotations,
          completionService: _completionService,
          style: TextStyle(
            color: Theme.of(context).colorScheme.inversePrimary,
            fontSize: 14,
            height: 1.5,
            leadingDistribution: TextLeadingDistribution.even,
          ),
          onMemoChanged: _onMemoChanged,
          onSplitMemo: _onSplitMemo,
          onMergeMemos: _onMergeMemos,
          onToggleStyle: _onToggleStyle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final memoSpaceDatabase = context.watch<MemoSpaceDatabase>();
    List<MemoSpace> memoSpaces = memoSpaceDatabase.memoSpaces;
    if (openedMemoSpaces.isEmpty) {
      openedMemoSpaces = memoSpaces.where((memoSpace) {
        return memoSpace.opened;
      }).toList();
    }

    if (hovered.isEmpty) {
      for (MemoSpace _ in openedMemoSpaces) {
        hovered.add(false);
      }
    }

    if (focusedMemoSpace == null) {
      if (openedMemoSpaces.isNotEmpty) {
        focusedMemoSpace = openedMemoSpaces.first;
        // Load memos for the initial focused space
        Future.microtask(_loadMemosForFocusedSpace);
      }
    }

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        const threshold = 300.0;

        if (velocity > threshold) {
          // 오른쪽으로 스와이프 -> 왼쪽 탭으로
          if (openedMemoSpaces.isNotEmpty &&
              focusedMemoSpace != null &&
              focusedMemoSpace != openedMemoSpaces.first) {
            setFocusedMemoSpace(openedMemoSpaces[
                openedMemoSpaces.indexOf(focusedMemoSpace!) - 1]);
          }
        } else if (velocity < -threshold) {
          // 왼쪽으로 스와이프 -> 오른쪽 탭으로
          if (openedMemoSpaces.isNotEmpty &&
              focusedMemoSpace != null &&
              focusedMemoSpace != openedMemoSpaces.last) {
            setFocusedMemoSpace(openedMemoSpaces[
                openedMemoSpaces.indexOf(focusedMemoSpace!) + 1]);
          }
        }
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          try {
            if (event is KeyDownEvent) {
              // Cmd+F : 검색
              if (HardwareKeyboard.instance.isMetaPressed &&
                  event.logicalKey == LogicalKeyboardKey.keyF) {
                _toggleSearch();
                return KeyEventResult.handled;
              }
              // Escape : 검색 닫기
              if (event.logicalKey == LogicalKeyboardKey.escape &&
                  _isSearching) {
                _toggleSearch();
                return KeyEventResult.handled;
              }
              // 검색 모드에서 Enter : 다음/이전 검색 결과로 이동
              if (_isSearching &&
                  _searchMatches.isNotEmpty &&
                  event.logicalKey == LogicalKeyboardKey.enter) {
                if (HardwareKeyboard.instance.isShiftPressed) {
                  _previousMatch();
                } else {
                  _nextMatch();
                }
                return KeyEventResult.handled;
              }
              // Cmd+Shift 조합
              if (HardwareKeyboard.instance.isMetaPressed &&
                  HardwareKeyboard.instance.isShiftPressed) {
                if (event.logicalKey == LogicalKeyboardKey.braceLeft) {
                  // Cmd+Shift+[ : 왼쪽 탭으로 이동
                  if (openedMemoSpaces.isNotEmpty &&
                      focusedMemoSpace != null &&
                      focusedMemoSpace != openedMemoSpaces.first) {
                    setFocusedMemoSpace(openedMemoSpaces[
                        openedMemoSpaces.indexOf(focusedMemoSpace!) - 1]);
                  }
                  return KeyEventResult.handled;
                } else if (event.logicalKey == LogicalKeyboardKey.braceRight) {
                  // Cmd+Shift+] : 오른쪽 탭으로 이동
                  if (openedMemoSpaces.isNotEmpty &&
                      focusedMemoSpace != null &&
                      focusedMemoSpace != openedMemoSpaces.last) {
                    setFocusedMemoSpace(openedMemoSpaces[
                        openedMemoSpaces.indexOf(focusedMemoSpace!) + 1]);
                  }
                  return KeyEventResult.handled;
                }
              }
            }
          } catch (e) {
            // 키보드 상태 동기화 에러 무시 (Flutter 버그)
            debugPrint('Keyboard event error (ignored): $e');
          }
          return KeyEventResult.ignored;
        },
        child: Scaffold(
          // Drawer animation improvements
          drawerEdgeDragWidth: 60, // Wider swipe area for easier access
          drawerScrimColor: Colors.black.withOpacity(0.3), // Subtler backdrop
          appBar: AppBar(
            elevation: 0,
            toolbarHeight: 40,
            leading: Builder(
              builder: (context) => GestureDetector(
                onTap: () => Scaffold.of(context).openDrawer(),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Opacity(
                      opacity: 0.8,
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        width: 24,
                        height: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.surface,
          drawer: MyDrawer(
            memoSpaces: memoSpaces,
            onTap: openMemoSpace,
            onDelete: deleteMemoSpace,
            onSettingsChanged: reloadCompletionService,
          ),
          body: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              openedMemoSpaceTabs(openedMemoSpaces, focusedMemoSpace),
              // 검색 바
              if (_isSearching) _buildSearchBar(),
              focusedMemoEditor(focusedMemoSpace),
            ],
          ),
        ),
      ),
    );
  }
}

/// Represents a search match position
class SearchMatch {
  final int memoIndex;
  final int position;

  SearchMatch({required this.memoIndex, required this.position});
}

/// A button with hover and press scale animation
class _HoverScaleButton extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  final Color? hoverColor;

  const _HoverScaleButton({
    required this.onTap,
    required this.child,
    this.hoverColor,
  });

  @override
  State<_HoverScaleButton> createState() => _HoverScaleButtonState();
}

class _HoverScaleButtonState extends State<_HoverScaleButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 100),
          scale: _isPressed ? 0.9 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _isHovered
                  ? (widget.hoverColor ??
                      colorScheme.inversePrimary.withOpacity(0.1))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// Add tab button with hover effect
class _AddTabButton extends StatefulWidget {
  final VoidCallback onTap;
  final Color borderColor;

  const _AddTabButton({
    required this.onTap,
    required this.borderColor,
  });

  @override
  State<_AddTabButton> createState() => _AddTabButtonState();
}

class _AddTabButtonState extends State<_AddTabButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          width: 34,
          height: 32,
          decoration: BoxDecoration(
            color: _isHovered
                ? colorScheme.inversePrimary.withOpacity(0.08)
                : Colors.transparent,
            border: Border(
              left: BorderSide(color: widget.borderColor, width: 1),
            ),
          ),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 100),
            scale: _isPressed ? 0.85 : 1.0,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  Icons.add,
                  size: 16,
                  color: _isHovered
                      ? colorScheme.inversePrimary.withOpacity(0.8)
                      : colorScheme.inversePrimary.withOpacity(0.5),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
