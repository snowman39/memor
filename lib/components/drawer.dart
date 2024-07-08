import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:memor/components/drawer_tile.dart';
import 'package:memor/models/memo_space.dart';
import 'package:memor/theme/theme_provider.dart';

class MyDrawer extends StatelessWidget {
  final List<MemoSpace> memoSpaces;
  final void Function(MemoSpace)? onTap;
  final void Function(MemoSpace)? onDelete;

  const MyDrawer(
      {super.key,
      required this.memoSpaces,
      required this.onTap,
      required this.onDelete});

  List<DrawerTile> renderMemoSpaces() {
    return memoSpaces
        .map((memoSpace) => DrawerTile(
              title: memoSpace.name,
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                iconSize: 18,
                onPressed: () => onDelete!(memoSpace),
              ),
              onTap: () => onTap!(memoSpace),
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Theme.of(context).colorScheme.inversePrimary,
        shape: const BeveledRectangleBorder(),
        child: Column(
          children: [
            const SizedBox(
              height: 20,
            ),
            ...renderMemoSpaces(),
            Divider(
              color: Theme.of(context).colorScheme.secondary,
              thickness: 1,
              indent: 20,
              endIndent: 20,
            ),
            DrawerTile(
              title: "Dark Mode",
              trailing: CupertinoSwitch(
                value: Provider.of<ThemeProvider>(context, listen: false)
                    .isDarkMode,
                onChanged: (value) => {
                  Provider.of<ThemeProvider>(context, listen: false)
                      .toggleTheme()
                },
              ),
              onTap: () {},
            )
          ],
        ));
  }
}
