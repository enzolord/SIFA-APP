import 'package:flutter/material.dart';

import '../../services/community_store.dart';
import '../../theme/colors.dart';
import 'new_post_screen.dart';
import 'post_card.dart';
import '../../l10n/l10n.dart';

class GroupDetailScreen extends StatelessWidget {
  const GroupDetailScreen({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final store = CommunityStore.instance;
    final g = store.groupById(groupId);
    return Scaffold(
      appBar: AppBar(title: Tx(g.name)),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final joined = store.isJoined(g.id);
          final posts = store.feed(groupId: g.id);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: SifaColors.brandSoft,
                  child: Icon(g.icon, color: SifaColors.brand, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(child: Tx(g.description, style: t.bodyLarge)),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: joined
                      ? OutlinedButton.icon(
                          onPressed: () => store.toggleJoin(g.id),
                          icon: const Icon(Icons.check_rounded),
                          label: const Tx('Membre'),
                        )
                      : FilledButton.icon(
                          onPressed: () => store.toggleJoin(g.id),
                          icon: const Icon(Icons.add_rounded),
                          label: const Tx('Rejoindre'),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(settings: const RouteSettings(name: 'NewPostScreen'), builder: (_) => NewPostScreen(groupId: g.id)),
                    ),
                    icon: const Icon(Icons.videocam_rounded),
                    label: const Tx('Publier'),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              if (posts.isEmpty)
                Tx('Aucune publication pour le moment. Lancez la discussion !', style: t.bodyMedium),
              for (final p in posts) ...[
                PostCard(post: p, showGroup: false),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}
