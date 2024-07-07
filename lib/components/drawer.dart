import 'package:flutter/material.dart';
import 'package:memor/components/drawer_tile.dart';

class MyDrawer extends StatelessWidget {
  const MyDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Theme.of(context).colorScheme.inversePrimary,
        shape: const BeveledRectangleBorder(),
        child: Column(
          children: [
            // dark mode toggle
            DrawerTile(
              title: 'Dark Mode',
              leading: const Icon(Icons.home),
              onTap: () => Navigator.pop(context),
            ),

            // list of memo spaces
            // each memo space has a delete button
          ],
        ));
  }
}
