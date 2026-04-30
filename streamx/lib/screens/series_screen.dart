// screens/series_screen.dart — Web Series listing (Loklok style)
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../services/api_service.dart';
import 'series_detail_screen.dart';

class SeriesScreen extends StatefulWidget {
  const SeriesScreen({super.key});
  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  List<Movie> _series = [];
  List<String> _categories = [];
  List<String> _languages  = [];
  String _category = '';
  String _language  = '';
  String _search    = '';
  int _page = 1, _totalPages = 1;
  bool _loading = true, _loadingMore = false;
  String? _error;
  final _scrollCtrl = ScrollController();

  static const _bg   = Color(0xFF0A0A0F);
  static const _card = Color(0xFF1A1A2E);
  static const _red  = Color(0xFFE63946);
  static const _gray = Color(0xFF7F8EA3);

  @override
  void initState() {
    super.initState();
    _load();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 400
          && !_loadingMore && _page < _totalPages) _loadMore();
    });
  }

  @override
  void dispose() { _scrollCtrl.dispose(); super.dispose(); }

  Future<void> _load({bool reset = true}) async {
    if (reset) setState(() { _loading = true; _page = 1; _series = []; _error = null; });
    try {
      final res = await ApiService.getSeries(
        page: _page,
        search: _search.isEmpty ? null : _search,
        category: _category.isEmpty ? null : _category,
        language: _language.isEmpty ? null : _language,
      );
      setState(() {
        _series     = res['series'];
        _totalPages = res['total_pages'];
        _categories = List<String>.from(res['available_filters']['categories'] ?? []);
        _languages  = List<String>.from(res['available_filters']['languages']  ?? []);
        _loading    = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadMore() async {
    setState(() { _loadingMore = true; _page++; });
    try {
      final res = await ApiService.getSeries(page: _page,
        category: _category.isEmpty ? null : _category,
        language: _language.isEmpty ? null : _language);
      setState(() { _series.addAll(res['series']); _loadingMore = false; });
    } catch (_) { setState(() { _page--; _loadingMore = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(children: [
          _topBar(),
          Expanded(
            child: _loading ? _shimmer()
              : _error != null ? _errorView()
              : _body(),
          ),
        ]),
      ),
    );
  }

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: Row(children: [
      Expanded(
        child: GestureDetector(
          onTap: _showSearch,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: _card, borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(children: [
              const Icon(Icons.search, color: _gray, size: 18),
              const SizedBox(width: 8),
              Text(_search.isEmpty ? 'Web Series খুঁজুন...' : _search,
                  style: GoogleFonts.inter(color: _gray, fontSize: 14)),
            ]),
          ),
        ),
      ),
      const SizedBox(width: 10),
      GestureDetector(
        onTap: _showFilters,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _card, shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: const Icon(Icons.tune_rounded, color: _gray, size: 20),
        ),
      ),
    ]),
  );

  Widget _body() => CustomScrollView(
    controller: _scrollCtrl,
    slivers: [
      // Category chips
      SliverToBoxAdapter(child: _categoryChips()),
      // Header
      SliverToBoxAdapter(child: _sectionHeader()),
      // Grid
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (_, i) {
              if (i >= _series.length) return _shimmerCard();
              return _SeriesCard(series: _series[i]);
            },
            childCount: _series.length + (_loadingMore ? 3 : 0),
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, childAspectRatio: 0.56,
            crossAxisSpacing: 8, mainAxisSpacing: 8,
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ],
  );

  Widget _categoryChips() => SizedBox(
    height: 40,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _Chip(label: 'সব', active: _category.isEmpty,
            onTap: () { setState(() => _category = ''); _load(); }),
        ..._categories.take(8).map((c) => _Chip(label: c, active: _category == c,
            onTap: () { setState(() => _category = _category == c ? '' : c); _load(); })),
      ],
    ),
  );

  Widget _sectionHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
    child: Row(children: [
      const Text('📺', style: TextStyle(fontSize: 16)),
      const SizedBox(width: 6),
      Text('Web Series', style: GoogleFonts.inter(
          color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
      const Spacer(),
      Text('${_series.length}+', style: GoogleFonts.inter(color: _gray, fontSize: 12)),
    ]),
  );

  Widget _shimmer() => Shimmer.fromColors(
    baseColor: _card, highlightColor: const Color(0xFF252540),
    child: GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, childAspectRatio: 0.56, crossAxisSpacing: 8, mainAxisSpacing: 8),
      itemCount: 9,
      itemBuilder: (_, __) => Container(decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(10))),
    ),
  );

  Widget _shimmerCard() => Shimmer.fromColors(
    baseColor: _card, highlightColor: const Color(0xFF252540),
    child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10))),
  );

  Widget _errorView() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.wifi_off, color: _red, size: 64),
    const SizedBox(height: 16),
    Text('Connection Error', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
    const SizedBox(height: 24),
    ElevatedButton.icon(
      style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      icon: const Icon(Icons.refresh), label: const Text('Retry'), onPressed: _load,
    ),
  ]));

  void _showSearch() async {
    final ctrl = TextEditingController(text: _search);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        title: Text('Search', style: GoogleFonts.inter(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Series name...',
            hintStyle: const TextStyle(color: _gray),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.white24)),
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text),
              child: const Text('Search', style: TextStyle(color: _red))),
        ],
      ),
    );
    if (result != null && result != _search) { setState(() => _search = result); _load(); }
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151520),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Filter', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const Spacer(),
            TextButton(onPressed: () { setState(() { _category = ''; _language = ''; }); Navigator.pop(context); _load(); },
                child: const Text('Reset', style: TextStyle(color: _red))),
          ]),
          const SizedBox(height: 12),
          Text('Language', style: GoogleFonts.inter(color: _gray, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _Chip(label: 'সব', active: _language.isEmpty, onTap: () => setS(() => _language = '')),
            ..._languages.map((l) => _Chip(label: l, active: _language == l,
                onTap: () => setS(() => _language = _language == l ? '' : l))),
          ]),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () { Navigator.pop(context); _load(); },
            child: Text('Apply', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          )),
        ]),
      )),
    );
  }
}

