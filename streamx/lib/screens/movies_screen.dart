// screens/movies_screen.dart — Ultra-premium redesign
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../services/api_service.dart';
import 'movie_detail_screen.dart';

class MoviesScreen extends StatefulWidget {
  const MoviesScreen({super.key});
  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> with SingleTickerProviderStateMixin {
  List<Movie> _movies   = [];
  List<Movie> _featured = [];
  List<String> _categories = [];
  List<String> _languages  = [];
  String _category = '';
  String _language  = '';
  String _search    = '';
  int _page = 1, _totalPages = 1;
  bool _loading = true, _loadingMore = false;
  String? _error;
  int _featuredIdx = 0;
  late AnimationController _bannerTimer;
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _pageCtrl   = PageController();

  static const _bg     = Color(0xFF080810);
  static const _card   = Color(0xFF12121E);
  static const _card2  = Color(0xFF1C1C2E);
  static const _red    = Color(0xFFE63946);
  static const _gray   = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _bannerTimer = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && _featured.length > 1) {
          _bannerTimer.reset();
          _bannerTimer.forward();
          final next = (_featuredIdx + 1) % _featured.length;
          _pageCtrl.animateToPage(next,
              duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
        }
      });
    _load();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose(); _scrollCtrl.dispose();
    _pageCtrl.dispose(); _bannerTimer.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 500
        && !_loadingMore && _page < _totalPages) _loadMore();
  }

  Future<void> _load({bool reset = true}) async {
    if (reset) setState(() { _loading = true; _page = 1; _movies = []; _error = null; });
    try {
      final res = await ApiService.getMovies(
        page: _page, search: _search.isEmpty ? null : _search,
        category: _category.isEmpty ? null : _category,
        language: _language.isEmpty ? null : _language,
        sort: 'newest',
      );
      setState(() {
        _movies     = res['movies'];
        _totalPages = res['total_pages'];
        _categories = List<String>.from(res['available_filters']['categories'] ?? []);
        _languages  = List<String>.from(res['available_filters']['languages']  ?? []);
        _featured   = _movies.length > 5 ? _movies.sublist(0, 5) : _movies;
        _loading    = false;
      });
      if (_featured.length > 1) _bannerTimer.forward();
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadMore() async {
    setState(() { _loadingMore = true; _page++; });
    try {
      final res = await ApiService.getMovies(page: _page,
          category: _category.isEmpty ? null : _category,
          language: _language.isEmpty ? null : _language);
      setState(() { _movies.addAll(res['movies']); _loadingMore = false; });
    } catch (_) { setState(() { _page--; _loadingMore = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
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

  Widget _topBar() => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [_bg, _bg.withOpacity(0)],
      ),
    ),
    child: Row(children: [
      // Logo
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE63946), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('ST', style: TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
              ),
            ),
          ),
        ),
        ),
      ),
      const SizedBox(width: 10),
      Text('StreamX', style: GoogleFonts.inter(
          color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
      const Spacer(),
      // Search
      GestureDetector(
        onTap: _showSearch,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _card2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: const Icon(Icons.search_rounded, color: Color(0xFF9CA3AF), size: 20),
        ),
      ),
      const SizedBox(width: 8),
      // Filter
      GestureDetector(
        onTap: _showFilters,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _category.isNotEmpty || _language.isNotEmpty ? _red.withOpacity(0.2) : _card2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _category.isNotEmpty || _language.isNotEmpty
                    ? _red.withOpacity(0.5)
                    : Colors.white.withOpacity(0.08)),
          ),
          child: Icon(Icons.tune_rounded,
              color: _category.isNotEmpty || _language.isNotEmpty ? _red : const Color(0xFF9CA3AF),
              size: 20),
        ),
      ),
    ]),
  );

  Widget _body() => CustomScrollView(
    controller: _scrollCtrl,
    physics: const BouncingScrollPhysics(),
    slivers: [
      // Hero Banner
      if (_featured.isNotEmpty) SliverToBoxAdapter(child: _heroCarousel()),
      // Category tabs
      SliverPersistentHeader(
        pinned: true,
        delegate: _StickyTabsDelegate(
          child: _categoryTabs(),
        ),
      ),
      // Trending row
      SliverToBoxAdapter(child: _sectionLabel('🔥 Trending', onTap: null)),
      SliverToBoxAdapter(child: _trendingRow()),
      // All movies label
      SliverToBoxAdapter(child: _sectionLabel('🎬 All Movies', count: _movies.length)),
      // Grid
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (_, i) => i >= _movies.length ? _shimmerCard() : _MovieCard(movie: _movies[i]),
            childCount: _movies.length + (_loadingMore ? 3 : 0),
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, childAspectRatio: 0.56,
              crossAxisSpacing: 8, mainAxisSpacing: 10),
        ),
      ),
    ],
  );

  Widget _heroCarousel() => SizedBox(
    height: 240,
    child: PageView.builder(
      controller: _pageCtrl,
      itemCount: _featured.length,
      onPageChanged: (i) => setState(() => _featuredIdx = i),
      itemBuilder: (_, i) {
        final m = _featured[i];
        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: m))),
          child: Stack(children: [
            // Image
            m.posterUrl.isNotEmpty
                ? CachedNetworkImage(imageUrl: m.posterUrl, fit: BoxFit.cover,
                    width: double.infinity, height: 240,
                    placeholder: (_, __) => Container(color: _card),
                    errorWidget: (_, __, ___) => Container(color: _card))
                : Container(color: _card, width: double.infinity, height: 240),
            // Gradient
            Container(
              width: double.infinity, height: 240,
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Color(0x22000000), Color(0xCC000000), Color(0xFF080810)],
                    stops: [0.0, 0.7, 1.0]),
              ),
            ),
            // Info
            Positioned(bottom: 16, left: 16, right: 16,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Badges
                Row(children: [
                  _PillBadge(m.language, _red),
                  const SizedBox(width: 6),
                  if (m.quality.isNotEmpty) _PillBadge(m.quality, const Color(0xFF7C3AED)),
                ]),
                const SizedBox(height: 6),
                Text(m.title, style: GoogleFonts.inter(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800,
                    shadows: [const Shadow(blurRadius: 8)]),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ]),
            ),
            // Page dots
            Positioned(bottom: 8, right: 16,
              child: Row(
                children: List.generate(_featured.length, (di) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(left: 4),
                  width: di == _featuredIdx ? 18 : 5, height: 4,
                  decoration: BoxDecoration(
                    color: di == _featuredIdx ? _red : Colors.white38,
                    borderRadius: BorderRadius.circular(3)),
                )),
              ),
            ),
          ]),
        );
      },
    ),
  );

  Widget _categoryTabs() => Container(
    height: 44,
    color: _bg,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      children: [
        _CatChip(label: 'সব', active: _category.isEmpty,
            color: _red, onTap: () { setState(() => _category = ''); _load(); }),
        ..._categories.take(10).map((c) => _CatChip(label: c, active: _category == c,
            color: _red, onTap: () { setState(() => _category = _category == c ? '' : c); _load(); })),
      ],
    ),
  );

  Widget _trendingRow() => SizedBox(
    height: 195,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: _movies.take(10).length,
      itemBuilder: (_, i) => _TrendingCard(movie: _movies[i], rank: i + 1),
    ),
  );

  Widget _sectionLabel(String title, {int? count, VoidCallback? onTap}) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
    child: Row(children: [
      Text(title, style: GoogleFonts.inter(
          color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
      const Spacer(),
      if (count != null) Text('$count+', style: GoogleFonts.inter(color: _gray, fontSize: 12)),
    ]),
  );

  Widget _shimmer() => Shimmer.fromColors(
    baseColor: _card, highlightColor: _card2,
    child: ListView(children: [
      Container(height: 240, color: Colors.white),
      const SizedBox(height: 8),
      Container(height: 44, margin: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22))),
      const SizedBox(height: 20),
      GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, childAspectRatio: 0.56, crossAxisSpacing: 8, mainAxisSpacing: 10),
        itemCount: 9,
        itemBuilder: (_, __) => Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
      ),
    ]),
  );

  Widget _shimmerCard() => Shimmer.fromColors(
    baseColor: _card, highlightColor: _card2,
    child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
  );

  Widget _errorView() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.wifi_off_rounded, color: _red, size: 64),
    const SizedBox(height: 16),
    Text('Connection Error', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
    const SizedBox(height: 8),
    Text('ইন্টারনেট connection check করুন', style: GoogleFonts.inter(color: _gray, fontSize: 13)),
    const SizedBox(height: 24),
    ElevatedButton.icon(
      style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
      icon: const Icon(Icons.refresh_rounded), label: Text('Retry', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      onPressed: _load,
    ),
  ]));

  void _showSearch() async {
    final res = await showSearch(context: context, delegate: _MovieSearch(_search));
    if (res != null && res != _search) { setState(() => _search = res); _load(); }
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        categories: _categories, languages: _languages,
        selectedCat: _category, selectedLang: _language,
        onApply: (cat, lang) {
          setState(() { _category = cat; _language = lang; });
          _load();
        },
      ),
    );
  }
}

