// screens/movie_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config.dart';
import '../models/movie.dart';
import 'player_screen.dart';

class MovieDetailScreen extends StatelessWidget {
  final Movie movie;
  const MovieDetailScreen({super.key, required this.movie});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: CustomScrollView(slivers: [
        // ── Hero Poster ──
        SliverAppBar(
          expandedHeight: 300,
          pinned: true,
          backgroundColor: const Color(0xFF0A0A0F),
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 16),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(fit: StackFit.expand, children: [
              movie.posterUrl.isNotEmpty
                  ? CachedNetworkImage(imageUrl: movie.posterUrl, fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: const Color(0xFF1A1A2E)),
                      errorWidget: (_, __, ___) => _posterPlaceholder())
                  : _posterPlaceholder(),
              // Gradient
              Container(decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xDD0A0A0F), Color(0xFF0A0A0F)],
                  stops: [0.4, 0.85, 1.0]),
              )),
            ]),
          ),
        ),

        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Title ──
            Text(movie.title,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.2)),
            const SizedBox(height: 12),

            // ── Meta info ──
            Wrap(spacing: 8, runSpacing: 6, children: [
              if (movie.language.isNotEmpty) _MetaBadge(movie.language, const Color(0xFF2A7BED)),
              if (movie.quality.isNotEmpty)  _MetaBadge(movie.quality,  const Color(0xFFE63946)),
              if (movie.groupName.isNotEmpty)
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
                  child: Text(movie.groupName, style: GoogleFonts.inter(color: const Color(0xFF7F8EA3), fontSize: 12))),
            ]),
            const SizedBox(height: 24),

            // ── Play Button ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE63946),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 28),
                label: Text('Watch Now', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => PlayerScreen(title: movie.title, streamUrls: [movie.streamUrl], isMatch: false),
                )),
              ),
            ),
            const SizedBox(height: 12),

            // ── Open in Browser button ──
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text('External Player', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => PlayerScreen(title: movie.title, streamUrls: [movie.streamUrl], isMatch: false),
                )),
              ),
            ),
            const SizedBox(height: 32),

            // ── Info Section ──
            _InfoRow('Source', movie.source),
            if (movie.addedAt.isNotEmpty)
              _InfoRow('Added', movie.addedAt.split(' ').first),
          ]),
        )),
      ]),
    );
  }

  Widget _posterPlaceholder() => Container(
    color: const Color(0xFF1A1A2E),
    child: const Center(child: Icon(Icons.movie, color: Color(0xFF7F8EA3), size: 80)),
  );
}

class _MetaBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _MetaBadge(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4))),
    child: Text(text, style: GoogleFonts.inter(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
  );
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      SizedBox(width: 80, child: Text(label, style: GoogleFonts.inter(color: const Color(0xFF7F8EA3), fontSize: 13))),
      const SizedBox(width: 8),
      Text(':', style: GoogleFonts.inter(color: const Color(0xFF7F8EA3))),
      const SizedBox(width: 8),
      Expanded(child: Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 13), overflow: TextOverflow.ellipsis)),
    ]),
  );
}
