import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ironvault/core/theme/app_tokens.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String version = "";
  String buildNumber = "";

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      version = info.version;
      buildNumber = info.buildNumber;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textMuted = AppThemeColors.textMuted(context);
    return Scaffold(
      appBar: AppBar(title: const Text("About")),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  child: Icon(
                    Icons.lock,
                    size: 36,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "IronVault",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  "Private, offline‑first vault",
                  style: TextStyle(fontSize: 12, color: textMuted),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          _sectionHeader('Build Info'),
          _infoTile(
            context,
            label: "Version",
            value: version.isEmpty ? "Loading..." : version,
          ),
          _infoTile(
            context,
            label: "Build Number",
            value: buildNumber.isEmpty ? "Loading..." : buildNumber,
          ),
          _infoTile(context, label: "Developer", value: "Rizwan Mulla"),

          const SizedBox(height: 8),
          _sectionHeader('About the App'),

          _section(
            context,
            title: 'What IronVault Is',
            body:
                'A private, offline‑first vault for passwords, cards, bank details, notes, and documents. Everything is stored locally and encrypted.',
          ),
          _section(
            context,
            title: 'Security',
            body:
                'Local AES‑256 encryption (AES‑GCM), master PIN, optional biometrics, and recovery key support. No cloud sync by default.',
          ),
          _section(
            context,
            title: 'Features',
            body:
                'Passwords, bank accounts, cards, secure notes, document scanning, categories, favorites, password health, and autofill.',
          ),
          _section(
            context,
            title: 'Data Storage',
            body:
                'All vault items are stored in a local SQLite database and encrypted per item. Scanned documents are compressed to reduce size.',
          ),
          _section(
            context,
            title: 'Updates',
            body: 'In‑app update prompts are delivered via GitHub Releases.',
          ),
          _section(
            context,
            title: 'Platforms',
            body: 'Android (primary). iOS not yet tested.',
          ),
          _section(
            context,
            title: 'What Happens If You Forget Your PIN',
            body:
                'You can reset the PIN using your recovery key. If you do not have it, you can reset the vault (this deletes all data).',
          ),
        ],
      ),
    );
  }

  Widget _infoTile(
    BuildContext context, {
    required String label,
    required String value,
    bool multiline = false,
  }) {
    final textMuted = AppThemeColors.textMuted(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: textMuted)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 16),
            maxLines: multiline ? null : 2,
            overflow: multiline ? null : TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}
