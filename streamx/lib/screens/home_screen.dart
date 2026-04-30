// screens/home_screen.dart — 4-tab bottom nav with Series
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'live_screen.dart';
import 'movies_screen.dart';
import 'channels_screen.dart';
import 'series_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _idx = 0;

  final _screens = const [
    MoviesScreen(),
    SeriesScreen(),
    LiveScreen(),
    ChannelsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: IndexedStack(index: _idx, children: _screens),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.07))),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 24, offset: const Offset(0, -8)),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 62,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.movie_outlined,
                activeIcon: Icons.movie_rounded,
                label: 'Movies',
                active: _idx == 0,
                onTap: () => setState(() => _idx = 0),
              ),
              _NavItem(
                icon: Icons.tv_outlined,
                activeIcon: Icons.tv_rounded,
                label: 'Series',
                active: _idx == 1,
                onTap: () => setState(() => _idx = 1),
                accentColor: const Color(0xFF6C63FF),
              ),
              _NavItem(
                icon: Icons.sports_outlined,
                activeIcon: Icons.sports,
                label: 'Live',
                active: _idx == 2,
                onTap: () => setState(() => _idx = 2),
                showBadge: true,
              ),
              _NavItem(
                icon: Icons.cast_outlined,
                activeIcon: Icons.cast_rounded,
                label: 'Channels',
                active: _idx == 3,
                onTap: () => setState(() => _idx = 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final bool active;
  final bool showBadge;
  final Color accentColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
    this.showBadge  = false,
    this.accentColor = const Color(0xFFE63946),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 80,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Stack(clipBehavior: Clip.none, children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                active ? activeIcon : icon,
                key: ValueKey(active),
                color: active ? accentColor : const Color(0xFF4A5568),
                size: 24,
              ),
            ),
            if (showBadge) Positioned(
              top: -4, right: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFE63946),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('LIVE', style: GoogleFonts.inter(
                    fontSize: 7, color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            color: active ? accentColor : const Color(0xFF4A5568),
          )),
          const SizedBox(height: 2),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 2, width: active ? 18 : 0,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ]),
      ),
    );
  }
}
