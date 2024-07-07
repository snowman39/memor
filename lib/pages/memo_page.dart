import 'dart:async';

import 'package:flutter/material.dart';
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
  MemoSpace? focusedMemoSpace;
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

  void _updateDatabase() {
    print("Updating database");
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

    BoxDecoration leftMostBox = BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(
        top: BorderSide(
          color: Theme.of(context).colorScheme.inversePrimary,
          width: 1,
        ),
        right: BorderSide(
          color: Theme.of(context).colorScheme.inversePrimary,
          width: 1,
        ),
        bottom: BorderSide(
          color: Theme.of(context).colorScheme.inversePrimary,
          width: 1,
        ),
      ),
    );

    BoxDecoration rightMostBox = BoxDecoration(
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

    BoxDecoration middleBox = BoxDecoration(
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

    BoxDecoration focusedBox = BoxDecoration(
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

    for (final (i, memoSpace) in openedMemoSpaces.indexed) {
      BoxDecoration? boxDecoration;
      if (focusedMemoSpace != null && memoSpace.id == focusedMemoSpace.id) {
        boxDecoration = focusedBox;
      } else if (i == 0) {
        boxDecoration = leftMostBox;
      } else if (i == openedMemoSpaces.length - 1) {
        boxDecoration = rightMostBox;
      } else {
        boxDecoration = middleBox;
      }

      openedMemoSpacesWidgets.add(
        Expanded(
          flex: 2,
          child: Container(
            decoration: boxDecoration,
            child: TextButton(
              onPressed: () {
                setFocusedMemoSpace(memoSpace);
              },
              child: Text(
                memoSpace.name,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.inversePrimary),
              ),
            ),
          ),
        ),
      );
    }
    return openedMemoSpacesWidgets;
  }

  Container renderCreateMemoSpaceButton() {
    return Container(
      height: 38,
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

    return Expanded(
      flex: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: TextField(
          controller: controller,
          onChanged: (text) {
            focusedMemoSpace.memo = text;
            if (timer?.isActive ?? false) timer?.cancel();
            timer = Timer(
              const Duration(seconds: 1),
              () => updateMemoSpace(focusedMemoSpace),
            );
          },
          // onTap
          // onTapOutside
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

    if (focusedMemoSpace == null) {
      for (final memoSpace in memoSpaces) {
        if (memoSpace.opened) {
          focusedMemoSpace = memoSpace;
          break;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.inversePrimary,
        toolbarHeight: 40,
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      drawer: const MyDrawer(),
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
          // focused memo editor
          renderFocusedMemoEditor(focusedMemoSpace),
        ],
      ),
    );
  }
}
