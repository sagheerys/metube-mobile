import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// About: the version, the developer, the project, what it is built on,
/// and the disclaimer.
///
/// **Updated 2026-09-09 with the open-sourcing**: the screen used to say
/// "all rights reserved", which is the literal opposite of GPL-3.0, and
/// named neither the licence nor the absence of any affiliation with the
/// MeTube project. The licence expects the user to find the copyright
/// notice and the warranty disclaimer **inside the program**, not in the
/// repository alone.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String _github = 'https://github.com/sagheerys';
  static const String _x = 'https://x.com/Sagheer700';
  static const String _repo = 'https://github.com/sagheerys/metube-mobile';
  static const String _issues = '$_repo/issues';
  static const String _metube = 'https://github.com/alexta69/metube';
  static const String _ytdlp = 'https://github.com/yt-dlp/yt-dlp';

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.about)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          MTSpace.pagePad,
          0,
          MTSpace.pagePad,
          MTSpace.xxl,
        ),
        children: [
          const SizedBox(height: MTSpace.lg),
          Center(
            child: Column(
              children: [
                // **The app's own icon**, not a generic glyph: the screen
                // that introduces the app is the first place its face
                // should appear.
                Image.asset(
                  'assets/icons/icon.png',
                  width: 76,
                  height: 76,
                  cacheWidth: (76 * MediaQuery.devicePixelRatioOf(context))
                      .round(),
                ),
                const SizedBox(height: MTSpace.md),
                Text(l10n.appTitle, style: text.headlineMedium),
                const SizedBox(height: MTSpace.xxs),
                // **Without the build number**: `2.0.0+1` is Flutter's
                // notation, and `+1` is an internal Android counter that
                // means nothing to the user (field report).
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) => Text(
                    snapshot.hasData
                        ? '${l10n.version} ${snapshot.data!.version}'
                        : '',
                    style: text.bodySmall!.copyWith(color: p.ink3),
                  ),
                ),
                const SizedBox(height: MTSpace.xxs),
                Text(
                  l10n.licensedUnder,
                  style: text.labelSmall!.copyWith(color: p.ink3),
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
            subtitle: 'metube-mobile/issues',
            url: _issues,
          ),
          const SizedBox(height: MTSpace.xl),
          MTSectionHeader(title: l10n.sourceCode),
          _LinkTile(
            icon: Icons.folder_open_rounded,
            title: l10n.sourceCode,
            subtitle: 'sagheerys/metube-mobile',
            url: _repo,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.description_outlined, color: p.ink2),
            title: Text(l10n.licenses),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showLicensePage(
              context: context,
              applicationName: l10n.appTitle,
              // The licences page lists the packages alone; the app's own
              // licence is passed here, or it would appear nowhere at all.
              applicationLegalese: '${l10n.copyright}\n${l10n.licensedUnder}',
            ),
          ),
          const SizedBox(height: MTSpace.xl),
          MTSectionHeader(title: l10n.builtWith),
          _LinkTile(
            icon: Icons.dns_outlined,
            title: 'MeTube',
            subtitle: l10n.metubeCredit,
            url: _metube,
            ltrSubtitle: false,
          ),
          _LinkTile(
            icon: Icons.download_for_offline_outlined,
            title: 'yt-dlp',
            subtitle: l10n.ytdlpCredit,
            url: _ytdlp,
            ltrSubtitle: false,
          ),
          const SizedBox(height: MTSpace.xl),
          MTSectionHeader(title: l10n.disclaimer),
          const SizedBox(height: MTSpace.sm),
          // The disclaimer of affiliation comes first: the name says what
          // the app connects to, not who made it.
          Text(
            l10n.notAffiliated,
            style: text.bodySmall!.copyWith(
              color: p.ink2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: MTSpace.sm),
          Text(
            l10n.disclaimerText,
            style: text.bodySmall!.copyWith(color: p.ink2),
          ),
          const SizedBox(height: MTSpace.sm),
          Text(l10n.noWarranty, style: text.bodySmall!.copyWith(color: p.ink3)),
          const SizedBox(height: MTSpace.xl),
          Center(
            child: Text(
              l10n.copyright,
              style: text.labelSmall!.copyWith(color: p.ink3),
            ),
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
    this.ltrSubtitle = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String url;

  /// URLs are isolated as LTR so their parts do not reverse in Arabic,
  /// while a translated description follows the language's direction.
  final bool ltrSubtitle;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: p.ink2),
      title: Text(title),
      subtitle: Text(
        subtitle,
        textDirection: ltrSubtitle ? TextDirection.ltr : null,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: const Icon(Icons.open_in_new_rounded, size: 17),
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
    );
  }
}
