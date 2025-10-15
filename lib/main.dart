import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'features/auth_wrapper.dart';
import 'services/auth_s.dart';
import 'services/password_s.dart';
import 'services/prefs_s.dart';

void main() async {
  // Ensure Flutter is initialized.
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // Initialize Firebase
  await Future.wait([Firebase.initializeApp(), Prefs.init()]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MultiProvider allows us to provide multiple services to the widget tree.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        // PasswordService depends on AuthService to get the current user's ID for cloud sync.
        ChangeNotifierProxyProvider<AuthService, PasswordService>(
          create: (_) => PasswordService(null),
          update: (_, auth, previous) {
            final service = previous ?? PasswordService(auth);
            // update new auth when changes
            service.updateAuth(auth);
            return service;
          },
        ),
      ],

      child: MaterialApp(
        title: 'Secura',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.teal,
          scaffoldBackgroundColor: const Color(0xFF121212),
          cardColor: const Color(0xFF1E1E1E),
          hintColor: Colors.grey[400],
          dividerColor: Colors.grey[700],
          colorScheme: ColorScheme.dark(
            primary: Colors.tealAccent.shade700,
            secondary: Colors.deepPurpleAccent.shade700,
            surface: const Color(0xFF1E1E1E),
            error: Colors.redAccent.shade400,
            onPrimary: Colors.black,
            onSecondary: Colors.white,
            onSurface: Colors.white,
            onError: Colors.black,
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: const Color(0xFF1E1E1E),
            elevation: 4,
            titleTextStyle: const TextStyle(
              color: Colors.tealAccent,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            iconTheme: const IconThemeData(color: Colors.tealAccent),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            hintStyle: TextStyle(color: Colors.grey[400]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.tealAccent, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 14,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent.shade700,
              foregroundColor: Colors.black,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: Colors.tealAccent.shade700,
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          iconTheme: IconThemeData(color: Colors.tealAccent.shade700, size: 24),
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            backgroundColor: const Color(0xFF1E1E1E),
            selectedItemColor: Colors.tealAccent.shade700,
            unselectedItemColor: Colors.grey[500],
            showUnselectedLabels: true,
            elevation: 8,
          ),
          snackBarTheme: SnackBarThemeData(
            backgroundColor: const Color(0xFF333333),
            contentTextStyle: const TextStyle(color: Colors.white),
            actionTextColor: Colors.tealAccent.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          dividerTheme: DividerThemeData(
            color: Colors.grey[700],
            thickness: 1,
            space: 1,
          ),
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: Colors.white),
            bodyMedium: TextStyle(color: Colors.white70),
            titleLarge: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            labelLarge: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.tealAccent,
            ),
          ),
        ),
        home: const AuthGate(),
      ),
    );
  }
}
