// screens/player_screen.dart — Loklok-style Premium Player
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../config.dart';

class PlayerScreen extends StatefulWidget {
  final String title;
  final List<dynamic> streamUrls;
  final bool isMatch;
  final String? poster;
  final String? year;
  final String? quality;
  final String? language;
  final String? category;
  final List<Map<String, dynamic>> relatedItems;

  const PlayerScreen({
    super.key,
    required this.title,
    required this.streamUrls,
    this.isMatch = false,
    this.poster,
    this.year,
    this.quality,
    this.language,
    this.category,
    this.relatedItems = const [],
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late WebViewController _wc;
  int _selectedIdx = 0;
  bool _loading = true;
  bool _isFullscreen = false;
  bool _inList = false;
  String _selectedLang = '';

  static const _bg        = Color(0xFF0F0F0F);
  static const _card      = Color(0xFF1A1A2E);
  static const _accent    = Color(0xFFE63946);
  static const _teal      = Color(0xFF00D4AA);
  static const _textGray  = Color(0xFF9E9E9E);

  @override
  void initState() {
    super.initState();
    _selectedLang = widget.language ?? 'Default';
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _initWebView();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _initWebView() {
    _wc = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) => setState(() => _loading = false),
        onWebResourceError: (_) => setState(() => _loading = false),
      ));
    _loadStream(_selectedIdx);
  }

  void _loadStream(int idx) {
    if (widget.streamUrls.isEmpty) {
      _wc.loadHtmlString(_noStreamHtml());
      return;
    }
    final url = widget.streamUrls[idx].toString();
    if (url.isEmpty || url == 'null' || url == 'about:blank') {
      _wc.loadHtmlString(_noStreamHtml());
      return;
    }
    if (url.contains('.m3u8') || url.contains('.mp4') || url.contains('.mkv') || url.contains('.ts')) {
      _wc.loadHtmlString(_buildHlsPlayer(url));
    } else {
      _wc.loadRequest(Uri.parse(url));
    }
  }

  String _noStreamHtml() => '''<html><body style="background:#0F0F0F;color:#666;display:flex;
    align-items:center;justify-content:center;height:100vh;margin:0;font-family:sans-serif;font-size:16px">
    <div style="text-align:center"><div style="font-size:48px">⚠️</div><p>Stream পাওয়া যায়নি</p></div></body></html>''';

  String _buildHlsPlayer(String url) => '''<!DOCTYPE html><html>
<head><meta name="viewport" content="width=device-width,initial-scale=1">
<style>*{margin:0;padding:0;background:#000}video{width:100vw;height:100vh;object-fit:contain}</style>
<script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>
</head><body>
<video id="v" controls autoplay playsinline></video>
<script>
var v=document.getElementById('v'),s="$url";
if(Hls.isSupported()&&s.includes('.m3u8')){var h=new Hls();h.loadSource(s);h.attachMedia(v);h.on(Hls.Events.MANIFEST_PARSED,function(){v.play()});}
else{v.src=s;v.play();}
</script></body></html>''';

