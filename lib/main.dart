import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'services/auth_service.dart';
import 'theme/brand.dart';
import 'widgets/app_loading.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const FlickerApp());
}

class FlickerApp extends StatelessWidget {
  const FlickerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthService>(
      create: (_) => AuthService(),
      child: MaterialApp(
        title: FlickerStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: FlickerColors.canvas,
          colorScheme: const ColorScheme.dark(
            primary: FlickerColors.primary,
            secondary: FlickerColors.primaryBright,
            surface: FlickerColors.surface,
            onSurface: FlickerColors.cream,
            error: FlickerColors.danger,
          ),
          fontFamily: 'sans-serif',
          textTheme: const TextTheme(
            bodyMedium: FlickerText.body,
            titleLarge: FlickerText.title,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: FlickerColors.canvas,
            foregroundColor: FlickerColors.cream,
            elevation: 0,
            scrolledUnderElevation: 0,
            titleTextStyle: FlickerText.section,
            iconTheme: IconThemeData(color: FlickerColors.cream),
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: FlickerColors.surface,
            selectedItemColor: FlickerColors.primaryBright,
            unselectedItemColor: FlickerColors.muted,
            type: BottomNavigationBarType.fixed,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: FlickerColors.primary,
              foregroundColor: FlickerColors.cream,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: FlickerColors.primary,
              foregroundColor: FlickerColors.cream,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: FlickerColors.surfaceRaised,
            hintStyle: FlickerText.caption,
            labelStyle: FlickerText.caption,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              borderSide: BorderSide(color: FlickerColors.primaryBright),
            ),
          ),
          dividerTheme: const DividerThemeData(
            color: FlickerColors.divider,
            space: 1,
          ),
        ),
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: AppLoading());
            }

            if (snapshot.hasData) {
              return const MainScreen();
            }

            return const LoginScreen();
          },
        ),
      ),
    );
  }
}
