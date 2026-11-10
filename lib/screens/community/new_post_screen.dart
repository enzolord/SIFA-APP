import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/community.dart';
import '../../services/community_store.dart';
import '../../services/persistence.dart';
import '../../theme/colors.dart';
import 'post_detail_screen.dart';

const _maxVideoBytes = 60 * 1024 * 1024;

class NewPostScreen extends StatefulWidget {
  const NewPostScreen({super.key, this.groupId});
  final String? groupId;

  @override
  State<NewPostScreen> createState() => _NewPostScreenState();
}

class _NewPostScreenState extends State<NewPostScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _picker = ImagePicker();
  late String _group = widget.groupId ?? CommunityStore.groups.first.id;
  PostCategory _category = PostCategory.sante;
  String? _videoPath;
  int _videoBytes = 0;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final f = await _picker.pickVideo(source: source, maxDuration: const Duration(seconds: 90));
      if (f == null) return;
      final size = await File(f.path).length();
      if (size > _maxVideoBytes) {
        setState(() => _error = 'Vidéo trop lourde (max 60 Mo). Choisissez une vidéo plus courte.');
        return;
      }
      setState(() {
        _videoPath = f.path;
        _videoBytes = size;
        _error = null;
      });
    } catch (_) {
      setState(() => _error = "Impossible d'ouvrir la vidéo. Réessayez.");
    }
  }

  Future<void> _publish() async {
    final title = _title.text.trim();
    if (title.length < 4) {
      setState(() => _error = 'Donnez un titre (au moins 4 caractères).');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    String? saved;
    if (_videoPath != null) {
      saved = await Persistence.saveVideo(_videoPath!);
      if (saved == null) {
        if (mounted) setState(() {
          _busy = false;
          _error = "La vidéo n'a pas pu être enregistrée. Réessayez.";
        });
        return;
      }
    }
    CommunityStore.instance.addPost(Post(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      groupId: _group,
      authorName: myName(),
      title: title,
      body: _body.text.trim(),
      category: _category,
      at: DateTime.now(),
      videoPath: saved,
      mine: true,
    ));
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Publié dans le groupe.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Partager une bonne pratique')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Vidéo (facultative)', style: t.titleSmall),
          const SizedBox(height: 8),
          if (_videoPath == null)
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                  onPressed: () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.videocam_rounded),
                  label: const Text('Filmer'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                  onPressed: () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.video_library_rounded),
                  label: const Text('Galerie'),
                ),
              ),
            ])
          else
            Card(
              child: ListTile(
                leading: const Icon(Icons.movie_rounded, color: SifaColors.brand),
                title: const Text('Vidéo ajoutée'),
                subtitle: Text('${(_videoBytes / (1024 * 1024)).toStringAsFixed(1)} Mo'),
                trailing: IconButton(
                  tooltip: 'Retirer',
                  onPressed: () => setState(() => _videoPath = null),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ),
          const SizedBox(height: 4),
          Text('90 secondes maximum, 60 Mo maximum.', style: t.bodySmall),
          const SizedBox(height: 20),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Titre', hintText: 'Ex. : Comment je nettoie mes abreuvoirs'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            textCapitalization: TextCapitalization.sentences,
            minLines: 3,
            maxLines: 6,
            maxLength: 600,
            decoration: const InputDecoration(labelText: 'Explication', alignLabelWithHint: true),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _group,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Groupe'),
            items: [
              for (final g in CommunityStore.groups) DropdownMenuItem(value: g.id, child: Text(g.name)),
            ],
            onChanged: (v) => setState(() => _group = v ?? _group),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<PostCategory>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Thème'),
            items: [
              for (final c in PostCategory.values) DropdownMenuItem(value: c, child: Text(c.label)),
            ],
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: SifaColors.yolkSoft, borderRadius: BorderRadius.circular(12)),
            child: const Text(
              'Partagez ce que vous faites vraiment dans votre élevage. Pas de publicité, '
              "pas d'insultes, pas de conseils de médicaments sans avis vétérinaire.",
              style: TextStyle(color: SifaColors.ink, fontSize: 14, height: 1.4),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: t.bodyMedium?.copyWith(color: SifaColors.danger)),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 54)),
            onPressed: _busy ? null : _publish,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_rounded),
            label: const Text('Publier'),
          ),
        ],
      ),
    );
  }
}
