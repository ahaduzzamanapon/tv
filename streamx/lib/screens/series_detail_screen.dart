// screens/series_detail_screen.dart — Series detail with Season/Episode selector
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../services/api_service.dart';
import 'player_screen.dart';

class SeriesDetailScreen extends StatefulWidget {
  final Movie series;
  const SeriesDetailScreen({super.key, required this.series});
  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  List<int>    _seasons   = [];
  List<dynamic> _episodes = [];
  int  _selectedSeason = 1;
  bool _loading = true;
  String? _error;

  static const _bg     = Color(0xFF0A0A0F);
  static const _card   = Color(0xFF1A1A2E);
  static const _purple = Color(0xFF6C63FF);
  static const _red    = Color(0xFFE63946);
  static const _gray   = Color(0xFF7F8EA3);
  static const _teal   = Color(0xFF00D4AA);

  @override
  void initState() {
    super.initState();
    _loadEpisodes();
  }

  Future<void> _loadEpisodes({int? season}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.getSeriesEpisodes(
        widget.series.id,
        season: season ?? _selectedSeason,
      );
      setState(() {
        _episodes = res['episodes'] as List;
        _seasons  = List<int>.from(res['available_seasons'] ?? []);
        _selectedSeason = res['current_season'] ?? _selectedSeason;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(slivers: [
        // ── Hero Poster ──
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          backgroundColor: _bg,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 16),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(fit: StackFit.expand, children: [
              widget.series.posterUrl.isNotEmpty
                  ? CachedNetworkImage(imageUrl: widget.series.posterUrl, fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: _card),
                      errorWidget: (_, __, ___) => _posterPlaceholder())
                  : _posterPlaceholder(),
              Container(decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xDD0A0A0F), Color(0xFF0A0A0F)],
                    stops: [0.4, 0.85, 1.0]),
              )),
              // TV badge
              Positioned(top: 16, right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _purple, borderRadius: BorderRadius.circular(6)),
                  child: Text('WEB SERIES', style: GoogleFonts.inter(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                ),
              ),
            ]),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Title ──
              Text(widget.series.title,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.2)),
              const SizedBox(height: 10),

              // ── Meta badges ──
              Wrap(spacing: 8, runSpacing: 6, children: [
                if (widget.series.language.isNotEmpty) _Badge(widget.series.language, const Color(0xFF2A7BED)),
                if (widget.series.groupName.isNotEmpty) _Badge(widget.series.groupName, _purple),
                if (widget.series.totalSeasons > 0)
                  _Badge('${widget.series.totalSeasons} Season${widget.series.totalSeasons > 1 ? 's' : ''}', _teal),
              ]),
              const SizedBox(height: 24),

              // ── Season Selector ──
              if (_seasons.isNotEmpty) ...[
                Text('Season', style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _seasons.length,
                    itemBuilder: (_, i) {
                      final s = _seasons[i];
                      final active = s == _selectedSeason;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedSeason = s);
                          _loadEpisodes(season: s);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                          decoration: BoxDecoration(
                            color: active ? _purple : _card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: active ? _purple : Colors.white.withOpacity(0.1)),
                          ),
                          child: Text('S$s', style: GoogleFonts.inter(
                              color: active ? Colors.white : _gray,
                              fontSize: 13, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── Episodes ──
              Text('Episodes', style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),

              if (_loading)
                const Center(child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: _purple, strokeWidth: 2),
                ))
              else if (_error != null)
                Center(child: Column(children: [
                  const Icon(Icons.error_outline, color: _red, size: 48),
                  const SizedBox(height: 12),
                  Text('Error loading episodes', style: GoogleFonts.inter(color: _gray)),
                  TextButton(onPressed: _loadEpisodes, child: const Text('Retry', style: TextStyle(color: _red))),
                ]))
              else if (_episodes.isEmpty)
                Center(child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('কোন episode পাওয়া যায়নি', style: GoogleFonts.inter(color: _gray)),
                ))
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _episodes.length,
                  itemBuilder: (_, i) => _EpisodeTile(
                    episode: _episodes[i],
                    index: i + 1,
                    seriesTitle: widget.series.title,
                  ),
                ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _posterPlaceholder() => Container(
    color: _card,
    child: const Center(child: Icon(Icons.tv, color: _gray, size: 80)),
  );
}

// ── Episode Tile ─────────────────────────────────────────
class _EpisodeTile extends StatelessWidget {
  final dynamic episode;
  final int index;
  final String seriesTitle;
  const _EpisodeTile({required this.episode, required this.index, required this.seriesTitle});

  static const _card   = Color(0xFF1A1A2E);
  static const _purple = Color(0xFF6C63FF);
  static const _gray   = Color(0xFF7F8EA3);

  @override
  Widget build(BuildContext context) {
    final ep = episode as Map<String, dynamic>;
    final epNum    = ep['episode_num'] ?? index;
    final epTitle  = ep['ep_title'] ?? 'Episode $epNum';
    final streamUrl = ep['stream_url'] ?? '';
    final seasonNum = ep['season_num'] ?? 1;

    return GestureDetector(
      onTap: () {
        if (streamUrl.toString().isNotEmpty) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => PlayerScreen(
              title: '$seriesTitle — S${seasonNum}E$epNum',
              streamUrls: [streamUrl],
              language: 'Multi',
              category: 'Web Series',
            ),
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Stream পাওয়া যায়নি'), backgroundColor: Colors.red),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _card, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(children: [
          // Episode number circle
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _purple.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _purple.withOpacity(0.3)),
            ),
            child: Center(
              child: Text('E$epNum', style: GoogleFonts.inter(
                  color: _purple, fontSize: 12, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 12),
          // Title
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(epTitle, style: GoogleFonts.inter(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('Season $seasonNum  •  Episode $epNum',
                  style: GoogleFonts.inter(color: _gray, fontSize: 11)),
            ]),
          ),
          // Play button
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: streamUrl.toString().isNotEmpty ? _purple : Colors.white10,
              shape: BoxShape.circle,
            ),
            child: Icon(
              streamUrl.toString().isNotEmpty ? Icons.play_arrow_rounded : Icons.lock_outline,
              color: Colors.white, size: 18,
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Badge ──────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4))),
    child: Text(text, style: GoogleFonts.inter(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
  );
}