  void _switchStream(int idx) {
    setState(() { _selectedIdx = idx; _loading = true; });
    _loadStream(idx);
  }

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullscreen) return _buildFullscreenPlayer();

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(children: [
          // ── Video Player (top 35% of screen) ──
          _buildVideoSection(),

          // ── Scrollable content below ──
          Expanded(
            child: SingleChildScrollView(
              child: Column(children: [
                _buildMovieInfo(),
                _buildActionButtons(),
                _buildResourcesSection(),
                _buildForYouSection(),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  // ════════════════════════════════════════
  //  VIDEO PLAYER SECTION
  // ════════════════════════════════════════
  Widget _buildVideoSection() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.30,
      color: Colors.black,
      child: Stack(children: [
        // WebView
        WebViewWidget(controller: _wc),

        // Loading
        if (_loading)
          Container(
            color: Colors.black,
            child: const Center(child: CircularProgressIndicator(color: _accent, strokeWidth: 2)),
          ),

        // Top bar (back + help)
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.7), Colors.transparent],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.help_outline, color: Colors.white, size: 16),
                  label: Text('Help', style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),

        // Bottom controls (fullscreen)
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.8), Colors.transparent],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.fullscreen, color: Colors.white, size: 22),
                  onPressed: _toggleFullscreen,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                  onPressed: () { setState(() => _loading = true); _loadStream(_selectedIdx); },
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  // ════════════════════════════════════════
  //  MOVIE INFO
  // ════════════════════════════════════════
  Widget _buildMovieInfo() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Title + Info button
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: GoogleFonts.inter(
                  color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
                maxLines: 2, overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white30),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Info', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                const SizedBox(width: 3),
                const Icon(Icons.chevron_right, color: Colors.white70, size: 14),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Meta row: rating, year, region, genre
        Row(children: [
          // Rating
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white10, borderRadius: BorderRadius.circular(4),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.star, color: Color(0xFFFFD700), size: 13),
              const SizedBox(width: 3),
              Text('8.5', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(width: 10),
          if (widget.year != null) ...[
            Text(widget.year!, style: GoogleFonts.inter(color: _textGray, fontSize: 12)),
            const SizedBox(width: 8),
            const Text('•', style: TextStyle(color: Colors.white30)),
            const SizedBox(width: 8),
          ],
          if (widget.language != null)
            Text(widget.language!, style: GoogleFonts.inter(color: _textGray, fontSize: 12)),
          if (widget.category != null) ...[
            const SizedBox(width: 8),
            const Text('•', style: TextStyle(color: Colors.white30)),
            const SizedBox(width: 8),
            Text(widget.category!, style: GoogleFonts.inter(color: _textGray, fontSize: 12)),
          ],
        ]),
      ]),
    );
  }

  // ════════════════════════════════════════
  //  ACTION BUTTONS
  // ════════════════════════════════════════
  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(children: [
        _actionBtn(Icons.playlist_add, _inList ? 'Added' : 'Add to list',
          _inList ? _teal : Colors.white70, () => setState(() => _inList = !_inList)),
        _actionBtn(Icons.share_outlined, 'Share', Colors.white70, () {}),
        _actionBtn(Icons.download_outlined, 'Download', Colors.white70, () {}),
        if (widget.streamUrls.length > 1)
          _actionBtn(Icons.play_circle_outline, 'Sources', Colors.white70, _showSourcesSheet),
      ]),
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.inter(color: color, fontSize: 10), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  void _showSourcesSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Stream Sources', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...List.generate(widget.streamUrls.length, (i) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: i == _selectedIdx ? _teal : Colors.white10,
              radius: 16,
              child: Text('${i+1}', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            title: Text('Stream ${i+1}', style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
            trailing: i == _selectedIdx
              ? const Icon(Icons.check_circle, color: _teal, size: 20)
              : null,
            onTap: () { Navigator.pop(context); _switchStream(i); },
          )),
        ]),
      ),
    );
  }

  // ════════════════════════════════════════
  //  RESOURCES / LANGUAGE
  // ════════════════════════════════════════
  Widget _buildResourcesSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Divider(color: Colors.white10, height: 1),
        const SizedBox(height: 12),
        Row(children: [
          Text('Resources', style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text('Uploaded by Media Hub', style: GoogleFonts.inter(color: _textGray, fontSize: 12)),
        ]),
        const SizedBox(height: 10),

        // Language chip
        GestureDetector(
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white10, borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_selectedLang, style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down, color: Colors.white60, size: 18),
            ]),
          ),
        ),
        const SizedBox(height: 12),

        // Play button
        GestureDetector(
          onTap: () => _loadStream(_selectedIdx),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF00BFA5), Color(0xFF00897B)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              widget.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ]),
    );
  }

  // ════════════════════════════════════════
  //  FOR YOU (Related)
  // ════════════════════════════════════════
  Widget _buildForYouSection() {
    if (widget.relatedItems.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Divider(color: Colors.white10, height: 1),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Row(children: [
          Text('For you', style: GoogleFonts.inter(
            color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(width: 16),
          Text('Comments', style: GoogleFonts.inter(color: _textGray, fontSize: 14)),
        ]),
      ),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, childAspectRatio: 0.62,
          crossAxisSpacing: 8, mainAxisSpacing: 8,
        ),
        itemCount: widget.relatedItems.length.clamp(0, 9),
        itemBuilder: (_, i) => _relatedCard(widget.relatedItems[i]),
      ),
      const SizedBox(height: 20),
    ]);
  }

  Widget _relatedCard(Map<String, dynamic> item) {
    return GestureDetector(
      onTap: () {},
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Poster
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(fit: StackFit.expand, children: [
              item['poster_url'] != null && item['poster_url'].toString().isNotEmpty
                ? Image.network(item['poster_url'], fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: _card))
                : Container(color: _card, child: const Icon(Icons.movie, color: Colors.white24, size: 32)),
              if (item['language'] != null)
                Positioned(
                  top: 4, left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(item['language'] ?? '', style: GoogleFonts.inter(
                      color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          item['title'] ?? '',
          style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
          maxLines: 2, overflow: TextOverflow.ellipsis,
        ),
      ]),
    );
  }

  // ════════════════════════════════════════
  //  FULLSCREEN MODE
  // ════════════════════════════════════════
  Widget _buildFullscreenPlayer() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        WebViewWidget(controller: _wc),
        if (_loading) const Center(child: CircularProgressIndicator(color: _accent)),
        Positioned(
          top: 16, left: 8,
          child: IconButton(
            icon: const Icon(Icons.fullscreen_exit, color: Colors.white, size: 26),
            onPressed: _toggleFullscreen,
          ),
        ),
      ]),
    );
  }
}
