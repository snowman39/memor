import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:memor/components/drawer_tile.dart';
import 'package:memor/models/memo_space.dart';
import 'package:memor/pages/settings_page.dart';
import 'package:memor/theme/theme.dart';
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

  List<DrawerTile> renderMemoSpaces(BuildContext context) {
    return memoSpaces
        .map((memoSpace) => DrawerTile(
              title: memoSpace.name,
              trailing: _DeleteButton(
                onTap: () => onDelete!(memoSpace),
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
        width: 280,
        backgroundColor: drawerColor,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(), // Clean flat edge
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Scrollable memo spaces list
            Expanded(
              child: ListView(
                physics: const NativeScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: EdgeInsets.zero,
                children: renderMemoSpaces(context),
              ),
            ),
            // Fixed bottom section
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
            ),
            const SizedBox(height: 20),
          ],
        ));
  }
}

/// Delete button with red hover hint
class _DeleteButton extends StatefulWidget {
  final VoidCallback onTap;

  const _DeleteButton({required this.onTap});

  @override
  State<_DeleteButton> createState() => _DeleteButtonState();
}

class _DeleteButtonState extends State<_DeleteButton> {
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
          scale: _isPressed ? 0.85 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _isHovered
                  ? Colors.red.withOpacity(0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 150),
                style: TextStyle(
                  color: _isHovered
                      ? Colors.red.shade400
                      : colorScheme.inversePrimary.withOpacity(0.6),
                ),
                child: Icon(
                  Icons.delete_outline,
                  size: 16,
                  color: _isHovered
                      ? Colors.red.shade400
                      : colorScheme.inversePrimary.withOpacity(0.6),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
