import 'package:flutter/material.dart';

import '../../models/community.dart';
import '../../services/community_store.dart';
import '../../theme/colors.dart';
import 'group_detail_screen.dart';
import 'new_post_screen.dart';
import 'post_card.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
          child: Row(children: [
            Expanded(child: Text('Communauté', style: t.headlineMedium)),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const NewPostScreen()),
              ),
              icon: const Icon(Icons.videocam_rounded),
              label: const Text('Partager'),
            ),
          ]),
        ),
        const TabBar(tabs: [Tab(text: 'Fil'), Tab(text: 'Groupes')]),
        const Expanded(child: TabBarView(children: [_FeedTab(), _GroupsTab()])),
      ]),
    );
  }
}

class _FeedTab extends StatefulWidget {
  const _FeedTab();

  @override
  State<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<_FeedTab> {
  PostCategory? _cat;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: CommunityStore.instance,
      builder: (context, _) {
        final posts = CommunityStore.instance.feed(category: _cat);
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            SizedBox(
              height: 44,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('Tout'),
                    selected: _cat == null,
                    onSelected: (_) => setState(() => _cat = null),
                  ),
                ),
                for (final c in PostCategory.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c.label),
                      selected: _cat == c,
                      onSelected: (_) => setState(() => _cat = c),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
            if (posts.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Text('Aucune publication dans ce thème.', style: t.bodyMedium, textAlign: TextAlign.center),
              ),
            for (final p in posts) ...[
              PostCard(post: p),
              const SizedBox(height: 12),
            ],
            const _LocalNote(),
          ],
        );
      },
    );
  }
}

class _GroupsTab extends StatelessWidget {
  const _GroupsTab();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final store = CommunityStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text('Rejoignez les groupes qui vous concernent pour échanger avec d’autres éleveurs.', style: t.bodyMedium),
          const SizedBox(height: 12),
          for (final g in CommunityStore.groups) ...[
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: SifaColors.brandSoft,
                  child: Icon(g.icon, color: SifaColors.brand),
                ),
                title: Text(g.name, style: t.titleSmall),
                subtitle: Text(g.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: store.isJoined(g.id)
                    ? const Icon(Icons.check_circle_rounded, color: SifaColors.ok)
                    : const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => GroupDetailScreen(groupId: g.id)),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          const _LocalNote(),
        ],
      ),
    );
  }
}

class _LocalNote extends StatelessWidget {
  const _LocalNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        'Version de démarrage : vos publications restent pour l’instant sur ce téléphone. '
        'Le partage entre éleveurs arrive avec la synchronisation.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
      ),
    );
  }
}
