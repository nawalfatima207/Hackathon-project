import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'app_colors.dart';
import 'conversation_store.dart';
import 'library_screen.dart';

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


  String get _initials {
    final parts = _name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  void initState() {
    super.initState();
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
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
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
                  icon: Icons.camera_alt,
                  iconBg: AppColors.accent,
                  title: 'Take a Photo',
                  subtitle: 'Use your camera',
                  onTap: () => _pickImage(ImageSource.camera),
                ),
                const SizedBox(height: 12),
                _PhotoOptionTile(
                  icon: Icons.photo_library,
                  iconBg: Colors.orange,
                  title: 'Choose from Gallery',
                  subtitle: 'Pick an existing photo',
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
              ],
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
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
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
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    setState(() {
                      _name = nameController.text.trim().isEmpty ? _name : nameController.text.trim();
                      _title = titleController.text.trim().isEmpty ? _title : titleController.text.trim();
                      _institution = institutionController.text.trim().isEmpty ? _institution : institutionController.text.trim();
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final allLectures = ConversationStore.instance.all;
    final recent = ConversationStore.instance.recent;
    int _totalSummaryRequests(List<LectureItem> items) {
      return items.fold(0, (sum, item) => sum + item.summaryRequestCount);
    }
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 230,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.accent, AppColors.background],
                    ),
                  ),
                ),
                Positioned(
                  top: 20,
                  left: 56,
                  right: 60,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'YOUR ACCOUNT',
                        style: TextStyle(
                          color: Colors.white70,
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
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Material(
                    color: Colors.white.withOpacity(0.2),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _showEditProfileSheet,
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.edit, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 100,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: CircleAvatar(
                      radius: 56,
                      backgroundColor: AppColors.card,
                      backgroundImage: _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
                      child: _avatarBytes == null
                          ? Text(
                        _initials,
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.accent),
                      )
                          : null,
                    ),
                  ),
                ),
                Positioned(
                  top: 190,
                  left: MediaQuery.of(context).size.width / 2 + 30,
                  child: Material(
                    color: AppColors.accent,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _showPhotoOptions,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.background, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 64),
            Text(_name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            const SizedBox(height: 4),
            Text(_title, style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(_institution, style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child:Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatColumn(value: '${allLectures.length}', label: 'Lectures'),
                    _StatColumn(value: _totalStudyTime(allLectures), label: 'Content Time'),
                    _StatColumn(value: '${_totalSummaryRequests(allLectures)}', label: 'Summaries'),
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
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => widget.onLectureTap?.call(item),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.replay, color: AppColors.accent, size: 18),
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
                                const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
                              ],
                            ),
                          ),
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
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _PhotoOptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PhotoOptionTile({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.textMuted.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 20),
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
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
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
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.accent)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ],
    );
  }
}