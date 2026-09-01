import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// حول (م-33): الإصدار، المطور، الإبلاغ عن خلل، التراخيص، إخلاء المسؤولية.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String _github = 'https://github.com/sagheerys';
  static const String _x = 'https://x.com/Sagheer700';

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.about)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            MTSpace.pagePad, 0, MTSpace.pagePad, MTSpace.xxl),
        children: [
          const SizedBox(height: MTSpace.lg),
          Center(
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: p.accentSoft,
                    borderRadius: BorderRadius.circular(MTRadius.cardLg),
                  ),
                  child: Icon(Icons.video_library_rounded,
                      color: p.accentInk, size: 30),
                ),
                const SizedBox(height: MTSpace.md),
                Text(l10n.appTitle, style: text.headlineMedium),
                const SizedBox(height: MTSpace.xxs),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) => Text(
                    snapshot.hasData
                        ? '${l10n.version} '
                            '${snapshot.data!.version}+'
                            '${snapshot.data!.buildNumber}'
                        : '',
                    style: text.bodySmall!.copyWith(color: p.ink3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MTSpace.xxl),
          MTSectionHeader(title: l10n.developer),
          _LinkTile(
            icon: Icons.code_rounded,
            title: l10n.developerName,
            subtitle: 'github.com/sagheerys',
            url: _github,
          ),
          _LinkTile(
            icon: Icons.alternate_email_rounded,
            title: 'X',
            subtitle: 'x.com/Sagheer700',
            url: _x,
          ),
          _LinkTile(
            icon: Icons.bug_report_outlined,
            title: l10n.reportBug,
            subtitle: 'github.com/sagheerys',
            url: _github,
          ),
          const SizedBox(height: MTSpace.xl),
          MTSectionHeader(title: l10n.licenses),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.description_outlined, color: p.ink2),
            title: Text(l10n.licenses),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showLicensePage(
              context: context,
              applicationName: l10n.appTitle,
            ),
          ),
          const SizedBox(height: MTSpace.xl),
          MTSectionHeader(title: l10n.disclaimer),
          const SizedBox(height: MTSpace.sm),
          Text(l10n.disclaimerText,
              style: text.bodySmall!.copyWith(color: p.ink2)),
          const SizedBox(height: MTSpace.xl),
          Center(
            child: Text(l10n.allRightsReserved,
                style: text.labelSmall!.copyWith(color: p.ink3)),
          ),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.url,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String url;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: p.ink2),
      title: Text(title),
      subtitle: Text(subtitle,
          textDirection: TextDirection.ltr,
          style: Theme.of(context).textTheme.bodySmall),
      trailing: const Icon(Icons.open_in_new_rounded, size: 17),
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
    );
  }
}