// ── Trending Card (horizontal row) ───────────────────────────
class _TrendingCard extends StatelessWidget {
  final Movie movie;
  final int rank;
  const _TrendingCard({required this.movie, required this.rank});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie))),
    child: Container(
      width: 115,
      margin: const EdgeInsets.only(right: 10),
      child: Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: movie.posterUrl.isNotEmpty
              ? CachedNetworkImage(imageUrl: movie.posterUrl, fit: BoxFit.cover,
                  width: 115, height: 185,
                  placeholder: (_, __) => Container(width: 115, height: 185, color: const Color(0xFF12121E)),
                  errorWidget: (_, __, ___) => Container(width: 115, height: 185, color: const Color(0xFF12121E)))
              : Container(width: 115, height: 185, color: const Color(0xFF12121E)),
        ),
        // Bottom gradient
        Positioned(bottom: 0, left: 0, right: 0,
          child: Container(height: 80,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xEE000000)]),
            ),
          ),
        ),
        // Rank
        Positioned(bottom: 6, left: 8,
          child: Text('$rank', style: GoogleFonts.inter(
              color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900,
              foreground: Paint()..shader = const LinearGradient(
                colors: [Color(0xFFE63946), Color(0xFFFF6B6B)],
              ).createShader(const Rect.fromLTWH(0, 0, 40, 40)))),
        ),
        // Language badge
        if (movie.language.isNotEmpty) Positioned(top: 8, right: 8,
          child: _PillBadge(movie.language.length > 4 ? movie.language.substring(0, 4) : movie.language,
              const Color(0xFFE63946)),
        ),
      ]),
    ),
  );
}

