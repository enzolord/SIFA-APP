import 'package:flutter/material.dart';

enum PostCategory { sante, vaccination, alimentation, biosecurite, batiment, autre }

extension PostCategoryLabel on PostCategory {
  String get label => switch (this) {
        PostCategory.sante => 'Santé',
        PostCategory.vaccination => 'Vaccination',
        PostCategory.alimentation => 'Alimentation',
        PostCategory.biosecurite => 'Biosécurité',
        PostCategory.batiment => 'Bâtiment',
        PostCategory.autre => 'Autre',
      };
}

class CommunityGroup {
  const CommunityGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
  });
  final String id, name, description;
  final IconData icon;
}

class Comment {
  Comment({required this.id, required this.authorName, required this.text, DateTime? at})
      : at = at ?? DateTime.now();
  final String id, authorName, text;
  final DateTime at;

  Map<String, dynamic> toJson() => {'id': id, 'a': authorName, 't': text, 'at': at.toIso8601String()};

  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
        id: j['id'] as String,
        authorName: j['a'] as String? ?? '',
        text: j['t'] as String? ?? '',
        at: DateTime.tryParse(j['at'] as String? ?? ''),
      );
}

class Post {
  Post({
    required this.id,
    required this.groupId,
    required this.authorName,
    required this.title,
    required this.body,
    required this.category,
    required this.at,
    this.videoPath,
    this.mine = false,
  });

  final String id, groupId, authorName, title, body;
  final PostCategory category;
  final DateTime at;
  final String? videoPath;
  final bool mine;

  bool get hasVideo => videoPath != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'g': groupId,
        'a': authorName,
        'ti': title,
        'b': body,
        'c': category.index,
        'at': at.toIso8601String(),
        'v': videoPath,
      };

  factory Post.fromJson(Map<String, dynamic> j) => Post(
        id: j['id'] as String,
        groupId: j['g'] as String,
        authorName: j['a'] as String? ?? '',
        title: j['ti'] as String? ?? '',
        body: j['b'] as String? ?? '',
        category: PostCategory.values[(j['c'] as int? ?? 0).clamp(0, PostCategory.values.length - 1)],
        at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
        videoPath: j['v'] as String?,
        mine: true,
      );
}
