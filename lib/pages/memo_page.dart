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

class ShiftFocusToLeft extends Intent {
  const ShiftFocusToLeft();
}

class ShiftFocusToRight extends Intent {
  const ShiftFocusToRight();
}

class _MemoPageState extends State<MemoPage> {
  List<MemoSpace> openedMemoSpaces = [];
  List<bool> hovered = [];

  MemoSpace? focusedMemoSpace;
  Map<int, TextSelection> textEditorPositions = {};
  Timer? timer;

  @override
  void initState() {
    super.initState();
    readMemoSpaces();
  }

  void setFocusedMemoSpace(MemoSpace memoSpace) {
    if (!memoSpace.opened) {
      memoSpace.opened = true;
      updateMemoSpace(memoSpace);
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
    openedMemoSpaces.add(memoSpace);
    memoSpace.opened = true;
    updateMemoSpace(memoSpace);
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
    updateMemoSpace(memoSpace);
    openedMemoSpaces.remove(memoSpace);
    hovered.removeAt(index);
  }

  void createMemoSpace() {
    context.read<MemoSpaceDatabase>().createMemoSpace();
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

  void deleteMemoSpace(MemoSpace memoSpace) {
    if (focusedMemoSpace != null && memoSpace.id == focusedMemoSpace!.id) {
      focusedMemoSpace = null;
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
        top: BorderSide(
          color: Theme.of(context).colorScheme.inversePrimary,
          width: 1,
        ),
        bottom: BorderSide(
          color: Theme.of(context).colorScheme.inversePrimary,
          width: 1,
        ),
      ),
    );

    BoxDecoration leftFocusedTab = BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(
        top: BorderSide(
          color: Theme.of(context).colorScheme.inversePrimary,
          width: 1,
        ),
        bottom: BorderSide(
          color: Theme.of(context).colorScheme.surface,
          width: 1,
        ),
      ),
    );

    BoxDecoration middleTab = BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(
        top: BorderSide(
          color: Theme.of(context).colorScheme.inversePrimary,
          width: 1,
        ),
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
        top: BorderSide(
          color: Theme.of(context).colorScheme.inversePrimary,
          width: 1,
        ),
        left: BorderSide(
          color: Theme.of(context).colorScheme.inversePrimary,
          width: 1,
        ),
        bottom: BorderSide(
          color: Theme.of(context).colorScheme.surface,
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

    return SizedBox(
      height: 32,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            shrinkWrap: true,
            physics: const ScrollPhysics(),
            itemCount: (openedMemoSpaces.length + 1),
            itemBuilder: (context, i) {
              if (i == openedMemoSpaces.length) {
                return createMemoSpaceButton();
              }
              bool isFocused = openedMemoSpaces.indexOf(focusedMemoSpace!) == i;
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
                        width: (constraints.maxWidth - 34) /
                            openedMemoSpaces.length,
                        decoration: draggedTab,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (isFocused)
                              Expanded(
                                child: TextField(
                                  controller: TextEditingController(
                                      text: openedMemoSpaces[i].name),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding:
                                        EdgeInsets.symmetric(vertical: 9),
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
                                  setFocusedMemoSpace(openedMemoSpaces[i]);
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
                    childWhenDragging: const SizedBox(
                      height: 32,
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
                        width: (constraints.maxWidth - 34) /
                            openedMemoSpaces.length,
                        decoration: (i == 0)
                            ? (openedMemoSpaces.length == 1)
                                ? middleFocusedTab
                                : (isFocused)
                                    ? leftFocusedTab
                                    : leftTab
                            : (isFocused)
                                ? middleFocusedTab
                                : middleTab,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: isFocused
                              ? [
                                  Expanded(
                                    child: TextField(
                                      controller: TextEditingController(
                                          text: openedMemoSpaces[i].name),
                                      onChanged: (text) {
                                        openedMemoSpaces[i].name = text;
                                      },
                                      onTapOutside: (event) {
                                        updateMemoSpace(openedMemoSpaces[i]);
                                      },
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding:
                                            EdgeInsets.symmetric(vertical: 9),
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
                                  ),
                                  closeMemoSpaceButton(openedMemoSpaces[i]),
                                ]
                              : [
                                  TextButton(
                                    onPressed: () {
                                      setFocusedMemoSpace(openedMemoSpaces[i]);
                                    },
                                    child: Text(
                                      openedMemoSpaces[i].name,
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .inversePrimary),
                                    ),
                                  ),
                                  hovered[i]
                                      ? closeMemoSpaceButton(
                                          openedMemoSpaces[i])
                                      : const SizedBox(),
                                ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  IconButton closeMemoSpaceButton(MemoSpace memoSpace) {
    return IconButton(
      icon: const Icon(Icons.close),
      onPressed: () => closeMemoSpace(memoSpace),
      iconSize: 16,
      splashRadius: 20,
    );
  }

  SizedBox createMemoSpaceButton() {
    return SizedBox(
      child: Container(
        height: 34,
        width: 34,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: Theme.of(context).colorScheme.inversePrimary,
            width: 1,
          ),
        ),
        child: IconButton(
          onPressed: createMemoSpace,
          icon: const Icon(Icons.add),
          iconSize: 16,
          splashRadius: 34,
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

    TextEditingController controller =
        TextEditingController(text: focusedMemoSpace.memo);
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

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.bracketLeft):
            const ShiftFocusToLeft(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.bracketRight):
            const ShiftFocusToRight(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          ShiftFocusToLeft: CallbackAction<ShiftFocusToLeft>(
            onInvoke: (_) => setState(
              () {
                if (openedMemoSpaces.isEmpty ||
                    focusedMemoSpace! == openedMemoSpaces.first) return;
                setFocusedMemoSpace(openedMemoSpaces[
                    openedMemoSpaces.indexOf(focusedMemoSpace!) - 1]);
              },
            ),
          ),
          ShiftFocusToRight: CallbackAction<ShiftFocusToRight>(
            onInvoke: (_) => setState(
              () {
                if (openedMemoSpaces.isEmpty ||
                    focusedMemoSpace! == openedMemoSpaces.last) return;
                setFocusedMemoSpace(openedMemoSpaces[
                    openedMemoSpaces.indexOf(focusedMemoSpace!) + 1]);
              },
            ),
          ),
        },
        child: FocusScope(
          autofocus: true,
          child: Scaffold(
            appBar: AppBar(
              elevation: 0,
              toolbarHeight: 40,
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
        ),
      ),
    );
  }
}
