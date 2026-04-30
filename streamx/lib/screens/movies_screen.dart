// screens/movies_screen.dart — Premium redesign (Loklok style)
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config.dart';
import '../models/movie.dart';
import '../services/api_service.dart';
import 'movie_detail_screen.dart';

class MoviesScreen extends StatefulWidget {
  const MoviesScreen({super.key});
  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> {
  List<Movie> _movies = [];
  List<Movie> _featured = [];
  List<String> _categories = [];
  List<String> _languages = [];
  String _category = '';
  String _language = '';
  String _search = '';
  int _page = 1, _totalPages = 1;
  bool _loading = true, _loadingMore = false;
  String? _error;
  int _featuredIdx = 0;
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _pageCtrl = PageController();

  @override
  void initState() {
    super.initState();
    _load();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() { _searchCtrl.dispose(); _scrollCtrl.dispose(); _pageCtrl.dispose(); super.dispose(); }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 400
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
        _movies = res['movies'];
        _totalPages = res['total_pages'];
        _categories = List<String>.from(res['available_filters']['categories'] ?? []);
        _languages = List<String>.from(res['available_filters']['languages'] ?? []);
        _featured = (_movies.length > 5) ? _movies.sublist(0, 5) : _movies;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadMore() async {
    setState(() { _loadingMore = true; _page++; });
    try {
      final res = await ApiService.getMovies(page: _page,
        category: _category.isEmpty ? null : _category,
        language: _language.isEmpty ? null : _language,
        sort: 'newest');
      setState(() { _movies.addAll(res['movies']); _loadingMore = false; });
    } catch (_) { setState(() { _page--; _loadingMore = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(child: Column(children: [
        _topBar(),
        Expanded(child: _loading ? _shimmer() : _error != null ? _errorView() : _body()),
      ])),
    );
  }

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: Row(children: [
      Expanded(child: GestureDetector(
        onTap: () => _showSearch(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
          child: Row(children: [
            const Icon(Icons.search, color: Color(0xFF7F8EA3), size: 18),
            const SizedBox(width: 8),
            Text(_search.isEmpty ? 'Movie, Show খুঁজুন...' : _search,
                style: GoogleFonts.inter(color: const Color(0xFF7F8EA3), fontSize: 14)),
          ]),
        ),
      )),
      const SizedBox(width: 10),
      GestureDetector(
        onTap: _showFilters,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFF1A1A2E), shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
          child: const Icon(Icons.tune_rounded, color: Color(0xFF7F8EA3), size: 20),
        ),
      ),
    ]),
  );

  Widget _body() => CustomScrollView(
    controller: _scrollCtrl,
    slivers: [
      // Category tabs
      SliverToBoxAdapter(child: _categoryTabs()),
      // Featured banner
      if (_featured.isNotEmpty) SliverToBoxAdapter(child: _featuredBanner()),
      // Section: Trending
      SliverToBoxAdapter(child: _sectionHeader('🔥 Trending Now', '')),
      SliverToBoxAdapter(child: _horizontalList(_movies.take(10).toList())),
      // Section: All movies
      SliverToBoxAdapter(child: _sectionHeader('🎬 সব Movies', '${_movies.length}+')),
      // Grid
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (_, i) {
              if (i >= _movies.length) return _shimmerCard();
              return _MovieCard(movie: _movies[i]);
            },
            childCount: _movies.length + (_loadingMore ? 3 : 0),
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, childAspectRatio: 0.58, crossAxisSpacing: 8, mainAxisSpacing: 8),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ],
  );

