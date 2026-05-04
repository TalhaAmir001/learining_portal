import 'package:flutter/material.dart';
import 'package:learining_portal/network/data_models/communicate/communicate_models.dart';
import 'package:learining_portal/screens/student_information/widgets/si_chrome.dart';

class CommTemplateDetailScreen extends StatelessWidget {
  const CommTemplateDetailScreen({
    super.key,
    required this.title,
    required this.template,
  });

  final String title;
  final CommTemplateModel template;

  @override
  Widget build(BuildContext context) {
    return SiThemedPageScaffold(
      title: title,
      subtitle: template.title.isNotEmpty ? template.title : 'Template #${template.id}',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          SiKeyValueTile(label: 'Title', value: template.title),
          SiKeyValueTile(label: 'Created', value: template.createdAt),
          if (template.updatedAt.isNotEmpty)
            SiKeyValueTile(label: 'Updated', value: template.updatedAt),
          SiKeyValueTile(
            label: 'Message',
            value: template.message.isNotEmpty ? template.message : '—',
          ),
        ],
      ),
    );
  }
}