// ── Movie Grid Card ─────────────────────────────────────────
class _MovieCard extends StatelessWidget {
  final Movie movie;
  const _MovieCard({required this.movie});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie))),
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(fit: StackFit.expand, children: [
          movie.posterUrl.isNotEmpty
              ? CachedNetworkImage(imageUrl: movie.posterUrl, fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: const Color(0xFF12121E)),
                  errorWidget: (_, __, ___) => _placeholder())
              : _placeholder(),
          // Gradient
          Positioned(bottom: 0, left: 0, right: 0,
            child: Container(height: 80,
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xF0000000)]),
              ),
            ),
          ),
          // Lang badge
          if (movie.language.isNotEmpty) Positioned(top: 6, left: 6,
            child: _PillBadge(
                movie.language.length > 5 ? movie.language.substring(0, 5) : movie.language,
                const Color(0xFF7C3AED)),
          ),
          // Title
          Positioned(bottom: 6, left: 6, right: 6,
            child: Text(movie.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 10.5,
                    fontWeight: FontWeight.w600, height: 1.3)),
          ),
        ]),
      ),
    ),
  );

  Widget _placeholder() => Container(
    color: const Color(0xFF12121E),
    child: const Center(child: Icon(Icons.movie_outlined, color: Color(0xFF374151), size: 32)),
  );
}

