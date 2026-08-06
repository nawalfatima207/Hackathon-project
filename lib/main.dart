import 'dart:ui';
import 'package:ai_lecture_assistant/services/auth_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'firebase_options.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';


void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lecture Summarizer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          primary: AppColors.accent,
          background: AppColors.background,
        ),
        useMaterial3: true,
      ),
      home: StreamBuilder(
        stream: AuthService.instance.authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            return const RootShell();
          }
          return const LoginScreen();
        },
      ),
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
    setState(() => _currentIndex = 0);
    _homeKey.currentState?.loadLecture(item);
  }

  late final List<Widget> _screens = [
    HomeScreen(key: _homeKey),
    LibraryScreen(onLectureTap: _openLectureInHome),
    ProfileScreen(onLectureTap: _openLectureInHome),
  ];

  Future<bool> _confirmLeaveIfNeeded() async {
    final homeState = _homeKey.currentState;
    if (homeState == null || !homeState.hasUnsavedConversation) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save this conversation?'),
        content: const Text('Do you want to save this conversation to your library before leaving?'),
        actions: [
          TextButton(
            onPressed: () {
              homeState.markSaveDialogSeen();
              Navigator.pop(context, false);
            },
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () async {
              await homeState.saveCurrentConversation();
              Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _navigateTo(int index) async {
    if (_currentIndex == 0 && index != 0) {
      final canLeave = await _confirmLeaveIfNeeded();
      if (!canLeave) return;
    }
    setState(() => _currentIndex = index);
    Navigator.pop(context);
  }

  void _startNewChat() async {
    if (_currentIndex == 0) {
      final canLeave = await _confirmLeaveIfNeeded();
      if (!canLeave) return;
    }
    _homeKey.currentState?.resetChat();
    setState(() => _currentIndex = 0);
    Navigator.pop(context);
  }

  Future<void> _handleLogout() async {
    Navigator.pop(context);
    await AuthService.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: Drawer(
        backgroundColor: AppColors.card,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  'Menu',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
              ),
              const Divider(height: 1),
              const SizedBox(height: 8),
              _DrawerItem(icon: Icons.bolt, label: 'Home', selected: _currentIndex == 0, onTap: () => _navigateTo(0)),
              _DrawerItem(icon: Icons.video_library_outlined, label: 'Library', selected: _currentIndex == 1, onTap: () => _navigateTo(1)),
              _DrawerItem(icon: Icons.person_outline, label: 'Profile', selected: _currentIndex == 2, onTap: () => _navigateTo(2)),
              const Padding(padding: EdgeInsets.fromLTRB(20, 16, 20, 4), child: Divider(height: 1)),
              _DrawerItem(icon: Icons.add_comment_outlined, label: 'New Chat', selected: false, onTap: _startNewChat),
              _DrawerItem(
                icon: Icons.tune,
                label: 'Response Preferences',
                selected: false,
                onTap: () {
                  Navigator.pop(context);
                  _homeKey.currentState?.showPreferencesSheet();
                },
              ),
              const Padding(padding: EdgeInsets.fromLTRB(20, 16, 20, 4), child: Divider(height: 1)),
              _DrawerItem(
                icon: Icons.logout,
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
            IndexedStack(index: _currentIndex, children: _screens),
            Positioned(
              top: 8,
              left: 8,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.menu, color: AppColors.textDark),
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DrawerItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: selected ? AppColors.accent : AppColors.textMuted),
      title: Text(
        label,
        style: TextStyle(color: selected ? AppColors.accent : AppColors.textDark, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
      ),
      selected: selected,
      selectedTileColor: AppColors.accent.withOpacity(0.08),
      onTap: onTap,
    );
  }
}