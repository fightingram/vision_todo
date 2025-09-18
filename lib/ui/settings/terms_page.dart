import 'package:flutter/material.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('利用規約'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: const [
          Text(
            '本規約は、Dream todo（以下「本アプリ」）の利用条件を定めるものです。',
          ),
          SizedBox(height: 12),
          Text('1. 適用'),
          SizedBox(height: 6),
          Text('本規約は、本アプリの利用に関わる一切の関係に適用されます。'),
          SizedBox(height: 12),
          Text('2. 禁止事項'),
          SizedBox(height: 6),
          Text('法令または公序良俗に違反する行為、本アプリの運営を妨害する行為、その他当社が不適切と判断する行為を禁止します。'),
          SizedBox(height: 12),
          Text('3. 免責事項'),
          SizedBox(height: 6),
          Text('本アプリの利用により生じたいかなる損害についても、当社は一切の責任を負いません。'),
          SizedBox(height: 12),
          Text('4. 規約の変更'),
          SizedBox(height: 6),
          Text('当社は、必要と判断した場合、本規約を変更することができます。'),
          SizedBox(height: 12),
          Text('5. 準拠法・裁判管轄'),
          SizedBox(height: 6),
          Text('本規約は日本法に準拠し、紛争が生じた場合は当社所在地を管轄する裁判所を第一審の専属的合意管轄とします。'),
          SizedBox(height: 24),
          Text('最終更新日: 2025-09-01'),
        ],
      ),
    );
  }
}
