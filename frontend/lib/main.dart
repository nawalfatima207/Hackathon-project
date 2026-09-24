import 'package:zero_ai_project/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'firebase_options.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'conversation_store.dart';
import 'widgets/glass.dart';
import 'widgets/custom_icons.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Completes a Google sign-in that used signInWithRedirect (web), so the
  // very first frame already reflects the signed-in state instead of
  // flashing the login screen before authStateChanges() catches up.
  await AuthService.instance.consumePendingRedirectResult();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zylo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: Brightness.dark,
          primary: AppColors.accent,
          surface: AppColors.card,
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

/// Single place that decides "logged in -> app, logged out -> login/signup".
///
/// Login and Signup are swapped *inside* this widget (not pushed as routes),
/// so the auth listener below is never removed from the tree. Any successful
/// sign-in (email, Google popup, or Google redirect) flips the stream and the
/// app moves to the home screen on its own -- no manual Navigator calls.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _showSignup = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      initialData: AuthService.instance.currentUser,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return const RootShell();
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.accentSoft),
            ),
          );
        }

        return _showSignup
            ? SignupScreen(onShowLogin: () => setState(() => _showSignup = false))
            : LoginScreen(onShowSignup: () => setState(() => _showSignup = true));
      },
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();

  int _currentIndex = 0;

  void _openLectureInHome(LectureItem item) {
    setState(() {
      _currentIndex = 0;
    });
    _homeKey.currentState?.loadLecture(item);
  }

  String get _greetingName {
    final displayName = AuthService.instance.currentUser?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName.split(RegExp(r'\s+')).first;
    }
    final email = AuthService.instance.currentUser?.email;
    if (email != null && email.contains('@')) return email.split('@').first;
    return 'there';
  }

  late final List<Widget> _screens = [
    HomeScreen(
      key: _homeKey,
      userName: _greetingName,
      onViewLibrary: () => setState(() => _currentIndex = 1),
    ),
    LibraryScreen(
      onLectureTap: _openLectureInHome,
    ),
    ProfileScreen(
      onLectureTap: _openLectureInHome,
    ),
  ];

  void _navigateTo(int index) {
    setState(() {
      _currentIndex = index;
    });
    Navigator.pop(context);
  }

  void _startNewChat() {
    _homeKey.currentState?.resetChat();
    setState(() {
      _currentIndex = 0;
    });
    Navigator.pop(context);
  }

  Future<void> _handleLogout() async {
    Navigator.pop(context); // close the drawer
    // AuthGate listens to the auth stream and shows the login screen itself.
    await AuthService.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: Drawer(
        backgroundColor: AppColors.cardAlt,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  'Menu',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Divider(height: 1, color: AppColors.glassBorder),
              const SizedBox(height: 8),
              _DrawerItem(
                glyph: AppGlyph.home,
                label: 'Home',
                selected: _currentIndex == 0,
                onTap: () => _navigateTo(0),
              ),
              _DrawerItem(
                glyph: AppGlyph.library,
                label: 'Library',
                selected: _currentIndex == 1,
                onTap: () => _navigateTo(1),
              ),
              _DrawerItem(
                glyph: AppGlyph.profile,
                label: 'Profile',
                selected: _currentIndex == 2,
                onTap: () => _navigateTo(2),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Divider(height: 1, color: AppColors.glassBorder),
              ),
              _DrawerItem(
                glyph: AppGlyph.addChat,
                label: 'New Chat',
                selected: false,
                onTap: _startNewChat,
              ),
              _DrawerItem(
                glyph: AppGlyph.sliders,
                label: 'Response Preferences',
                selected: false,
                onTap: () {
                  Navigator.pop(context);
                  _homeKey.currentState?.showPreferencesSheet();
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Divider(height: 1, color: AppColors.glassBorder),
              ),
              _DrawerItem(
                glyph: AppGlyph.logout,
                label: 'Log Out',
                selected: false,
                onTap: _handleLogout,
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
            Positioned(
              top: 8,
              left: 8,
              child: GlassIconButton(
                icon: const AppIcon(AppGlyph.menu, color: AppColors.textDark, size: 16),
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final AppGlyph glyph;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.glyph,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: AppIcon(
        glyph,
        color: selected ? AppColors.accentSoft : AppColors.textMuted,
        size: 18,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? AppColors.accentSoft : AppColors.textDark,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      selected: selected,
      selectedTileColor: AppColors.accent.withOpacity(0.12),
      onTap: onTap,
    );
  }
}