// ── Pill Badge ─────────────────────────────────────────────
class _PillBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _PillBadge(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
        color: color.withOpacity(0.9), borderRadius: BorderRadius.circular(5)),
    child: Text(text, style: GoogleFonts.inter(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
  );
}

// ── Cat Chip ───────────────────────────────────────────────
class _CatChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _CatChip({required this.label, required this.active, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        gradient: active ? LinearGradient(colors: [color, color.withOpacity(0.7)]) : null,
        color: active ? null : const Color(0xFF1C1C2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? Colors.transparent : Colors.white.withOpacity(0.07)),
        boxShadow: active ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8)] : [],
      ),
      child: Text(label, style: GoogleFonts.inter(
          fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          color: active ? Colors.white : const Color(0xFF6B7280))),
    ),
  );
}

// ── Sticky Header Delegate ─────────────────────────────────
class _StickyTabsDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  const _StickyTabsDelegate({required this.child});
  @override double get minExtent => 44;
  @override double get maxExtent => 44;
  @override Widget build(_, __, ___) => child;
  @override bool shouldRebuild(_) => true;
}

// ── Filter Bottom Sheet ────────────────────────────────────
class _FilterSheet extends StatefulWidget {
  final List<String> categories, languages;
  final String selectedCat, selectedLang;
  final void Function(String cat, String lang) onApply;
  const _FilterSheet({required this.categories, required this.languages,
      required this.selectedCat, required this.selectedLang, required this.onApply});
  @override State<_FilterSheet> createState() => _FilterSheetState();
}
class _FilterSheetState extends State<_FilterSheet> {
  late String _cat, _lang;
  @override
  void initState() {
    super.initState();
    _cat = widget.selectedCat; _lang = widget.selectedLang;
  }
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Color(0xFF12121E),
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: Container(width: 36, height: 4,
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
      const SizedBox(height: 16),
      Row(children: [
        Text('Filters', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        const Spacer(),
        TextButton(onPressed: () { setState(() { _cat = ''; _lang = ''; }); },
            child: const Text('Reset', style: TextStyle(color: Color(0xFFE63946)))),
      ]),
      const SizedBox(height: 12),
      Text('Language', style: GoogleFonts.inter(color: const Color(0xFF9CA3AF), fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _CatChip(label: 'All', active: _lang.isEmpty, color: const Color(0xFFE63946), onTap: () => setState(() => _lang = '')),
        ...widget.languages.map((l) => _CatChip(label: l, active: _lang == l,
            color: const Color(0xFFE63946), onTap: () => setState(() => _lang = _lang == l ? '' : l))),
      ]),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE63946), foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () { Navigator.pop(context); widget.onApply(_cat, _lang); },
        child: Text('Apply Filters', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
      )),
    ]),
  );
}

// ── Search Delegate ───────────────────────────────────────
class _MovieSearch extends SearchDelegate<String> {
  final String initial;
  _MovieSearch(this.initial);
  @override String get searchFieldLabel => 'Movie খুঁজুন...';
  @override ThemeData appBarTheme(BuildContext context) => Theme.of(context).copyWith(
    appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF12121E)),
    inputDecorationTheme: InputDecorationTheme(
        hintStyle: GoogleFonts.inter(color: const Color(0xFF6B7280))),
  );
  @override List<Widget> buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear, color: Color(0xFF6B7280)), onPressed: () { query = ''; }),
  ];
  @override Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back, color: Colors.white),
    onPressed: () => close(context, initial),
  );
  @override Widget buildResults(BuildContext context) { close(context, query); return const SizedBox(); }
  @override Widget buildSuggestions(BuildContext context) => Container(color: const Color(0xFF080810));
}
