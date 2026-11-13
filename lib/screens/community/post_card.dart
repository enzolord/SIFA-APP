import 'package:flutter/material.dart';

import '../../models/community.dart';
import '../../services/community_store.dart';
import '../../theme/colors.dart';
import 'post_detail_screen.dart';
import '../../l10n/l10n.dart';

String timeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return tr("à l'instant");
  if (diff.inHours < 1) return trf('il y a {0} min', [diff.inMinutes]);
  if (diff.inDays < 1) return trf('il y a {0} h', [diff.inHours]);
  if (diff.inDays < 30) return trf('il y a {0} j', [diff.inDays]);
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class AuthorAvatar extends StatelessWidget {
  const AuthorAvatar(this.name, {super.key, this.size = 40});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    final official = name == 'Équipe SIFA';
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: official ? SifaColors.brand : SifaColors.brandSoft,
      child: official
          ? Icon(Icons.verified_rounded, color: Colors.white, size: size * 0.55)
          : Tx(initial, style: const TextStyle(color: SifaColors.brand, fontWeight: FontWeight.w700)),
    );
  }
}

class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post, this.showGroup = true});
  final Post post;
  final bool showGroup;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final store = CommunityStore.instance;
    final group = store.groupById(post.groupId);
    final liked = store.isLiked(post.id);
    final comments = store.commentsOf(post.id).length;
    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(settings: const RouteSettings(name: 'PostDetailScreen'), builder: (_) => PostDetailScreen(postId: post.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              AuthorAvatar(post.authorName),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Tx(post.authorName, style: t.titleSmall),
                  Tx(
                    showGroup ? '${tr(group.name)} · ${timeAgo(post.at)}' : timeAgo(post.at),
                    style: t.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ]),
              ),
              PostMenu(post: post),
            ]),
            const SizedBox(height: 12),
            Tx(post.title, style: t.titleMedium),
            const SizedBox(height: 8),
            if (post.hasVideo)
              const VideoPlaceholder()
            else
              Tx(post.body, style: t.bodyMedium, maxLines: 4, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            Row(children: [
              Chip(
                label: Tx(post.category.label),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
              const Spacer(),
              IconButton(
                tooltip: tr("J'aime"),
                onPressed: () => store.toggleLike(post.id),
                icon: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: liked ? SifaColors.danger : null),
              ),
              Row(children: [
                const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                const SizedBox(width: 4),
                Tx('$comments'),
                const SizedBox(width: 6),
              ]),
            ]),
          ]),
        ),
      ),
    );
  }
}

class VideoPlaceholder extends StatelessWidget {
  const VideoPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0E2F25), Color(0xFF0F6B4F)],
            ),
          ),
          child: const Center(
            child: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white24,
              child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
            ),
          ),
        ),
      ),
    );
  }
}

class PostMenu extends StatelessWidget {
  const PostMenu({super.key, required this.post, this.onDeleted});
  final Post post;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    final store = CommunityStore.instance;
    return PopupMenuButton<String>(
      tooltip: tr('Plus'),
      onSelected: (v) {
        if (v == 'report') {
          store.report(post.id);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Tx('Publication masquée sur cet appareil. Merci du signalement.')),
          );
          onDeleted?.call();
        } else if (v == 'delete') {
          store.deletePost(post.id);
          onDeleted?.call();
        }
      },
      itemBuilder: (_) => [
        if (post.mine)
          const PopupMenuItem(value: 'delete', child: Tx('Supprimer'))
        else
          const PopupMenuItem(value: 'report', child: Tx('Signaler')),
      ],
    );
  }
}
