import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:memor/components/drawer.dart';
import 'package:memor/models/memo_space.dart';
import 'package:memor/models/memo_space_database.dart';
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
  Timer? timer;
  int? editingTabId;
  final ScrollController _tabScrollController = ScrollController();

  // 더블탭 감지를 위한 변수
  int? _lastTappedTabId;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    readMemoSpaces();
  }

  @override
  void dispose() {
    _tabScrollController.dispose();
    for (var controller in _memoControllers.values) {
      controller.dispose();
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

    BoxDecoration leftTab = BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(
        bottom: BorderSide(
          color: Theme.of(context).colorScheme.inversePrimary,
          width: 1,
        ),
      ),
    );

    BoxDecoration leftFocusedTab = BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
    );

    BoxDecoration middleTab = BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(
        left: BorderSide(
          color: Theme.of(context).colorScheme.inversePrimary,
          width: 1,
        ),
        bottom: BorderSide(
          color: Theme.of(context).colorScheme.inversePrimary,
          width: 1,
        ),
      ),
    );

    BoxDecoration middleFocusedTab = BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(
        left: BorderSide(
          color: Theme.of(context).colorScheme.inversePrimary,
          width: 1,
        ),
      ),
    );

    BoxDecoration draggedTab = BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(
        top: BorderSide(
          color: Theme.of(context).colorScheme.inversePrimary,
          width: 1,
        ),
        bottom: BorderSide(
          color: Theme.of(context).colorScheme.inversePrimary,
          width: 1,
        ),
        left: BorderSide(
          color: Theme.of(context).colorScheme.inversePrimary,
          width: 1,
        ),
        right: BorderSide(
          color: Theme.of(context).colorScheme.inversePrimary,
          width: 1,
        ),
      ),
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
                // Top border
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: Container(
                    height: 1,
                    color: Theme.of(context).colorScheme.inversePrimary,
                  ),
                ),
                // Bottom border (맨 아래 layer)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 1,
                    color: Theme.of(context).colorScheme.inversePrimary,
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
                            return DragTarget<int>(
                              onAcceptWithDetails: (from) {
                                dragMemoSpace(from.data, i);
                              },
                              builder: (context, _, __) {
                                return Draggable<int>(
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
                                                            openedMemoSpaces[i]
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
                                                  fontWeight: FontWeight.w700,
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
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surface
                                          .withOpacity(0.5),
                                      border: Border(
                                        top: BorderSide(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .inversePrimary,
                                          width: 1,
                                        ),
                                        bottom: BorderSide(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .inversePrimary,
                                          width: 1,
                                        ),
                                        left: i == 0
                                            ? BorderSide.none
                                            : BorderSide(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .inversePrimary,
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
                                      height: isFocused ? 31 : 30,
                                      decoration: (i == 0)
                                          ? (openedMemoSpaces.length == 1)
                                              ? middleFocusedTab
                                              : (isFocused)
                                                  ? leftFocusedTab
                                                  : leftTab
                                          : (isFocused)
                                              ? middleFocusedTab
                                              : middleTab,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          // 탭 제목 (편집 모드)
                                          if (editingTabId ==
                                              openedMemoSpaces[i].id)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 12, right: 32),
                                              child: Focus(
                                                onFocusChange: (hasFocus) {
                                                  if (!hasFocus) {
                                                    updateMemoSpace(
                                                        openedMemoSpaces[i]);
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
                                                    openedMemoSpaces[i].name =
                                                        text;
                                                  },
                                                  onSubmitted: (text) {
                                                    updateMemoSpace(
                                                        openedMemoSpaces[i]);
                                                    setState(() {
                                                      editingTabId = null;
                                                    });
                                                  },
                                                  decoration:
                                                      const InputDecoration(
                                                    border: InputBorder.none,
                                                    isDense: true,
                                                    contentPadding:
                                                        EdgeInsets.symmetric(
                                                            vertical: 9),
                                                  ),
                                                  textAlign: TextAlign.left,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
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
                                                  final now = DateTime.now();
                                                  final tabId =
                                                      openedMemoSpaces[i].id;

                                                  // 더블탭 감지 (300ms 이내 같은 탭 클릭)
                                                  if (_lastTappedTabId ==
                                                          tabId &&
                                                      _lastTapTime != null &&
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
                                                        openedMemoSpaces[i]);
                                                    _lastTappedTabId = tabId;
                                                    _lastTapTime = now;
                                                  }
                                                },
                                                child: Container(
                                                  color: Colors.transparent,
                                                  padding:
                                                      const EdgeInsets.only(
                                                          left: 12, right: 32),
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: Text(
                                                    openedMemoSpaces[i].name,
                                                    textAlign: TextAlign.left,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: isFocused
                                                          ? FontWeight.w700
                                                          : FontWeight.normal,
                                                      color: Theme.of(context)
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
                                              opacity: (isFocused || hovered[i])
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
                                );
                              },
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
    return Container(
      height: 32,
      width: 34,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.inversePrimary,
            width: 1,
          ),
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.inversePrimary,
            width: 1,
          ),
          left: BorderSide(
            color: Theme.of(context).colorScheme.inversePrimary,
            width: 1,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: createMemoSpace,
          child: const Center(
            child: Icon(Icons.add, size: 16),
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
        child: TextField(
          style: TextStyle(
            color: Theme.of(context).colorScheme.inversePrimary,
            fontSize: 14,
          ),
          controller: controller,
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

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            HardwareKeyboard.instance.isMetaPressed &&
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
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          toolbarHeight: 40,
          leading: Builder(
            builder: (context) => Padding(
              padding: const EdgeInsets.all(10.0),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => Scaffold.of(context).openDrawer(),
                  child: const Center(
                    child: Icon(Icons.menu, size: 18),
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
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            openedMemoSpaceTabs(openedMemoSpaces, focusedMemoSpace),
            focusedMemoEditor(focusedMemoSpace),
          ],
        ),
      ),
    );
  }
}
