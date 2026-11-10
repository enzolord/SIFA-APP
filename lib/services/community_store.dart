import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/community.dart';

/// Communauté : groupes, publications (vidéos de bonnes pratiques), commentaires.
///
/// POUR L'INSTANT LOCAL À L'APPAREIL : les publications créées ici ne sont visibles que sur ce
/// téléphone. Le partage réel entre éleveurs viendra avec la synchronisation (serveur, stockage
/// vidéo, modération). Les conseils « Équipe SIFA » sont des contenus de départ.
class CommunityStore extends ChangeNotifier {
  CommunityStore._();
  static final instance = CommunityStore._();

  static const groups = <CommunityGroup>[
    CommunityGroup(
      id: 'debuter',
      name: 'Débuter en élevage',
      description: 'Les bases pour bien démarrer : bâtiment, achat des poussins, premiers soins.',
      icon: Icons.school_rounded,
    ),
    CommunityGroup(
      id: 'chair',
      name: 'Poulets de chair',
      description: 'Croissance, indice de consommation, mortalité, vente à 35–45 jours.',
      icon: Icons.restaurant_rounded,
    ),
    CommunityGroup(
      id: 'pondeuses',
      name: 'Poules pondeuses',
      description: 'Ponte, qualité des œufs, lumière, calcium, réforme.',
      icon: Icons.egg_alt_rounded,
    ),
    CommunityGroup(
      id: 'vaccin',
      name: 'Vaccination et prophylaxie',
      description: 'Calendrier, conservation des vaccins, rappels.',
      icon: Icons.vaccines_rounded,
    ),
    CommunityGroup(
      id: 'bio',
      name: 'Biosécurité et hygiène',
      description: 'Pédiluve, désinfection, vide sanitaire, gestion des visiteurs.',
      icon: Icons.clean_hands_rounded,
    ),
    CommunityGroup(
      id: 'alim',
      name: 'Alimentation et eau',
      description: 'Rations, stockage de l’aliment, qualité de l’eau, abreuvoirs.',
      icon: Icons.water_drop_rounded,
    ),
  ];

  static final _seed = <Post>[
    Post(
      id: 's1',
      groupId: 'debuter',
      authorName: 'Équipe SIFA',
      title: 'Contrôlez les fientes chaque matin',
      body: 'Passez dans le bâtiment tôt le matin et regardez la couleur, la consistance et la '
          'quantité des fientes. De la diarrhée, du sang, des fientes très vertes ou blanches '
          'méritent une photo dans SIFA et un appel à votre vétérinaire.',
      category: PostCategory.sante,
      at: DateTime(2026, 10, 12),
    ),
    Post(
      id: 's2',
      groupId: 'bio',
      authorName: 'Équipe SIFA',
      title: 'Bottes et pédiluve entre deux bâtiments',
      body: 'Gardez une paire de bottes par bâtiment, ou nettoyez-les et passez-les dans un '
          'pédiluve avec désinfectant. Renouvelez le produit souvent : il perd son efficacité '
          'quand il est sale. Limitez les visites et notez qui entre dans l’élevage.',
      category: PostCategory.biosecurite,
      at: DateTime(2026, 10, 14),
    ),
    Post(
      id: 's3',
      groupId: 'alim',
      authorName: 'Équipe SIFA',
      title: 'Une eau propre, c’est la base',
      body: 'Nettoyez les abreuvoirs tous les jours, vérifiez qu’ils coulent bien et évitez '
          'l’eau stagnante au soleil. Une baisse de consommation d’eau est souvent le premier '
          'signe d’un problème dans la bande.',
      category: PostCategory.alimentation,
      at: DateTime(2026, 10, 16),
    ),
    Post(
      id: 's4',
      groupId: 'chair',
      authorName: 'Équipe SIFA',
      title: 'Litière sèche, moins de coccidiose',
      body: 'L’humidité favorise la coccidiose. Retirez les zones mouillées autour des '
          'abreuvoirs, retournez la litière, assurez une bonne ventilation et évitez de trop '
          'charger le bâtiment.',
      category: PostCategory.batiment,
      at: DateTime(2026, 10, 18),
    ),
    Post(
      id: 's5',
      groupId: 'vaccin',
      authorName: 'Équipe SIFA',
      title: 'Suivez le calendrier de vaccination',
      body: 'Faites établir votre calendrier avec un vétérinaire, notez chaque date dans SIFA '
          'et gardez les vaccins au frais jusqu’à l’utilisation. En cas de doute sur un oiseau '
          'malade, demandez conseil avant de vacciner.',
      category: PostCategory.vaccination,
      at: DateTime(2026, 10, 20),
    ),
  ];

