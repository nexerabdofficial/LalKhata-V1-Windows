import 'package:flutter/material.dart';

class BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const BottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: SizedBox(
        height: 65,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [

            // Records
            IconButton(
              tooltip: "Records",
              icon: Icon(
                Icons.folder_copy,
                color: selectedIndex == 0
                    ? Theme.of(context).primaryColor
                    : Colors.grey,
              ),
              onPressed: () => onTap(0),
            ),

            const SizedBox(width: 40),

            // Settings
            IconButton(
              tooltip: "Settings",
              icon: Icon(
                Icons.settings,
                color: selectedIndex == 1
                    ? Theme.of(context).primaryColor
                    : Colors.grey,
              ),
              onPressed: () => onTap(1),
            ),

          ],
        ),
      ),
    );
  }
}