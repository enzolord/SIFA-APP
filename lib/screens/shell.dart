import 'package:flutter/material.dart';

import 'history_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'scan_screen.dart';
import 'tips_screen.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

  static const _pages = <Widget>[
    HomeScreen(),
    HistoryScreen(),
    ScanScreen(),
    TipsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _index, children: _pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Historique'),
          NavigationDestination(icon: Icon(Icons.center_focus_strong_outlined), selectedIcon: Icon(Icons.center_focus_strong), label: 'Scanner'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Conseils'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}
