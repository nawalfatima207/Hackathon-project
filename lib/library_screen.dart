import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'conversation_store.dart';

class LectureItem {
  final String? documentId;
  final String title;
  final String? summary;
  final int summaryRequestCount;
  final List<Map<String, dynamic>> messages;
  final String duration;
  final DateTime savedAt;
  final Color tagColor;

  LectureItem({
    this.documentId,
    required this.title,
    required this.summary,
    this.summaryRequestCount = 0,
    required this.messages,
    required this.duration,
    required this.savedAt,
    required this.tagColor,
  });

  String get shortSummary {
    if (summary == null || summary!.isEmpty) {
      return 'No summary requested for this chat.';
    }

    return summary!.length > 80
        ? '${summary!.substring(0, 80)}...'
        : summary!;
  }

  String get formattedDate {
    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final saved = DateTime(
      savedAt.year,
      savedAt.month,
      savedAt.day,
    );

    final diff = today.difference(saved).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    return '${saved.day} ${months[saved.month - 1]}';
  }
}

class LibraryScreen extends StatefulWidget {
  final void Function(LectureItem item)? onLectureTap;

  const LibraryScreen({super.key, this.onLectureTap});

  @override
  State<LibraryScreen> createState() => LibraryScreenState();
}

class LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();

    ConversationStore.instance.addListener(
      _onStoreChanged,
    );

    ConversationStore.instance.refresh();
  }

  @override
  void dispose() {
    ConversationStore.instance.removeListener(_onStoreChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  List<LectureItem> get _filtered {
    final all = ConversationStore.instance.all;
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all.where((l) => l.title.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('YOUR LECTURES', style: TextStyle(color: AppColors.textMuted, fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text('Library', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search lectures...',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No lectures found.', style: TextStyle(color: AppColors.textMuted)))
                  : ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  return _LectureCard(
                    item: item,
                    lectureNumber: index + 1,
                    onTap: () => widget.onLectureTap?.call(item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _LectureCard extends StatelessWidget {
  final LectureItem item;
  final int lectureNumber;
  final VoidCallback onTap;

  const _LectureCard({
    required this.item,
    required this.lectureNumber,
    required this.onTap,
  });

  Future<void> _deleteConversation(BuildContext context) async {
    if (item.documentId == null) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete conversation?'),
          content: const Text(
            'This conversation will be permanently removed from your library.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      await ConversationStore.instance.delete(item.documentId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // TOP ROW
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: item.tagColor,
                      shape: BoxShape.circle,
                    ),
                  ),

                  const SizedBox(width: 8),

                  Text(
                    'Lecture $lectureNumber',
                    style: TextStyle(
                      color: item.tagColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),

                  const SizedBox(width: 8),

                  Text(
                    '· ${item.formattedDate}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),

                  const Spacer(),

                  // DELETE BUTTON
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    tooltip: 'Delete',
                    onPressed: () => _deleteConversation(context),
                  ),

                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Text(
                item.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.textDark,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                item.shortSummary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),

              const Divider(height: 20),

              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 14,
                    color: AppColors.textMuted,
                  ),

                  const SizedBox(width: 4),

                  Text(
                    item.duration,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
