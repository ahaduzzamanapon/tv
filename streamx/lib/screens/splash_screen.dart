// screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fade  = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
    _scale = Tween<double>(begin: 0.7, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _ctrl.forward();
    _init();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _init() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    await _checkVersion();
  }

  Future<void> _checkVersion() async {
    try {
      final res  = await ApiService.checkVersion();
      final data = res['data'] as Map<String, dynamic>? ?? {};
      final action = data['action'] ?? 'none';

      if (!mounted) return;

      if (action == 'block') {
        final status = data['status'] ?? '';
        if (status == 'maintenance') {
          _showDialog(
            title   : '🔧 Maintenance',
            message : data['message'] ?? 'সিস্টেম রক্ষণাবেক্ষণ চলছে।',
            canDismiss: false,
          );
        } else {
          // Force update
          _showUpdateDialog(
            message    : data['message'] ?? 'আপডেট প্রয়োজন।',
            downloadUrl: data['download_url'] ?? '',
            changelog  : List<String>.from(data['changelog'] ?? []),
            forced     : true,
          );
        }
      } else if (action == 'notify') {
        _showUpdateDialog(
          message    : data['update_message'] ?? 'নতুন version পাওয়া গেছে।',
          downloadUrl: data['download_url'] ?? '',
          changelog  : List<String>.from(data['changelog'] ?? []),
          forced     : false,
        );
      } else {
        _goHome();
      }
    } catch (_) {
      _goHome(); // API unavailable → app চলতে দাও
    }
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _showDialog({required String title, required String message, bool canDismiss = true}) {
    showDialog(
      context: context,
      barrierDismissible: canDismiss,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111C30),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Color(0xFF7F8EA3))),
        actions: canDismiss
            ? [TextButton(onPressed: _goHome, child: const Text('OK'))]
            : [],
      ),
    );
  }

  void _showUpdateDialog({
    required String message,
    required String downloadUrl,
    required List<String> changelog,
    required bool forced,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !forced,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111C30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE63946).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.system_update, color: Color(0xFFE63946)),
          ),
          const SizedBox(width: 12),
          Text(forced ? 'আপডেট প্রয়োজন!' : 'নতুন আপডেট',
              style: const TextStyle(color: Colors.white, fontSize: 18)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(message, style: const TextStyle(color: Color(0xFF7F8EA3))),
          if (changelog.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('নতুন কি আছে:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...changelog.take(5).map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                const Icon(Icons.check_circle, color: Color(0xFF34D399), size: 14),
                const SizedBox(width: 8),
                Expanded(child: Text(c, style: const TextStyle(color: Color(0xFF7F8EA3), fontSize: 13))),
              ]),
            )),
          ],
        ]),
        actions: [
          if (!forced)
            TextButton(
              onPressed: _goHome,
              child: const Text('পরে', style: TextStyle(color: Color(0xFF7F8EA3))),
            ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE63946),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.download, size: 18),
            label: const Text('ডাউনলোড করুন'),
            onPressed: () async {
              if (downloadUrl.isNotEmpty) {
                await launchUrl(Uri.parse(downloadUrl), mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [Color(0xFF1A0A0F), Color(0xFF0A0A0F)],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Column(mainAxisSize: MainAxisSize.min, children: [

                  // ── ST Logo ──
                  Container(
                    width: 140, height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE63946).withOpacity(0.35),
                          blurRadius: 50, spreadRadius: 5,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          width: 140, height: 140,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFFE63946), Color(0xFF7C3AED)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Center(
                            child: Text('ST', style: TextStyle(
                              color: Colors.white, fontSize: 48,
                              fontWeight: FontWeight.w900, letterSpacing: -2)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── App Name ──
                  Text(
                    'StreamX',
                    style: GoogleFonts.inter(
                      fontSize: 42, fontWeight: FontWeight.w900,
                      color: Colors.white, letterSpacing: -1.5,
                      shadows: [
                        Shadow(
                          color: const Color(0xFFE63946).withOpacity(0.5),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Movies • Live • TV Channels',
                    style: GoogleFonts.inter(
                      fontSize: 13, color: const Color(0xFF7F8EA3),
                      letterSpacing: 1.2, fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 70),

                  // ── Loader ──
                  SizedBox(
                    width: 32, height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: const Color(0xFFE63946).withOpacity(0.8),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
