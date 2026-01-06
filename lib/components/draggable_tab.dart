import 'package:flutter/material.dart';
import 'package:memor/models/memo_space.dart';

class DraggableTab extends StatelessWidget {
  final MemoSpace memoSpace;
  final BoxDecoration decoration;
  final bool isFocused;
  final void Function(MemoSpace) updateMemoSpace;
  final void Function(MemoSpace) closeMemoSpace;
  final void Function(MemoSpace) setFocusedMemoSpace;

  const DraggableTab({
    super.key,
    required this.memoSpace,
    required this.updateMemoSpace,
    required this.closeMemoSpace,
    required this.setFocusedMemoSpace,
    required this.decoration,
    required this.isFocused,
  });

  @override
  Widget build(BuildContext context) {
    TextEditingController controller =
        TextEditingController(text: memoSpace.name);

    return Expanded(
      child: Container(
        height: 32,
        decoration: decoration,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (isFocused)
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: (text) {
                    memoSpace.name = text;
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
              )
            else
              TextButton(
                onPressed: () {
                  setFocusedMemoSpace(memoSpace);
                },
                child: Text(
                  memoSpace.name,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.inversePrimary,
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(
                Icons.close,
                color: Colors.white,
              ),
              onPressed: () {
                closeMemoSpace(memoSpace);
              },
            ),
          ],
        ),
      ),
    );
  }
}