// ── Series Card ──────────────────────────────────────────
class _SeriesCard extends StatelessWidget {
  final Movie series;
  const _SeriesCard({required this.series});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => SeriesDetailScreen(series: series))),
    child: Stack(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: series.posterUrl.isNotEmpty
            ? CachedNetworkImage(imageUrl: series.posterUrl, fit: BoxFit.cover,
                width: double.infinity, height: double.infinity,
                placeholder: (_, __) => Container(color: const Color(0xFF1A1A2E)),
                errorWidget: (_, __, ___) => _placeholder())
            : _placeholder(),
      ),
      // Gradient
      Positioned(bottom: 0, left: 0, right: 0,
        child: Container(height: 70, decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0xDD000000)]),
        )),
      ),
      // TV badge
      Positioned(top: 6, left: 6,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(color: const Color(0xFF6C63FF), borderRadius: BorderRadius.circular(4)),
          child: Text('TV', style: GoogleFonts.inter(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
        ),
      ),
      // Seasons badge
      if (series.totalSeasons > 0) Positioned(top: 6, right: 6,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
          child: Text('S${series.totalSeasons}', style: GoogleFonts.inter(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w700)),
        ),
      ),
      // Title
      Positioned(bottom: 6, left: 6, right: 6,
        child: Text(series.title, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600, height: 1.3)),
      ),
    ]),
  );

  Widget _placeholder() => Container(
    color: const Color(0xFF1A1A2E),
    child: const Center(child: Icon(Icons.tv, color: Color(0xFF7F8EA3), size: 32)),
  );
}

// ── Category Chip ────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 8, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF6C63FF) : const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? const Color(0xFF6C63FF) : Colors.white.withOpacity(0.08)),
      ),
      child: Text(label, style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          color: active ? Colors.white : const Color(0xFF7F8EA3))),
    ),
  );
}
