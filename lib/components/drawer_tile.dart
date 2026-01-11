import 'package:flutter/material.dart';

class DrawerTile extends StatefulWidget {
  final String title;
  final Widget trailing;
  final void Function()? onTap;

  const DrawerTile({
    super.key,
    required this.title,
    required this.trailing,
    required this.onTap,
  });

  @override
  State<DrawerTile> createState() => _DrawerTileState();
}

class _DrawerTileState extends State<DrawerTile> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 1),
      child: MouseRegion(
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
            decoration: BoxDecoration(
              color: _isPressed
                  ? colorScheme.inversePrimary.withOpacity(0.12)
                  : _isHovered
                      ? colorScheme.inversePrimary.withOpacity(0.06)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 100),
              scale: _isPressed ? 0.98 : 1.0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.inversePrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: _isHovered ? 1.0 : 0.0,
                      child: widget.trailing,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
