// screens/channels_screen.dart — Premium redesign
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config.dart';
import '../models/channel.dart';
import '../services/api_service.dart';
import 'player_screen.dart';

class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});
  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  List<Channel> _channels = [];
  List<String>  _groups   = [];
  String _selectedGroup   = '';
  String _search          = '';
  bool   _loading         = true;
  String? _error;
  final _searchCtrl = TextEditingController();

  static const _groupMeta = {
    'SPORTS':    (icon: Icons.sports_soccer_rounded,  color: Color(0xFF10B981)),
    'NEWS':      (icon: Icons.newspaper_rounded,       color: Color(0xFF3B82F6)),
    'BANGLA TV': (icon: Icons.live_tv_rounded,         color: Color(0xFFE63946)),
    'MOVIES':    (icon: Icons.movie_rounded,           color: Color(0xFFF59E0B)),
    'MUSIC':     (icon: Icons.music_note_rounded,      color: Color(0xFFA855F7)),
    'KIDS':      (icon: Icons.child_care_rounded,      color: Color(0xFFEC4899)),
    'OTHERS':    (icon: Icons.tv_rounded,              color: Color(0xFF6B7280)),
  };

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.getChannels(
        group:  _selectedGroup.isEmpty ? null : _selectedGroup,
        search: _search.isEmpty        ? null : _search,
        limit:  300,
      );
      setState(() {
        _channels = res['channels'];
        _groups   = List<String>.from(res['available_filters']['groups'] ?? []);
        _loading  = false;
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
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
    child: Column(children: [
      Row(children: [
        Text('TV Channels', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
        const Spacer(),
        if (!_loading) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(20)),
          child: Text('${_channels.length} ch', style: GoogleFonts.inter(color: const Color(0xFF7F8EA3), fontSize: 11))),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _load,
          child: Container(padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: const Color(0xFF1A1A2E), shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
            child: const Icon(Icons.refresh_rounded, color: Color(0xFF7F8EA3), size: 18)),
        ),
      ]),
      const SizedBox(height: 12),
      // Search bar
      Container(
        decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07))),
        child: TextField(
          controller: _searchCtrl,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Channel খুঁজুন...',
            hintStyle: GoogleFonts.inter(color: const Color(0xFF7F8EA3), fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: Color(0xFF7F8EA3), size: 20),
            suffixIcon: _search.isNotEmpty
                ? IconButton(icon: const Icon(Icons.clear, color: Color(0xFF7F8EA3), size: 18),
                    onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); _load(); })
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          ),
          onSubmitted: (v) { setState(() => _search = v); _load(); },
          onChanged: (v) { if (v.isEmpty) { setState(() => _search = ''); _load(); } },
        ),
      ),
    ]),
  );

  Widget _filters() => SizedBox(
    height: 44,
    child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _GroupChip(label: 'সব', icon: Icons.apps_rounded, color: const Color(0xFFE63946),
            active: _selectedGroup.isEmpty, onTap: () { setState(() => _selectedGroup = ''); _load(); }),
        ..._groups.map((g) {
          final meta = _groupMeta[g] ?? (icon: Icons.tv_rounded, color: const Color(0xFF6B7280));
          return _GroupChip(label: g, icon: meta.icon, color: meta.color,
              active: _selectedGroup == g,
              onTap: () { setState(() => _selectedGroup = _selectedGroup == g ? '' : g); _load(); });
        }),
      ],
    ),
  );

  Widget _body() {
    if (_channels.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.tv_off_rounded, color: Color(0xFF7F8EA3), size: 72),
      const SizedBox(height: 16),
      Text('কোনো channel নেই', style: GoogleFonts.inter(color: const Color(0xFF7F8EA3), fontSize: 16)),
    ]));

    if (_selectedGroup.isEmpty && _search.isEmpty) {
      final grouped = <String, List<Channel>>{};
      for (final c in _channels) {
        grouped.putIfAbsent(c.groupName, () => []).add(c);
      }
      return RefreshIndicator(
        color: const Color(0xFFE63946), backgroundColor: const Color(0xFF1A1A2E), onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
          ...grouped.entries.map((e) {
            final meta = _groupMeta[e.key] ?? (icon: Icons.tv_rounded, color: const Color(0xFF6B7280));
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Row(children: [
                Container(padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: meta.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Icon(meta.icon, color: meta.color, size: 16)),
                const SizedBox(width: 10),
                Text(e.key, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(width: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(10)),
                  child: Text('${e.value.length}', style: GoogleFonts.inter(color: const Color(0xFF7F8EA3), fontSize: 11))),
              ])),
              ...e.value.map((c) => _ChannelTile(channel: c)),
              const SizedBox(height: 4),
            ]);
          }),
        ]),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFFE63946), backgroundColor: const Color(0xFF1A1A2E), onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: _channels.length,
        itemBuilder: (_, i) => _ChannelTile(channel: _channels[i]),
      ),
    );
  }

  Widget _shimmer() => Shimmer.fromColors(
    baseColor: const Color(0xFF1A1A2E), highlightColor: const Color(0xFF252540),
    child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: 8,
      itemBuilder: (_, __) => Container(height: 70, margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14))),
    ),
  );

  Widget _errorView() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.wifi_off_rounded, color: Color(0xFFE63946), size: 72),
    const SizedBox(height: 16),
    Text('Connection Error', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
    const SizedBox(height: 24),
    ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE63946), foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      icon: const Icon(Icons.refresh), label: const Text('Retry'), onPressed: _load),
  ]));
}

class _ChannelTile extends StatelessWidget {
  final Channel channel;
  const _ChannelTile({required this.channel});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(
      title: channel.channelName, streamUrls: [channel.streamUrl], isMatch: false,
    ))),
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF13131F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(children: [
        // Logo
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(12)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: channel.logoUrl.isNotEmpty
                ? CachedNetworkImage(imageUrl: channel.logoUrl, fit: BoxFit.contain,
                    placeholder: (_, __) => const Icon(Icons.tv, color: Color(0xFF7F8EA3), size: 24),
                    errorWidget: (_, __, ___) => const Icon(Icons.tv, color: Color(0xFF7F8EA3), size: 24))
                : const Icon(Icons.tv, color: Color(0xFF7F8EA3), size: 24),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(channel.channelName,
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(channel.groupName,
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF7F8EA3))),
        ])),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(color: Color(0xFFE63946), shape: BoxShape.circle),
          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
        ),
      ]),
    ),
  );
}

class _GroupChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool active;
  final VoidCallback onTap;
  const _GroupChip({required this.label, required this.icon, required this.color, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? color : const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? color : Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: active ? Colors.white : color),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? Colors.white : const Color(0xFF7F8EA3))),
      ]),
    ),
  );
}
