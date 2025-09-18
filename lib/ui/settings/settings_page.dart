import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:in_app_review/in_app_review.dart';
import 'terms_page.dart';

import '../../providers/settings_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setting'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // 週の開始（唯一の設定）
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, top: 16.0),
            child: Text('週の開始', style: Theme.of(context).textTheme.titleMedium),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('月曜はじまり'),
                          selected: settings.weekStart == WeekStart.monday,
                          onSelected: (_) => ref
                              .read(settingsProvider.notifier)
                              .setWeekStart(WeekStart.monday),
                        ),
                        ChoiceChip(
                          label: const Text('日曜はじまり'),
                          selected: settings.weekStart == WeekStart.sunday,
                          onSelected: (_) => ref
                              .read(settingsProvider.notifier)
                              .setWeekStart(WeekStart.sunday),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // サポート
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, top: 16.0),
            child: Text('サポート', style: Theme.of(context).textTheme.titleMedium),
          ),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.star_rate_outlined),
                  title: const Text('評価・レビュー'),
                  onTap: () async {
                    final liked = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('このアプリは気に入っていますか？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('改善してほしい'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('気に入っている'),
                          ),
                        ],
                      ),
                    );
                    if (liked == true) {
                      final inAppReview = InAppReview.instance;
                      try {
                        if (await inAppReview.isAvailable()) {
                          await inAppReview.requestReview();
                        }
                      } catch (_) {}
                    } else if (liked == false) {
                      final uri = Uri.parse(
                          'https://ashimonkey.sakura.ne.jp/contact-app/public/contact/app_2837e73fe341');
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('お問い合わせ'),
                  subtitle: const Text('ご意見・ご要望・不具合のご連絡'),
                  onTap: () async {
                    final uri = Uri.parse(
                        'https://ashimonkey.sakura.ne.jp/contact-app/public/contact/app_2837e73fe341');
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                ),
              ],
            ),
          ),

          // アプリ情報
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, top: 16.0),
            child:
                Text('アプリ情報', style: Theme.of(context).textTheme.titleMedium),
          ),
          Card(
            child: Column(
              children: [
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snap) {
                    final v = snap.data?.version ?? '—';
                    return ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('バージョン'),
                      subtitle: Text(v),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('利用規約'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TermsPage()),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
