// screens/live_screen.dart — Premium redesign
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config.dart';
import '../models/live_match.dart';
import '../services/api_service.dart';
import 'player_screen.dart';

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});
  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  List<LiveMatch> _matches = [];
  List<String> _leagues   = [];
  String _selectedLeague  = '';
  String _selectedStatus  = '';
  bool _loading  = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.getLive(
        league: _selectedLeague.isEmpty ? null : _selectedLeague,
        status: _selectedStatus.isEmpty ? null : _selectedStatus,
      );
      setState(() {
        _matches = res['matches'];
        _leagues = List<String>.from(res['available_filters']['leagues'] ?? []);
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0F),
    body: SafeArea(child: Column(children: [
      _header(),
      _filters(),
      Expanded(child: _loading ? _shimmer() : _error != null ? _errorView() : _body()),
    ])),
  );

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
    child: Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Live Sports', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
        Row(children: [
          Container(width: 8, height: 8,
              decoration: const BoxDecoration(color: Color(0xFFE63946), shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('${_matches.where((m) => m.isLive).length} LIVE now',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFE63946), fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          Text('· ${_matches.where((m) => !m.isLive).length} Upcoming',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF7F8EA3))),
        ]),
      ]),
      const Spacer(),
      GestureDetector(
        onTap: _load,
        child: Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFF1A1A2E), shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
          child: const Icon(Icons.refresh_rounded, color: Color(0xFF7F8EA3), size: 20)),
      ),
    ]),
  );

  Widget _filters() => SizedBox(
    height: 44,
    child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _Chip(label: 'সব', active: _selectedLeague.isEmpty && _selectedStatus.isEmpty,
            onTap: () { setState(() { _selectedLeague = ''; _selectedStatus = ''; }); _load(); }),
        _Chip(label: '🔴 LIVE', active: _selectedStatus == 'LIVE', isLive: true,
            onTap: () { setState(() { _selectedStatus = _selectedStatus == 'LIVE' ? '' : 'LIVE'; _selectedLeague = ''; }); _load(); }),
        ..._leagues.map((l) => _Chip(label: l, active: _selectedLeague == l,
            onTap: () { setState(() { _selectedLeague = _selectedLeague == l ? '' : l; _selectedStatus = ''; }); _load(); })),
      ],
    ),
  );

  Widget _body() {
    if (_matches.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.sports_score_outlined, color: Color(0xFF7F8EA3), size: 72),
      const SizedBox(height: 16),
      Text('কোনো match নেই', style: GoogleFonts.inter(color: const Color(0xFF7F8EA3), fontSize: 16)),
    ]));

    // Separate live and upcoming
    final live     = _matches.where((m) => m.isLive).toList();
    final upcoming = _matches.where((m) => !m.isLive).toList();

    return RefreshIndicator(
      color: const Color(0xFFE63946), backgroundColor: const Color(0xFF1A1A2E), onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        if (live.isNotEmpty) ...[
          _SectionLabel('🔴 LIVE NOW', live.length),
          ...live.map((m) => _MatchCard(match: m)),
          const SizedBox(height: 8),
        ],
        if (upcoming.isNotEmpty) ...[
          _SectionLabel('⏰ UPCOMING', upcoming.length),
          ...upcoming.map((m) => _MatchCard(match: m)),
        ],
      ]),
    );
  }

  Widget _shimmer() => Shimmer.fromColors(
    baseColor: const Color(0xFF1A1A2E), highlightColor: const Color(0xFF252540),
    child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: 5,
      itemBuilder: (_, __) => Container(height: 110, margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
    ),
  );

  Widget _errorView() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.wifi_off_rounded, color: Color(0xFFE63946), size: 72),
    const SizedBox(height: 16),
    Text('Connection Error', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
    const SizedBox(height: 8),
    Text('Internet check করুন', style: GoogleFonts.inter(color: const Color(0xFF7F8EA3))),
    const SizedBox(height: 24),
    ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE63946), foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      icon: const Icon(Icons.refresh), label: const Text('Retry'), onPressed: _load),
  ]));
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final int count;
  const _SectionLabel(this.label, this.count);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 4),
    child: Row(children: [
      Text(label, style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
      const SizedBox(width: 8),
      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(10)),
        child: Text('$count', style: GoogleFonts.inter(color: const Color(0xFF7F8EA3), fontSize: 11))),
    ]),
  );
}

class _MatchCard extends StatelessWidget {
  final LiveMatch match;
  const _MatchCard({required this.match});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      if (match.streamUrls.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stream নেই'), backgroundColor: Color(0xFFE63946)));
        return;
      }
      Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(
        title: match.matchTitle, streamUrls: match.streamUrls, isMatch: true,
      )));
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF13131F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: match.isLive
            ? const Color(0xFFE63946).withValues(alpha: 0.35)
            : Colors.white.withValues(alpha: 0.06)),
        boxShadow: match.isLive ? [BoxShadow(
          color: const Color(0xFFE63946).withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 4))] : [],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Top row
          Row(children: [
            // Status badge
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: match.isLive ? const Color(0xFFE63946) : const Color(0xFF1E2040),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (match.isLive) ...[
                  Container(width: 5, height: 5,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                ],
                Text(match.isLive ? 'LIVE' : match.startTimeBd.isNotEmpty ? match.startTimeBd : 'Soon',
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(match.league,
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF7F8EA3), fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis)),
            // Play icon
            Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: match.isLive ? const Color(0xFFE63946) : const Color(0xFF1E2040),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18)),
          ]),
          const SizedBox(height: 16),
          // Teams row
          Row(children: [
            Expanded(child: _TeamCol(name: match.team1, logo: match.team1Logo)),
            Column(children: [
              Text('VS', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900,
                  color: match.isLive ? const Color(0xFFE63946) : const Color(0xFF7F8EA3), letterSpacing: 1)),
            ]),
            Expanded(child: _TeamCol(name: match.team2, logo: match.team2Logo)),
          ]),
        ]),
      ),
    ),
  );
}

class _TeamCol extends StatelessWidget {
  final String name, logo;
  const _TeamCol({required this.name, required this.logo});

  @override
  Widget build(BuildContext context) => Column(children: [
    logo.isNotEmpty
        ? CachedNetworkImage(imageUrl: logo, width: 44, height: 44, fit: BoxFit.contain,
            placeholder: (_, __) => const Icon(Icons.shield, color: Color(0xFF7F8EA3), size: 40),
            errorWidget: (_, __, ___) => const Icon(Icons.shield, color: Color(0xFF7F8EA3), size: 40))
        : const Icon(Icons.shield, color: Color(0xFF7F8EA3), size: 40),
    const SizedBox(height: 8),
    Text(name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white, height: 1.2)),
  ]);
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final bool isLive;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.active, required this.onTap, this.isLive = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE63946) : const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? const Color(0xFFE63946) : Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          color: active ? Colors.white : const Color(0xFF7F8EA3))),
    ),
  );
}
