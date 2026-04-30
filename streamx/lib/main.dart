// main.dart — StreamX App Entry Point
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'config.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(AppConfig.bgDark),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const StreamXApp());
}

class StreamXApp extends StatelessWidget {
  const StreamXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(AppConfig.bgDark),
        colorScheme: ColorScheme.dark(
          primary:   const Color(AppConfig.primaryRed),
          secondary: const Color(0xFFF4A261),
          surface:   const Color(AppConfig.bgCard),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(AppConfig.bgDark),
          elevation: 0,
          titleTextStyle: GoogleFonts.inter(
            color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700,
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(AppConfig.bgCard),
          contentTextStyle: TextStyle(color: Colors.white),
        ),
        dividerColor: Colors.white12,
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
