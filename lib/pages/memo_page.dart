import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:memor/components/autocomplete_text_field.dart';
import 'package:memor/components/drawer.dart';
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
  Map<int, TextSelection> textEditorPositions = {};
  final Map<int, TextEditingController> _memoControllers = {};
  final Map<int, FocusNode> _memoFocusNodes = {};
  final Map<int, ScrollController> _memoScrollControllers = {};
  Timer? timer;
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
  List<int> _searchMatches = []; // 검색 결과 위치들
  int _currentMatchIndex = -1;

  @override
  void initState() {
    super.initState();
    readMemoSpaces();
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
    if (focusedMemoSpace == null || query.isEmpty) {
      setState(() {
        _searchMatches.clear();
        _currentMatchIndex = -1;
      });
      return;
    }

    final text = focusedMemoSpace!.memo.toLowerCase();
    final searchQuery = query.toLowerCase();
    final matches = <int>[];

    int index = 0;
    while (true) {
      index = text.indexOf(searchQuery, index);
      if (index == -1) break;
      matches.add(index);
      index += 1;
    }

    setState(() {
      _searchMatches = matches;
      _currentMatchIndex = matches.isNotEmpty ? 0 : -1;
    });
    // 검색어 입력 중에는 focus 이동 안 함 - Enter나 버튼 클릭 시에만 이동
  }

  void _nextMatch() {
    if (_searchMatches.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _searchMatches.length;
    });
    _highlightMatch();
  }

  void _previousMatch() {
    if (_searchMatches.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex - 1 + _searchMatches.length) % _searchMatches.length;
    });
    _highlightMatch();
  }

  void _highlightMatch() {
    if (_currentMatchIndex < 0 || focusedMemoSpace == null) return;
    
    final controller = _memoControllers[focusedMemoSpace!.id];
    final focusNode = _memoFocusNodes[focusedMemoSpace!.id];
    final scrollController = _memoScrollControllers[focusedMemoSpace!.id];
    if (controller == null) return;

    final matchStart = _searchMatches[_currentMatchIndex];
    final matchEnd = matchStart + _searchController.text.length;

    // 에디터에 focus를 줘야 selection이 보임
    if (focusNode != null) {
      focusNode.requestFocus();
    }

    // selection 설정
    Future.delayed(const Duration(milliseconds: 30), () {
      if (mounted) {
        controller.selection = TextSelection(
          baseOffset: matchStart,
          extentOffset: matchEnd,
        );
      }
    });
    
    // 스크롤 위치 계산 및 이동
    if (scrollController != null && scrollController.hasClients) {
      final text = controller.text.substring(0, matchStart);
      final lineCount = '\n'.allMatches(text).length;
      const lineHeight = 20.0; // 대략적인 줄 높이
      final targetScroll = lineCount * lineHeight;
      
      final maxScroll = scrollController.position.maxScrollExtent;
      final viewportHeight = scrollController.position.viewportDimension;
      
      // 현재 뷰포트에 보이지 않으면 스크롤
      final currentScroll = scrollController.offset;
      if (targetScroll < currentScroll || targetScroll > currentScroll + viewportHeight - 50) {
        scrollController.animateTo(
          (targetScroll - viewportHeight / 3).clamp(0.0, maxScroll),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _tabScrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    for (var controller in _memoControllers.values) {
      controller.dispose();
    }
    for (var focusNode in _memoFocusNodes.values) {
      focusNode.dispose();
    }
    for (var scrollController in _memoScrollControllers.values) {
      scrollController.dispose();
    }
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

  void updateMemoSpace(MemoSpace memoSpace) {
    context.read<MemoSpaceDatabase>().updateMemoSpace(
          memoSpace.id,
          memoSpace.name,
          memoSpace.memo,
        );
  }

  void updateOpenedState(MemoSpace memoSpace) {
    context.read<MemoSpaceDatabase>().updateOpenedState(
          memoSpace.id,
          memoSpace.opened,
        );
  }

  void deleteMemoSpace(MemoSpace memoSpace) {
    // 열려있는 탭이면 닫기 (updateMemoSpace 없이)
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
        }
      }
      openedMemoSpaces.remove(openedTab);
      if (index >= 0 && index < hovered.length) {
        hovered.removeAt(index);
      }
    }
    context.read<MemoSpaceDatabase>().deleteMemoSpace(memoSpace.id);
  }

  SizedBox openedMemoSpaceTabs(
      List<MemoSpace> openedMemoSpaces, MemoSpace? focusedMemoSpace) {
    if (openedMemoSpaces.isEmpty) {
      return const SizedBox(
        height: 32,
        child: Center(
          child: Text('No memospace opened'),
        ),
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
    final borderColor = Theme.of(context).colorScheme.inversePrimary.withOpacity(0.08);

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
          border: isFocused ? null : Border(
            bottom: BorderSide(color: borderColor, width: 1),
          ),
        );
      } else {
        return BoxDecoration(
          color: bgColor,
          border: Border(
            left: BorderSide(color: borderColor, width: 1),
            bottom: isFocused ? BorderSide.none : BorderSide(color: borderColor, width: 1),
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

    const double minTabWidth = 120;

    return SizedBox(
      height: 32,
      width: double.infinity,
      child: Row(
        children: [
          Expanded(
            child: Stack(
              children: [
                // Top border (연한 색상)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: Container(
                    height: 1,
                    color: borderColor,
                  ),
                ),
                // Bottom border (연한 색상)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 1,
                    color: borderColor,
                  ),
                ),
                // 탭 영역 (위 layer - bottom border를 덮을 수 있음)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 1,
                  bottom: 0,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double availableWidth = constraints.maxWidth;
                      final double tabWidth =
                          (availableWidth / openedMemoSpaces.length)
                              .clamp(minTabWidth, double.infinity);

                      return Scrollbar(
                        controller: _tabScrollController,
                        thumbVisibility: false,
                        thickness: 3,
                        radius: const Radius.circular(2),
                        child: ListView.builder(
                          controller: _tabScrollController,
                          scrollDirection: Axis.horizontal,
                          shrinkWrap: true,
                          physics: const ClampingScrollPhysics(),
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
                                final isDropTarget = candidateData.isNotEmpty &&
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
                                        borderRadius: BorderRadius.circular(2),
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
                                                MainAxisAlignment.spaceBetween,
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
                                                      border: InputBorder.none,
                                                      isDense: true,
                                                      contentPadding:
                                                          EdgeInsets.symmetric(
                                                              vertical: 9),
                                                    ),
                                                    textAlign: TextAlign.center,
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
                                                        color: Theme.of(context)
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
                                          color: inactiveTabColor.withOpacity(0.5),
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
                                        child: Container(
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
                                                          left: 17, right: 32),
                                                  child: Focus(
                                                    onFocusChange: (hasFocus) {
                                                      if (!hasFocus) {
                                                        updateMemoSpace(
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
                                                        updateMemoSpace(
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
                                                      textAlign: TextAlign.left,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: Theme.of(context)
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
                                                          editingTabId = tabId;
                                                        });
                                                        _lastTappedTabId = null;
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
                                                      color: Colors.transparent,
                                                      padding:
                                                          const EdgeInsets.only(
                                                              left: 17,
                                                              right: 32),
                                                      alignment:
                                                          Alignment.centerLeft,
                                                      child: Text(
                                                        openedMemoSpaces[i]
                                                            .name,
                                                        textAlign:
                                                            TextAlign.left,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight: isFocused
                                                              ? FontWeight.w700
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
                                                  opacity:
                                                      (isFocused || hovered[i])
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
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          createMemoSpaceButton(),
        ],
      ),
    );
  }

  Widget closeMemoSpaceButton(MemoSpace memoSpace) {
    return SizedBox(
      width: 28,
      height: 28,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => closeMemoSpace(memoSpace),
          child: const Center(
            child: Icon(Icons.close, size: 14),
          ),
        ),
      ),
    );
  }

  Widget createMemoSpaceButton() {
    final borderColor = Theme.of(context).colorScheme.inversePrimary.withOpacity(0.08);
    final inactiveColor = Color.lerp(
      Theme.of(context).colorScheme.surface,
      Theme.of(context).colorScheme.primary,
      0.4,
    )!;
    return Container(
      height: 32,
      width: 34,
      decoration: BoxDecoration(
        color: inactiveColor,
        border: Border(
          top: BorderSide(
            color: borderColor,
            width: 1,
          ),
          bottom: BorderSide(
            color: borderColor,
            width: 1,
          ),
          left: BorderSide(
            color: borderColor,
            width: 1,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: createMemoSpace,
          child: Center(
            child: Icon(
              Icons.add, 
              size: 16,
              color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.5),
            ),
          ),
        ),
      ),
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
              color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.6),
            ),
          ),
        ),
      ),
    );
  }

  Expanded focusedMemoEditor(MemoSpace? focusedMemoSpace) {
    if (focusedMemoSpace == null) {
      return const Expanded(
        child: Center(
          child: Text('No memospace opened'),
        ),
      );
    }

    // 캐싱된 controller 사용 또는 새로 생성
    TextEditingController controller;
    if (_memoControllers.containsKey(focusedMemoSpace.id)) {
      controller = _memoControllers[focusedMemoSpace.id]!;
      // 텍스트가 변경되었으면 업데이트
      if (controller.text != focusedMemoSpace.memo) {
        controller.text = focusedMemoSpace.memo;
      }
    } else {
      controller = TextEditingController(text: focusedMemoSpace.memo);
      _memoControllers[focusedMemoSpace.id] = controller;
    }

    // 캐싱된 FocusNode 사용 또는 새로 생성
    FocusNode focusNode;
    if (_memoFocusNodes.containsKey(focusedMemoSpace.id)) {
      focusNode = _memoFocusNodes[focusedMemoSpace.id]!;
    } else {
      focusNode = FocusNode();
      _memoFocusNodes[focusedMemoSpace.id] = focusNode;
    }

    // 캐싱된 ScrollController 사용 또는 새로 생성
    ScrollController scrollController;
    if (_memoScrollControllers.containsKey(focusedMemoSpace.id)) {
      scrollController = _memoScrollControllers[focusedMemoSpace.id]!;
    } else {
      scrollController = ScrollController();
      _memoScrollControllers[focusedMemoSpace.id] = scrollController;
    }

    TextSelection? savedPosition = textEditorPositions[focusedMemoSpace.id];
    if (savedPosition != null) {
      int maxOffset = focusedMemoSpace.memo.length;
      controller.selection = TextSelection(
        baseOffset: savedPosition.baseOffset.clamp(0, maxOffset),
        extentOffset: savedPosition.extentOffset.clamp(0, maxOffset),
      );
    }

    return Expanded(
      flex: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: AutocompleteTextField(
          style: TextStyle(
            color: Theme.of(context).colorScheme.inversePrimary,
            fontSize: 14,
            height: 1.5, // 줄 높이
            leadingDistribution: TextLeadingDistribution.even,
          ),
          controller: controller,
          focusNode: focusNode,
          scrollController: scrollController,
          completionService: _completionService,
          onChanged: (text) {
            focusedMemoSpace.memo = text;
            if (timer?.isActive ?? false) timer?.cancel();
            timer = Timer(const Duration(seconds: 1), () {
              textEditorPositions[focusedMemoSpace.id] = controller.selection;
              updateMemoSpace(focusedMemoSpace);
            });
          },
          maxLines: null,
          decoration: const InputDecoration(
            border: InputBorder.none,
          ),
          autofocus: true,
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
              if (event.logicalKey == LogicalKeyboardKey.escape && _isSearching) {
                _toggleSearch();
                return KeyEventResult.handled;
              }
              // 검색 모드에서 Enter : 다음/이전 검색 결과로 이동
              if (_isSearching && _searchMatches.isNotEmpty &&
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