  Widget _categoryTabs() => SizedBox(
    height: 40,
    child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _CatTab(label: 'সব', active: _category.isEmpty,
            onTap: () { setState(() => _category = ''); _load(); }),
        ..._categories.take(8).map((c) => _CatTab(label: c, active: _category == c,
            onTap: () { setState(() => _category = _category == c ? '' : c); _load(); })),
      ],
    ),
  );

  Widget _featuredBanner() {
    if (_featured.isEmpty) return const SizedBox();
    return SizedBox(
      height: 220,
      child: PageView.builder(
        controller: _pageCtrl,
        itemCount: _featured.length,
        onPageChanged: (i) => setState(() => _featuredIdx = i),
        itemBuilder: (_, i) {
          final m = _featured[i];
          return GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: m))),
            child: Stack(children: [
              // Poster
              m.posterUrl.isNotEmpty
                  ? CachedNetworkImage(imageUrl: m.posterUrl, fit: BoxFit.cover, width: double.infinity, height: 220,
                      placeholder: (_, __) => Container(color: const Color(0xFF1A1A2E)),
                      errorWidget: (_, __, ___) => _bannerPlaceholder())
                  : _bannerPlaceholder(),
              // Gradient overlay
              Container(decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC0A0A0F), Color(0xFF0A0A0F)],
                  stops: [0.4, 0.8, 1.0]),
              )),
              // Info
              Positioned(bottom: 16, left: 16, right: 16, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.title, style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  if (m.language.isNotEmpty) _Badge(m.language, const Color(0xFF2A7BED)),
                  const SizedBox(width: 6),
                  if (m.quality.isNotEmpty) _Badge(m.quality, const Color(0xFFE63946)),
                  const SizedBox(width: 6),
                  if (m.groupName.isNotEmpty)
                    Text(m.groupName, style: GoogleFonts.inter(color: const Color(0xFF7F8EA3), fontSize: 11)),
                ]),
              ])),
              // Dots
              Positioned(bottom: 8, right: 16, child: Row(
                children: List.generate(_featured.length, (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(left: 4),
                  width: i == _featuredIdx ? 16 : 5, height: 5,
                  decoration: BoxDecoration(
                    color: i == _featuredIdx ? const Color(0xFFE63946) : Colors.white24,
                    borderRadius: BorderRadius.circular(3)),
                )),
              )),
            ]),
          );
        },
      ),
    );
  }

  Widget _bannerPlaceholder() => Container(color: const Color(0xFF1A1A2E),
      child: const Center(child: Icon(Icons.movie, color: Color(0xFF7F8EA3), size: 64)));

  Widget _sectionHeader(String title, String sub) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
    child: Row(children: [
      Text(title, style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
      const Spacer(),
      if (sub.isNotEmpty) Text(sub, style: GoogleFonts.inter(color: const Color(0xFF7F8EA3), fontSize: 12)),
    ]),
  );

  Widget _horizontalList(List<Movie> movies) => SizedBox(
    height: 190,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: movies.length,
      itemBuilder: (_, i) => SizedBox(
        width: 110,
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _MovieCard(movie: movies[i], showRank: i < 3 ? i + 1 : null),
        ),
      ),
    ),
  );

  Widget _shimmer() => Shimmer.fromColors(
    baseColor: const Color(0xFF1A1A2E), highlightColor: const Color(0xFF252540),
    child: ListView(children: [
      Container(height: 40, margin: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
      Container(height: 220, margin: const EdgeInsets.symmetric(horizontal: 16), color: Colors.white),
      const SizedBox(height: 20),
      GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.58, crossAxisSpacing: 8, mainAxisSpacing: 8),
        itemCount: 9, itemBuilder: (_, __) => Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)))),
    ]),
  );

  Widget _shimmerCard() => Shimmer.fromColors(
    baseColor: const Color(0xFF1A1A2E), highlightColor: const Color(0xFF252540),
    child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10))),
  );

  Widget _errorView() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.wifi_off, color: Color(0xFFE63946), size: 64),
    const SizedBox(height: 16),
    Text('Connection Error', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
    const SizedBox(height: 24),
    ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE63946), foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      icon: const Icon(Icons.refresh), label: const Text('Retry'), onPressed: _load),
  ]));

  void _showSearch() async {
    final result = await showSearch(context: context, delegate: _MovieSearch(_search));
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
                child: const Text('Reset', style: TextStyle(color: Color(0xFFE63946)))),
          ]),
          const SizedBox(height: 16),
          Text('Language', style: GoogleFonts.inter(color: const Color(0xFF7F8EA3), fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _CatTab(label: 'সব', active: _language.isEmpty, onTap: () => setS(() => _language = '')),
            ..._languages.map((l) => _CatTab(label: l, active: _language == l, onTap: () => setS(() => _language = _language == l ? '' : l))),
          ]),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE63946), foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () { Navigator.pop(context); _load(); },
            child: Text('Apply', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          )),
        ]),
      )),
    );
  }
}

// ─── Movie Card (3-col grid style) ───────────────────────────────────────────
class _MovieCard extends StatelessWidget {
  final Movie movie;
  final int? showRank;
  const _MovieCard({required this.movie, this.showRank});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie))),
    child: Stack(children: [
      // Poster
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: movie.posterUrl.isNotEmpty
            ? CachedNetworkImage(imageUrl: movie.posterUrl, fit: BoxFit.cover, width: double.infinity, height: double.infinity,
                placeholder: (_, __) => Container(color: const Color(0xFF1A1A2E)),
                errorWidget: (_, __, ___) => Container(color: const Color(0xFF1A1A2E),
                    child: const Icon(Icons.movie, color: Color(0xFF7F8EA3), size: 32)))
            : Container(color: const Color(0xFF1A1A2E),
                child: const Icon(Icons.movie, color: Color(0xFF7F8EA3), size: 32)),
      ),
      // Gradient bottom
      Positioned(bottom: 0, left: 0, right: 0, child: Container(
        height: 60, decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0xCC000000)]),
        ),
      )),
      // Language badge top-left
      if (movie.language.isNotEmpty) Positioned(top: 6, left: 6, child: _Badge(movie.language.length > 5 ? movie.language.substring(0, 5) : movie.language, const Color(0xFF2A7BED))),
      // Rank badge top-left
      if (showRank != null) Positioned(top: 6, left: 6, child: Container(
        width: 24, height: 24,
        decoration: BoxDecoration(color: const Color(0xFFE63946), borderRadius: BorderRadius.circular(6)),
        child: Center(child: Text('$showRank', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900))),
      )),
      // Title bottom
      Positioned(bottom: 6, left: 6, right: 6, child: Text(movie.title, maxLines: 1,
          overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))),
    ]),
  );
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
    child: Text(text, style: GoogleFonts.inter(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
  );
}

class _CatTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _CatTab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 8, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
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

// ─── Search Delegate ──────────────────────────────────────────────────────────
class _MovieSearch extends SearchDelegate<String> {
  final String initial;
  _MovieSearch(this.initial);

  @override
  String get searchFieldLabel => 'Movie খুঁজুন...';

  @override
  ThemeData appBarTheme(BuildContext context) => Theme.of(context).copyWith(
    appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0A0A0F)),
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: GoogleFonts.inter(color: const Color(0xFF7F8EA3)),
    ),
  );

  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear, color: Color(0xFF7F8EA3)), onPressed: () { query = ''; }),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back, color: Colors.white),
    onPressed: () => close(context, initial),
  );

  @override
  Widget buildResults(BuildContext context) { close(context, query); return const SizedBox(); }

  @override
  Widget buildSuggestions(BuildContext context) => Container(color: const Color(0xFF0A0A0F));
}
