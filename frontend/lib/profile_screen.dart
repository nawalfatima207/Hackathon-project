import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'app_colors.dart';
import 'conversation_store.dart';
import 'library_screen.dart';
import 'services/auth_service.dart';
import 'widgets/glass.dart';
import 'widgets/custom_icons.dart';

class ProfileScreen extends StatefulWidget {
  final void Function(LectureItem item)? onLectureTap;
  const ProfileScreen({super.key, this.onLectureTap});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Uint8List? _avatarBytes;
  final ImagePicker _picker = ImagePicker();

  String _name = 'Your Name';
  String _title = 'Software Engineering Student';
  String _institution = 'University of Gujrat';

  /// Only the first character of the name is shown on the avatar, per design.
  String get _initials {
    final trimmed = _name.trim();
    return trimmed.isNotEmpty ? trimmed[0].toUpperCase() : '?';
  }

  void _loadNameFromAccount() {
    final user = AuthService.instance.currentUser;
    final displayName = user?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      _name = displayName;
    } else if (user?.email != null && user!.email!.contains('@')) {
      _name = user.email!.split('@').first;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadNameFromAccount();
    ConversationStore.instance.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    ConversationStore.instance.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context);
    final XFile? picked = await _picker.pickImage(source: source, imageQuality: 80);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _avatarBytes = bytes);
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _DarkSheet(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Profile Photo',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _PhotoOptionTile(
                    glyph: AppGlyph.camera,
                    title: 'Take a Photo',
                    subtitle: 'Use your camera',
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                  const SizedBox(height: 12),
                  _PhotoOptionTile(
                    glyph: AppGlyph.gallery,
                    title: 'Choose from Gallery',
                    subtitle: 'Pick an existing photo',
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showEditProfileSheet() {
    final nameController = TextEditingController(text: _name);
    final titleController = TextEditingController(text: _title);
    final institutionController = TextEditingController(text: _institution);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _DarkSheet(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit Profile',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
                const SizedBox(height: 16),
                _EditField(label: 'Name', controller: nameController),
                const SizedBox(height: 12),
                _EditField(label: 'Title', controller: titleController),
                const SizedBox(height: 12),
                _EditField(label: 'Institution', controller: institutionController),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: GlassGradientButton(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    onTap: () {
                      final newName = nameController.text.trim().isEmpty ? _name : nameController.text.trim();
                      setState(() {
                        _name = newName;
                        _title = titleController.text.trim().isEmpty ? _title : titleController.text.trim();
                        _institution = institutionController.text.trim().isEmpty ? _institution : institutionController.text.trim();
                      });
                      AuthService.instance.updateDisplayName(newName);
                      Navigator.pop(context);
                    },
                    child: const Center(
                      child: Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final allLectures = ConversationStore.instance.all;
    final recent = ConversationStore.instance.recent;
    int totalSummaryRequests(List<LectureItem> items) {
      return items.fold(0, (sum, item) => sum + item.summaryRequestCount);
    }
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.6),
          radius: 1.3,
          colors: AppColors.backgroundGradient,
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 230,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.accentDeep, AppColors.background.withOpacity(0)],
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 20,
                    left: 56,
                    right: 60,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YOUR ACCOUNT',
                          style: TextStyle(
                            color: AppColors.accentSoft,
                            fontSize: 12,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Profile',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: GlassIconButton(
                      icon: const AppIcon(AppGlyph.edit, color: AppColors.textDark, size: 17),
                      onTap: _showEditProfileSheet,
                    ),
                  ),
                  Positioned(
                    top: 100,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(colors: AppColors.accentGradient),
                          boxShadow: [
                            BoxShadow(color: AppColors.accent.withOpacity(0.4), blurRadius: 20, spreadRadius: 2),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 54,
                          backgroundColor: AppColors.cardAlt,
                          backgroundImage: _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
                          child: _avatarBytes == null
                              ? Text(
                            _initials,
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.accentSoft),
                          )
                              : null,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 190,
                    left: MediaQuery.of(context).size.width / 2 + 30,
                    child: GlassIconButton(
                      size: 36,
                      fill: AppColors.glassFillStrong,
                      icon: const AppIcon(AppGlyph.camera, size: 16, color: AppColors.textDark),
                      onTap: _showPhotoOptions,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 64),
              Text(_name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              const SizedBox(height: 4),
              Text(_title, style: const TextStyle(color: AppColors.accentSoft, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(_institution, style: const TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GlassSurface(
                  borderRadius: BorderRadius.circular(18),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatColumn(value: '${allLectures.length}', label: 'Lectures'),
                      _StatColumn(value: _totalStudyTime(allLectures), label: 'Content Time'),
                      _StatColumn(value: '${totalSummaryRequests(allLectures)}', label: 'Summaries'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recents',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 12),
                    if (recent.isEmpty)
                      const Text('No chats yet.', style: TextStyle(color: AppColors.textMuted))
                    else
                      ...recent.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GlassCard(
                          borderRadius: BorderRadius.circular(14),
                          padding: const EdgeInsets.all(14),
                          onTap: () => widget.onLectureTap?.call(item),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: AppColors.glassFillStrong, borderRadius: BorderRadius.circular(10)),
                                child: const AppIcon(AppGlyph.addChat, color: AppColors.accentSoft, size: 15),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark, fontSize: 14)),
                                    const SizedBox(height: 2),
                                    Text('${item.duration} · ${item.formattedDate}',
                                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                  ],
                                ),
                              ),
                              const AppIcon(AppGlyph.chevronRight, color: AppColors.textMuted, size: 14),
                            ],
                          ),
                        ),
                      )),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _totalStudyTime(List<LectureItem> items) {
    int totalSeconds = 0;
    for (final item in items) {
      final parts = item.duration.split(':').map(int.parse).toList();
      if (parts.length == 3) {
        totalSeconds += parts[0] * 3600 + parts[1] * 60 + parts[2];
      } else if (parts.length == 2) {
        totalSeconds += parts[0] * 60 + parts[1];
      }
    }
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
  }
}

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _EditField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: const TextStyle(color: AppColors.textDark),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.glassFill,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _PhotoOptionTile extends StatelessWidget {
  final AppGlyph glyph;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PhotoOptionTile({
    required this.glyph,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: BorderRadius.circular(14),
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppColors.accentGradient),
              shape: BoxShape.circle,
            ),
            child: AppIcon(glyph, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
                Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          const AppIcon(AppGlyph.chevronRight, color: AppColors.textMuted, size: 14),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String value;
  final String label;

  const _StatColumn({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.accentSoft)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ],
    );
  }
}

/// Shared dark, blurred bottom-sheet backdrop (kept local to avoid a
/// cross-file dependency; identical styling to the one in home_screen.dart).
class _DarkSheet extends StatelessWidget {
  final Widget child;
  const _DarkSheet({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: GlassSurface(
        borderRadius: BorderRadius.zero,
        fill: AppColors.cardAlt.withOpacity(0.96),
        border: Colors.transparent,
        child: child,
      ),
    );
  }
}
