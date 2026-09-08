import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../shared/error_report.dart';
import 'widgets/help_button.dart';
import 'widgets/server_status_card.dart';

/// الإعدادات (م-27/م-29/م-30/م-34): بطاقة السيرفر أولاً، حول آخراً
/// (النموذج أ). Lite بلا «إدارة الروابط» — رابط واحد لسيرفر العائلة.
/// قيمة الشريحة التي تعني «لا لغة محفوظة» — لا تُخزَّن أبداً (م-50).

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final _urlController =
      TextEditingController(text: ref.read(settingsProvider).serverUrl);
  late final _userController =
      TextEditingController(text: ref.read(settingsProvider).username ?? '');
  late final _passController =
      TextEditingController(text: ref.read(settingsProvider).password ?? '');
  bool _testing = false;

  @override
  void dispose() {
    _urlController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _testAndSave() async {
    final l10n = context.mtl;
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      showMTSnack(context, l10n.serverUrlRequired, type: MTSnackType.error);
      return;
    }
    setState(() => _testing = true);
    try {
      // ر-1: لا حفظ صامت لإعداد فاسد — اختبار أولاً برسائل مصنفة.
      await ref.read(settingsProvider.notifier).saveServer(
            url: url,
            username: _userController.text.trim(),
            password: _passController.text,
          );
      ref.invalidate(serverStatusProvider);
      if (mounted) {
        showMTSnack(context, l10n.connectionSuccessful,
            type: MTSnackType.success);
      }
    } on MTApiException catch (e) {
      if (mounted) {
        showErrorSnack(context, ref, e, tag: 'server');
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: Theme.of(context).textTheme.bodyMedium),
        subtitle:
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        value: value,
        onChanged: onChanged,
      );

  ListTile _navTile(
          IconData icon, String title, String subtitle, String route) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(title),
        subtitle:
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.go(route),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            MTSpace.pagePad, 0, MTSpace.pagePad, 120),
        children: [
          const ServerStatusCard(),
          const SizedBox(height: MTSpace.xl),

          MTSectionHeader(title: l10n.serverConfiguration),
          const SizedBox(height: MTSpace.md),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: l10n.serverUrl,
                  hintText: l10n.serverUrlHint,
                ),
              ),
            ),
            HelpButton(
                title: l10n.serverUrlHelpTitle, body: l10n.serverUrlHelpBody),
          ]),
          const SizedBox(height: MTSpace.md),
          // **الفراغ بعرض زر المساعدة** (فحص 2026-09-05): بدونه يمتد
          // حقل اسم المستخدم وحده إلى الحافة، فتختلف حواف ثلاثة حقول
          // متتالية.
          Row(children: [
            Expanded(
              child: TextField(
                controller: _userController,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(labelText: l10n.username),
              ),
            ),
            const HelpButtonGap(),
          ]),
          const SizedBox(height: MTSpace.md),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _passController,
                obscureText: true,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(labelText: l10n.password),
              ),
            ),
            HelpButton(title: l10n.authentication, body: l10n.authHelper),
          ]),
          const SizedBox(height: MTSpace.lg),
          FilledButton.icon(
            onPressed: _testing ? null : _testAndSave,
            icon: _testing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.wifi_tethering_rounded, size: 18),
            label: Text(_testing ? l10n.testingConnection : l10n.saveSettings),
          ),
          const SizedBox(height: MTSpace.xl),

          MTSectionHeader(title: l10n.preferences),
          const SizedBox(height: MTSpace.md),
          Row(children: [
            Expanded(
              child: DropdownMenu<Quality>(
                initialSelection: settings.quality,
                label: Text(l10n.defaultQuality),
                expandedInsets: EdgeInsets.zero,
                dropdownMenuEntries: [
                  DropdownMenuEntry(
                      value: Quality.best, label: l10n.qualityBest),
                  DropdownMenuEntry(
                      value: Quality.q1080, label: l10n.quality1080),
                  DropdownMenuEntry(
                      value: Quality.q720, label: l10n.quality720),
                  DropdownMenuEntry(
                      value: Quality.q480, label: l10n.quality480),
                  DropdownMenuEntry(
                      value: Quality.audio, label: l10n.audioOnly),
                ],
                onSelected: (q) => q == null
                    ? null
                    : ref.read(settingsProvider.notifier).setQuality(q),
              ),
            ),
            HelpButton(title: l10n.defaultQuality, body: l10n.qualityHelper),
          ]),
          // **الجودة الافتراضية كانت إعداداً بلا أثر**: تُملأ في ورقة
          // الإضافة فيعيد المستخدم اختيارها كل مرة. مع «التحميل السريع»
          // تصير هي القرار فعلاً — والورقة تُتخطى كلياً.
          _switchTile(
            title: l10n.quickDownload,
            subtitle: l10n.quickDownloadHelp,
            value: settings.quickDownload,
            onChanged: ref.read(settingsProvider.notifier).setQuickDownload,
          ),
          _switchTile(
            title: l10n.wifiOnly,
            subtitle: l10n.wifiOnlyHelp,
            value: settings.wifiOnly,
            onChanged: ref.read(settingsProvider.notifier).setWifiOnly,
          ),
          _switchTile(
            title: l10n.autoRetry,
            subtitle: l10n.autoRetryHelp,
            value: settings.autoRetry,
            onChanged: ref.read(settingsProvider.notifier).setAutoRetry,
          ),
          _switchTile(
            title: l10n.compatiblePlayback,
            subtitle: l10n.compatiblePlaybackHelp,
            value: settings.compatiblePlayback,
            onChanged:
                ref.read(settingsProvider.notifier).setCompatiblePlayback,
          ),
          const SizedBox(height: MTSpace.lg),
          Text(l10n.theme, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: MTSpace.xs),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                  value: ThemeMode.system, label: Text(l10n.themeSystem)),
              ButtonSegment(
                  value: ThemeMode.light, label: Text(l10n.themeLight)),
              ButtonSegment(
                  value: ThemeMode.dark, label: Text(l10n.themeDark)),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (selection) => ref
                .read(settingsProvider.notifier)
                .setThemeMode(selection.first),
          ),
          const SizedBox(height: MTSpace.lg),
          Text(l10n.language, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: MTSpace.xs),
          // م-50: **«النظام» خيارٌ لا حالةٌ ضمنية.** كان الفراغ يعني
          // «اتبع الهاتف» فعلاً، لكن المبدّل يعرضه «العربية» — فيقرأ
          // صاحب الجهاز الإنجليزي واجهةً إنجليزية ومبدّلاً يقول عربية،
          // وأول لمسة تثبّت لغةً بلا رجعة.
          // **صفٌّ يفتح شاشة، لا زرٌّ مقسّم** (طلب المالك 2026-09-08):
          // `SegmentedButton` يقسم العرض على عدد الخيارات، فثلاثةٌ تسع
          // 360dp **وستةٌ تنكسر** — والخطة المعلنة دعم اللغات الشائعة.
          _navTile(
            Icons.translate_rounded,
            l10n.language,
            settings.localeCode == null
                ? l10n.languageSystem
                : mtLanguageName(settings.localeCode!),
            '/settings/language',
          ),
          const SizedBox(height: MTSpace.xl),

          // البيانات والتشخيص (م-31/م-32) ثم «حول» آخراً (النموذج أ).
          MTSectionHeader(title: l10n.backupSettings),
          _navTile(Icons.shield_outlined, l10n.backupSettings,
              l10n.backupSettingsSubtitle, '/settings/backup'),
          _navTile(Icons.article_outlined, l10n.diagnosticLogs,
              l10n.diagnosticLogsSubtitle, '/settings/logs'),
          const SizedBox(height: MTSpace.xl),
          MTSectionHeader(title: l10n.about),
          _navTile(Icons.info_outline_rounded, l10n.aboutApp,
              l10n.aboutDescriptionLite, '/settings/about'),
        ],
      ),
    );
  }
}
