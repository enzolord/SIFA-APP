import 'package:flutter/material.dart';

import '../services/analysis_store.dart';
import '../services/community_store.dart';
import '../services/nav.dart';
import '../services/session.dart';
import '../theme/colors.dart';
import '../widgets/disclaimer.dart';
import '../widgets/section_header.dart';
import '../widgets/sifa_mark.dart';
import '../widgets/status_chip.dart';
import 'community/post_detail_screen.dart';
import 'ferme/ferme_hub.dart';
import 'pharmacie_screen.dart';
import 'prophylaxie_screen.dart';
import 'result_screen.dart';
import 'tips_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final farm = Session.instance.farmName;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(children: [
          const SifaIcon(size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(farm.isEmpty ? 'Bonjour 👋' : 'Bonjour, $farm 👋', style: t.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(Session.instance.flockType.label, style: t.bodySmall),
            ]),
          ),
        ]),
        const SizedBox(height: 20),
        _ScanHero(onScan: () => AppNav.go(AppNav.scan)),
        const SectionHeader('Mes services'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: [
            _ServiceTile('Ma ferme', 'Bandes, stocks, finances', Icons.agriculture_rounded, SifaColors.brand,
                () => _push(context, const FermeHub())),
            _ServiceTile('Vaccins', 'Calendrier de prophylaxie', Icons.vaccines_rounded, const Color(0xFF2F6FB5),
                () => _push(context, const ProphylaxieScreen())),
            _ServiceTile('Pharmacies', 'Carte et itinéraire', Icons.local_pharmacy_rounded, const Color(0xFFB5532F),
                () => _push(context, const PharmacieScreen())),
            _ServiceTile('Conseils', 'Bons réflexes d’élevage', Icons.menu_book_rounded, const Color(0xFF8A6A00),
                () => _push(context, const TipsScreen())),
          ],
        ),
        const SectionHeader('Dernière analyse'),
        ListenableBuilder(
          listenable: AnalysisStore.instance,
          builder: (context, _) {
            final d = AnalysisStore.instance.last;
            if (d == null) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(children: [
                    const Icon(Icons.center_focus_strong_outlined, size: 32, color: SifaColors.inkMuted),
                    const SizedBox(width: 14),
                    Expanded(child: Text('Aucune analyse pour le moment. Touchez le bouton Scanner pour commencer.', style: t.bodyMedium)),
                  ]),
                ),
              );
            }
            return Card(
              child: InkWell(
                onTap: () => _push(context, ResultScreen(diagnosis: d)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(d.photo, width: 64, height: 64, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d.info.name, style: t.titleSmall),
                        const SizedBox(height: 6),
                        StatusChip(d.info.status, 'Confiance ${(d.confidence * 100).round()} %'),
                      ]),
                    ),
                    const Icon(Icons.chevron_right),
                  ]),
                ),
              ),
            );
          },
        ),
        SectionHeader('Communauté', action: 'Voir tout', onAction: () => AppNav.go(AppNav.community)),
        ListenableBuilder(
          listenable: CommunityStore.instance,
          builder: (context, _) {
            final posts = CommunityStore.instance.feed().take(2).toList();
            return Column(children: [
              for (final p in posts) ...[
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: CircleAvatar(
                      backgroundColor: SifaColors.brandSoft,
                      child: Icon(p.hasVideo ? Icons.play_arrow_rounded : Icons.lightbulb_outline, color: SifaColors.brand),
                    ),
                    title: Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(p.authorName),
                    onTap: () => _push(context, PostDetailScreen(postId: p.id)),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ]);
          },
        ),
        const SizedBox(height: 12),
        const Disclaimer(),
      ],
    );
  }
}

class _ScanHero extends StatelessWidget {
  const _ScanHero({required this.onScan});
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 8, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E9A72), SifaColors.brand, Color(0xFF083D2E)],
        ),
        boxShadow: [BoxShadow(color: SifaColors.brand.withValues(alpha: 0.30), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Contrôlez la santé de votre bande',
                style: t.headlineSmall?.copyWith(color: Colors.white)),
            const SizedBox(height: 8),
            Text('Photographiez une fiente : SIFA vous donne un avis en quelques secondes.',
                style: t.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.88))),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: SifaColors.yolk,
                foregroundColor: SifaColors.onYolk,
                minimumSize: const Size(0, 52),
              ),
              onPressed: onScan,
              icon: const Icon(Icons.center_focus_strong_rounded),
              label: const Text('Scanner une fiente'),
            ),
          ]),
        ),
        const SizedBox(width: 4),
        const SifaMark(size: 104, onDark: true),
      ]),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile(this.title, this.subtitle, this.icon, this.color, this.onTap);
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: t.titleSmall),
              Text(subtitle, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ]),
        ),
      ),
    );
  }
}