  final List<Post> _mine = [];
  final Set<String> _joined = {};
  final Set<String> _liked = {};
  final Set<String> _reported = {};
  final Map<String, List<Comment>> _comments = {};

  CommunityGroup groupById(String id) =>
      groups.firstWhere((g) => g.id == id, orElse: () => groups.first);

  Post? byId(String id) {
    for (final p in [..._mine, ..._seed]) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Publications visibles, de la plus récente à la plus ancienne.
  List<Post> feed({String? groupId, PostCategory? category}) {
    final all = [..._mine, ..._seed]
        .where((p) => !_reported.contains(p.id))
        .where((p) => groupId == null || p.groupId == groupId)
        .where((p) => category == null || p.category == category)
        .toList()
      ..sort((a, b) => b.at.compareTo(a.at));
    return all;
  }

  bool isJoined(String groupId) => _joined.contains(groupId);
  bool isLiked(String postId) => _liked.contains(postId);
  int likeCount(String postId) => _liked.contains(postId) ? 1 : 0;
  List<Comment> commentsOf(String postId) => List.unmodifiable(_comments[postId] ?? const []);

  void toggleJoin(String groupId) {
    if (!_joined.remove(groupId)) _joined.add(groupId);
    notifyListeners();
  }

  void toggleLike(String postId) {
    if (!_liked.remove(postId)) _liked.add(postId);
    notifyListeners();
  }

  void report(String postId) {
    _reported.add(postId);
    notifyListeners();
  }

  void addComment(String postId, String author, String text) {
    final list = _comments.putIfAbsent(postId, () => []);
    list.add(Comment(id: DateTime.now().microsecondsSinceEpoch.toString(), authorName: author, text: text));
    notifyListeners();
  }

  void addPost(Post p) {
    _mine.add(p);
    _joined.add(p.groupId);
    notifyListeners();
  }

  void deletePost(String postId) {
    final i = _mine.indexWhere((p) => p.id == postId);
    if (i < 0) return;
    final path = _mine[i].videoPath;
    _mine.removeAt(i);
    _comments.remove(postId);
    if (path != null) {
      try {
        File(path).deleteSync();
      } catch (_) {/* fichier déjà absent */}
    }
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
        'mine': [for (final p in _mine) p.toJson()],
        'joined': _joined.toList(),
        'liked': _liked.toList(),
        'reported': _reported.toList(),
        'comments': {
          for (final e in _comments.entries) e.key: [for (final c in e.value) c.toJson()],
        },
      };

  void restore(Map<String, dynamic> j) {
    _mine
      ..clear()
      ..addAll([
        for (final x in (j['mine'] as List<dynamic>? ?? const []))
          Post.fromJson(Map<String, dynamic>.from(x as Map)),
      ]);
    _joined
      ..clear()
      ..addAll((j['joined'] as List<dynamic>? ?? const []).cast<String>());
    _liked
      ..clear()
      ..addAll((j['liked'] as List<dynamic>? ?? const []).cast<String>());
    _reported
      ..clear()
      ..addAll((j['reported'] as List<dynamic>? ?? const []).cast<String>());
    _comments.clear();
    final cm = j['comments'] as Map<String, dynamic>? ?? const {};
    for (final e in cm.entries) {
      _comments[e.key] = [
        for (final c in (e.value as List<dynamic>)) Comment.fromJson(Map<String, dynamic>.from(c as Map)),
      ];
    }
    notifyListeners();
  }
}
