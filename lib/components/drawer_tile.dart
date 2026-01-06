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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: ListTile(
          dense: true,
          visualDensity: const VisualDensity(vertical: -3),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Text(
            widget.title,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.inversePrimary,
            ),
          ),
          trailing: Opacity(
            opacity: _isHovered ? 1.0 : 0.0,
            child: widget.trailing,
          ),
          onTap: widget.onTap,
        ),
      ),
    );
  }
}
