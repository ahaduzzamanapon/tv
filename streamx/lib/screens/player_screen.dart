// screens/player_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../config.dart';

class PlayerScreen extends StatefulWidget {
  final String title;
  final List<dynamic> streamUrls;
  final bool isMatch;

  const PlayerScreen({
    super.key,
    required this.title,
    required this.streamUrls,
    required this.isMatch,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late WebViewController _wc;
  int _selectedIdx = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
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

    final url = _currentUrl;
    if (url.startsWith('<!DOCTYPE')) {
      _wc.loadHtmlString(url);
    } else {
      _wc.loadRequest(Uri.parse(url));
    }
  }

  String get _currentUrl {
    if (widget.streamUrls.isEmpty) return 'about:blank';
    final url = widget.streamUrls[_selectedIdx].toString();
    if (url.startsWith('http')) return url;
    return 'about:blank';
  }

  String _buildHtmlPlayer(String url) => '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>* { margin:0; padding:0; background:#000; } video { width:100vw; height:100vh; object-fit:contain; }</style>
</head>
<body>
  <video controls autoplay playsinline>
    <source src="$url">
  </video>
</body>
</html>''';


  void _switchStream(int idx) {
    setState(() { _selectedIdx = idx; _loading = true; });
    final url = widget.streamUrls[idx].toString();
    if (url.contains('.m3u8') || url.contains('.mp4')) {
      _wc.loadHtmlString(_buildHtmlPlayer(url));
    } else {
      _wc.loadRequest(Uri.parse(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(children: [
          // Top bar
          Container(
            color: const Color(AppConfig.bgDark),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(child: Text(widget.title,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis)),
              IconButton(
                icon: const Icon(Icons.open_in_new, color: Color(0xFF7F8EA3), size: 20),
                onPressed: () async {
                  final url = widget.streamUrls[_selectedIdx].toString();
                  _wc.loadRequest(Uri.parse(url));
                },
                tooltip: 'Reload',
              ),
            ]),
          ),

          // WebView Player
          Expanded(child: Stack(children: [
            WebViewWidget(controller: _wc),
            if (_loading) Container(color: Colors.black,
                child: const Center(child: CircularProgressIndicator(color: Color(0xFFE63946)))),
          ])),

          // Stream selector (if multiple streams)
          if (widget.streamUrls.length > 1)
            Container(
              color: const Color(AppConfig.bgDark),
              height: 52,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: widget.streamUrls.length,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _switchStream(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: _selectedIdx == i ? const Color(0xFFE63946) : const Color(AppConfig.bgCard),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Stream ${i + 1}',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
                            color: _selectedIdx == i ? Colors.white : const Color(0xFF7F8EA3))),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
