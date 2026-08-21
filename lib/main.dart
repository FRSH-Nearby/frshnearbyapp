import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'features/auth/auth_screen.dart';
import 'features/auth/app_preferences_store.dart';
import 'features/notifications/push_notification_service.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  const useFirebaseEmulator = bool.fromEnvironment(
    'USE_FIREBASE_EMULATOR',
    defaultValue: false,
  );

  if (useFirebaseEmulator) {
    await FirebaseAuth.instance.useAuthEmulator(
      'localhost',
      9099,
    );
  }

  runApp(const FrshNearbyApp());
}

class FrshNearbyApp extends StatefulWidget {
  const FrshNearbyApp({super.key});

  @override
  State<FrshNearbyApp> createState() => _FrshNearbyAppState();
}

class _FrshNearbyAppState extends State<FrshNearbyApp> {
  final _preferences = AppPreferencesStore();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  Locale? _preferredLocale;

  @override
  void initState() {
    super.initState();
    PushNotificationService.instance.initialize(_messengerKey);
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final language = await _preferences.language();
    if (mounted && language != null) {
      setState(() => _preferredLocale = Locale(language));
    }
  }

  Future<void> _setLanguage(String languageCode) async {
    await _preferences.setLanguage(languageCode);
    if (mounted) setState(() => _preferredLocale = Locale(languageCode));
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF2F6B45);
    const ink = Color(0xFF1B2A20);
    const muted = Color(0xFF66735F);
    const field = Color(0xFFF3F2EA);
    const cream = Color(0xFFFBFAF5);

    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              color == Colors.transparent
                  ? BorderSide.none
                  : BorderSide(color: color, width: width),
        );

    return MaterialApp(
      scaffoldMessengerKey: _messengerKey,
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      locale: _preferredLocale,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
        ).copyWith(primary: primary),
        scaffoldBackgroundColor: cream,
        textTheme: GoogleFonts.interTextTheme().apply(
          bodyColor: ink,
          displayColor: ink,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primary,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: ink,
          contentTextStyle: GoogleFonts.inter(color: cream, fontSize: 13.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: field,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          labelStyle: const TextStyle(
            color: muted,
            fontWeight: FontWeight.w500,
          ),
          hintStyle: const TextStyle(color: Color(0xFF9AA69A)),
          border: inputBorder(Colors.transparent),
          enabledBorder: inputBorder(Colors.transparent),
          focusedBorder: inputBorder(primary, 1.6),
          errorBorder: inputBorder(const Color(0xFFBA1A1A)),
          focusedErrorBorder: inputBorder(const Color(0xFFBA1A1A), 1.6),
        ),
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        for (final locale in supportedLocales) {
          if (locale.languageCode == deviceLocale?.languageCode) return locale;
        }
        return const Locale('en');
      },
      home: _ResponsiveAuthPreview(
        selectedLanguageCode: _preferredLocale?.languageCode,
        onLanguageChanged: _setLanguage,
      ),
    );
  }
}

class _ResponsiveAuthPreview extends StatelessWidget {
  const _ResponsiveAuthPreview({
    required this.selectedLanguageCode,
    required this.onLanguageChanged,
  });

  final String? selectedLanguageCode;
  final ValueChanged<String> onLanguageChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // On a desktop-sized browser, present the app inside a phone-sized
        // preview. Phones and narrow browser windows keep the native full view.
        if (constraints.maxWidth < 800) {
          return AuthScreen(
            selectedLanguageCode: selectedLanguageCode,
            onLanguageChanged: onLanguageChanged,
          );
        }

        final phoneHeight = (constraints.maxHeight - 64).clamp(640.0, 860.0);
        return Scaffold(
          backgroundColor: const Color(0xFF0E2118),
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -.4),
                radius: 1.2,
                colors: [Color(0xFF16321F), Color(0xFF0E2118)],
              ),
            ),
            child: Center(
              child: Container(
                width: 430,
                height: phoneHeight,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1811),
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x59040B07),
                      blurRadius: 60,
                      offset: Offset(0, 28),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: AuthScreen(
                    selectedLanguageCode: selectedLanguageCode,
                    onLanguageChanged: onLanguageChanged,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
