// screens/home_screen.dart — Premium glassmorphism bottom nav
import 'dart:ui';
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

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _idx = 0;
  late AnimationController _navAnim;

  final _screens = const [
    MoviesScreen(),
    SeriesScreen(),
    LiveScreen(),
    ChannelsScreen(),
  ];

  final _navItems = const [
    _NavData(Icons.movie_outlined,  Icons.movie_rounded,   'Movies',   Color(0xFFE63946)),
    _NavData(Icons.tv_outlined,     Icons.smart_display,   'Series',   Color(0xFF7C3AED)),
    _NavData(Icons.sports_outlined, Icons.sports,          'Live',     Color(0xFF00D4AA)),
    _NavData(Icons.cast_outlined,   Icons.cast_rounded,    'Channels', Color(0xFFFF9500)),
  ];

  @override
  void initState() {
    super.initState();
    _navAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void dispose() { _navAnim.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      extendBody: true,
      body: IndexedStack(index: _idx, children: _screens),
      bottomNavigationBar: _buildGlassNav(),
    );
  }

  Widget _buildGlassNav() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F1A).withOpacity(0.85),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08), width: 0.5)),
          ),
          child: SafeArea(
            child: SizedBox(
              height: 64,
              child: Row(
                children: List.generate(_navItems.length, (i) => Expanded(
                  child: _buildNavBtn(i),
                )),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavBtn(int i) {
    final item   = _navItems[i];
    final active = _idx == i;
    return GestureDetector(
      onTap: () => setState(() => _idx = i),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          // Icon with glow
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: active ? item.color.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: active ? [BoxShadow(color: item.color.withOpacity(0.3), blurRadius: 12)] : [],
            ),
            child: Stack(clipBehavior: Clip.none, children: [
              Icon(
                active ? item.activeIcon : item.icon,
                color: active ? item.color : const Color(0xFF4A5568),
                size: 22,
              ),
              if (i == 2) Positioned(top: -4, right: -6,
                child: Container(
                  width: 7, height: 7,
                  decoration: const BoxDecoration(color: Color(0xFFE63946), shape: BoxShape.circle),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: GoogleFonts.inter(
              fontSize: active ? 10.5 : 10,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              color: active ? item.color : const Color(0xFF4A5568),
            ),
            child: Text(item.label),
          ),
        ]),
      ),
    );
  }
}

class _NavData {
  final IconData icon, activeIcon;
  final String label;
  final Color color;
  const _NavData(this.icon, this.activeIcon, this.label, this.color);
}
