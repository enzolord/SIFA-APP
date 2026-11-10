import 'package:flutter/material.dart';

import '../../models/community.dart';
import '../../services/community_store.dart';
import '../../services/session.dart';
import '../../theme/colors.dart';
import 'post_card.dart';
import 'video_box.dart';
import '../../l10n/l10n.dart';

String myName() {
  final n = Session.instance.farmName.trim();
  return n.isEmpty ? tr('Éleveur') : n;
}

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.postId});
  final String postId;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    CommunityStore.instance.addComment(widget.postId, myName(), text);
    _ctrl.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final store = CommunityStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = store.byId(widget.postId);
        if (p == null || store.feed().every((x) => x.id != p.id)) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Tx('Cette publication n’est plus disponible.')),
          );
        }
        final group = store.groupById(p.groupId);
        final comments = store.commentsOf(p.id);
        final liked = store.isLiked(p.id);
        return Scaffold(
          appBar: AppBar(
            title: Tx(group.name, style: t.titleMedium),
            actions: [PostMenu(post: p, onDeleted: () => Navigator.of(context).maybePop())],
          ),
          body: Column(children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Row(children: [
                    AuthorAvatar(p.authorName, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Tx(p.authorName, style: t.titleSmall),
                        Tx(timeAgo(p.at), style: t.bodySmall),
                      ]),
                    ),
                    Chip(label: Tx(p.category.label), visualDensity: VisualDensity.compact),
                  ]),
                  const SizedBox(height: 16),
                  Tx(p.title, style: t.headlineSmall),
                  const SizedBox(height: 12),
                  if (p.videoPath != null) ...[
                    VideoBox(path: p.videoPath!),
                    const SizedBox(height: 12),
                  ],
                  if (p.body.isNotEmpty) Tx(p.body, style: t.bodyLarge),
                  const SizedBox(height: 12),
                  Row(children: [
                    FilledButton.tonalIcon(
                      onPressed: () => store.toggleLike(p.id),
                      icon: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: liked ? SifaColors.danger : null),
                      label: Tx(liked ? 'Utile' : "J'aime"),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  Tx(trf('Commentaires ({0})', [comments.length]), style: t.titleMedium),
                  const SizedBox(height: 8),
                  if (comments.isEmpty)
                    Tx('Soyez le premier à répondre ou à partager votre expérience.', style: t.bodyMedium),
                  for (final c in comments)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        AuthorAvatar(c.authorName, size: 34),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: SifaColors.surfaceSunken,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Tx('${c.authorName} · ${timeAgo(c.at)}',
                                  style: t.bodySmall?.copyWith(color: SifaColors.ink)),
                              const SizedBox(height: 2),
                              Tx(c.text, style: t.bodyMedium?.copyWith(color: SifaColors.ink)),
                            ]),
                          ),
                        ),
                      ]),
                    ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(hintText: tr('Écrire un commentaire…')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    tooltip: tr('Envoyer'),
                    icon: const Icon(Icons.send_rounded),
                  ),
                ]),
              ),
            ),
          ]),
        );
      },
    );
  }
}
