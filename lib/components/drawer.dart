import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:memor/components/drawer_tile.dart';
import 'package:memor/models/memo_space.dart';
import 'package:memor/pages/settings_page.dart';
import 'package:memor/theme/theme_provider.dart';

class MyDrawer extends StatelessWidget {
  final List<MemoSpace> memoSpaces;
  final void Function(MemoSpace)? onTap;
  final void Function(MemoSpace)? onDelete;
  final VoidCallback? onSettingsChanged;

  const MyDrawer(
      {super.key,
      required this.memoSpaces,
      required this.onTap,
      required this.onDelete,
      this.onSettingsChanged});

  List<DrawerTile> renderMemoSpaces() {
    return memoSpaces
        .map((memoSpace) => DrawerTile(
              title: memoSpace.name,
              trailing: SizedBox(
                width: 28,
                height: 28,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onDelete!(memoSpace),
                    child: const Center(
                      child: Icon(Icons.delete, size: 16),
                    ),
                  ),
                ),
              ),
              onTap: () => onTap!(memoSpace),
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    // 선택 안된 탭과 같은 색상으로 통일
    final drawerColor = Color.lerp(
      Theme.of(context).colorScheme.surface,
      Theme.of(context).colorScheme.primary,
      0.4,
    )!;
    
    return Drawer(
        backgroundColor: drawerColor,
        surfaceTintColor: Colors.transparent,
        shape: const BeveledRectangleBorder(),
        child: Column(
          children: [
            const SizedBox(
              height: 20,
            ),
            ...renderMemoSpaces(),
            Divider(
              color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.1),
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
            ),
            DrawerTile(
              title: "Settings",
              trailing: Icon(
                Icons.settings,
                size: 20,
                color: Theme.of(context).colorScheme.inversePrimary,
              ),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                ).then((_) {
                  // Settings 페이지에서 돌아온 후 completion service 다시 로드
                  onSettingsChanged?.call();
                });
              },
            )
          ],
        ));
  }
}
