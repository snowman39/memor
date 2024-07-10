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

class MoveFocusedMemoSpaceLeft extends Intent {
  const MoveFocusedMemoSpaceLeft();
}

class MoveFocusedMemoSpaceRight extends Intent {
  const MoveFocusedMemoSpaceRight();
}

class _MemoPageState extends State<MemoPage> {
  MemoSpace? focusedMemoSpace;
  int? textEditorOffset;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    readMemoSpaces();
  }

  void _handleShortcut() {
    // Your custom function here
    print('Shortcut triggered!');
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

  void openMemoSpace(MemoSpace memoSpace) {
    memoSpace.opened = true;
    updateMemoSpace(memoSpace);
    setFocusedMemoSpace(memoSpace);
  }

  // create memo space
  void createMemoSpace() {
    // create a new empty memo space
    context.read<MemoSpaceDatabase>().createMemoSpace();
  }

  // read memo spaces
  void readMemoSpaces() {
    // read all memo spaces
    context.read<MemoSpaceDatabase>().readMemoSpaces();
  }

  // update memo space
  void updateMemoSpace(MemoSpace memoSpace) {
    context.read<MemoSpaceDatabase>().updateMemoSpace(
          memoSpace.id,
          memoSpace.name,
          memoSpace.memo,
        );
  }

  // delete memo space
  void deleteMemoSpace(MemoSpace memoSpace) {
    if (focusedMemoSpace != null && memoSpace.id == focusedMemoSpace!.id) {
      focusedMemoSpace = null;
    }
    context.read<MemoSpaceDatabase>().deleteMemoSpace(memoSpace.id);
  }

  // TODO: refactor this function into a separate widget file
  List<Expanded> renderOpenedMemoSpaces(
      List<MemoSpace> memoSpaces, MemoSpace? focusedMemoSpace) {
    List<MemoSpace> openedMemoSpaces = [];
    for (final memoSpace in memoSpaces) {
      if (memoSpace.opened) {
        openedMemoSpaces.add(memoSpace);
      }
    }

    List<Expanded> openedMemoSpacesWidgets = [];

    BoxDecoration leftBox = BoxDecoration(
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

    BoxDecoration leftFocusedBox = BoxDecoration(
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

    BoxDecoration middleBox = BoxDecoration(
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

    BoxDecoration middlefocusedBox = BoxDecoration(
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

    for (final (i, memoSpace) in openedMemoSpaces.indexed) {
      BoxDecoration? boxDecoration;
      bool isFocused =
          focusedMemoSpace != null && memoSpace.id == focusedMemoSpace.id;

      if (i == 0) {
        if (openedMemoSpaces.length == 1) {
          boxDecoration = middlefocusedBox;
        } else if (isFocused) {
          boxDecoration = leftFocusedBox;
        } else {
          boxDecoration = leftBox;
        }
      } else {
        if (isFocused) {
          boxDecoration = middlefocusedBox;
        } else {
          boxDecoration = middleBox;
        }
      }

      openedMemoSpacesWidgets.add(
        Expanded(
          flex: 2,
          child: Container(
            decoration: boxDecoration,
            child: Builder(builder: (context) {
              if (isFocused) {
                return SizedBox(
                  height: 32,
                  child: TextField(
                    controller: TextEditingController(text: memoSpace.name),
                    onChanged: (text) {
                      memoSpace.name = text;
                      // updateMemoSpace(memoSpace);
                    },
                    onTapOutside: (event) {
                      updateMemoSpace(memoSpace);
                    },
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.inversePrimary,
                    ),
                  ),
                );
              }
              return TextButton(
                onPressed: () {
                  setFocusedMemoSpace(memoSpace);
                },
                child: Text(
                  memoSpace.name,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.inversePrimary),
                ),
              );
            }),
          ),
        ),
      );
    }
    return openedMemoSpacesWidgets;
  }

  Container renderCreateMemoSpaceButton() {
    return Container(
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
    );
  }

  Expanded renderFocusedMemoEditor(MemoSpace? focusedMemoSpace) {
    if (focusedMemoSpace == null) {
      return const Expanded(
        flex: 10,
        child: Center(
          child: Text('No memo space opened'),
        ),
      );
    }

    TextEditingController controller =
        TextEditingController(text: focusedMemoSpace.memo);
    controller.selection = TextSelection(
      baseOffset: textEditorOffset ?? 0,
      extentOffset: textEditorOffset ?? 0,
    );

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
              textEditorOffset = controller.selection.baseOffset;
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
    List<MemoSpace> openedMemoSpaces = memoSpaces.where((memoSpace) {
      return memoSpace.opened;
    }).toList();

    if (focusedMemoSpace == null) {
      for (final memoSpace in memoSpaces) {
        if (memoSpace.opened) {
          focusedMemoSpace = memoSpace;
          break;
        }
      }
    }

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.bracketLeft):
            const MoveFocusedMemoSpaceLeft(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.bracketRight):
            const MoveFocusedMemoSpaceRight(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          MoveFocusedMemoSpaceLeft: CallbackAction<MoveFocusedMemoSpaceLeft>(
            onInvoke: (_) => setState(
              () {
                if (focusedMemoSpace == null) return;
                int index = openedMemoSpaces.indexOf(focusedMemoSpace!);
                if (index == 0) return;
                setFocusedMemoSpace(memoSpaces[index - 1]);
              },
            ),
          ),
          MoveFocusedMemoSpaceRight: CallbackAction<MoveFocusedMemoSpaceRight>(
            onInvoke: (_) => setState(
              () {
                if (focusedMemoSpace == null) return;
                int index = openedMemoSpaces.indexOf(focusedMemoSpace!);
                if (index == memoSpaces.length - 1) return;
                setFocusedMemoSpace(memoSpaces[index + 1]);
              },
            ),
          ),
        },
        child: FocusScope(
          autofocus: true,
          // focusNode: FocusNode(),
          child: Scaffold(
            appBar: AppBar(
              elevation: 0,
              backgroundColor: Colors.transparent,
              foregroundColor: Theme.of(context).colorScheme.inversePrimary,
              toolbarHeight: 40,
            ),
            backgroundColor: Theme.of(context).colorScheme.surface,
            drawer: MyDrawer(
                memoSpaces: memoSpaces,
                onTap: openMemoSpace,
                onDelete: deleteMemoSpace),
            body: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ...renderOpenedMemoSpaces(memoSpaces, focusedMemoSpace),
                    renderCreateMemoSpaceButton(),
                  ],
                ),
                renderFocusedMemoEditor(focusedMemoSpace),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
