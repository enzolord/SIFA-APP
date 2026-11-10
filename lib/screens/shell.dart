import 'package:flutter/material.dart';

import '../services/nav.dart';
import '../widgets/sifa_nav_bar.dart';
import 'community/community_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'scan_screen.dart';

class Shell extends StatelessWidget {
  const Shell({super.key});

  static const _pages = <Widget>[
    HomeScreen(),
    HistoryScreen(),
    ScanScreen(),
    CommunityScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AppNav.tab,
      builder: (context, i, _) => Scaffold(
        body: SafeArea(bottom: false, child: IndexedStack(index: i, children: _pages)),
        bottomNavigationBar: SifaNavBar(index: i, onSelect: AppNav.go),
      ),
    );
  }
}
