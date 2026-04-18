import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/sci_fi_widgets.dart';

class License {
  final String name;
  final String version;
  final String description;
  final String license;

  const License({
    required this.name,
    required this.version,
    required this.description,
    required this.license,
  });
}

class LicensesPage extends StatelessWidget {
  const LicensesPage({super.key});

  static const List<License> _licenses = [
    License(
      name: 'Flutter',
      version: '3.41.7',
      description: 'UI toolkit for building natively compiled applications',
      license: 'BSD-3-Clause',
    ),
    License(
      name: 'flutter_bloc',
      version: '8.1.6',
      description: 'State management library for Flutter',
      license: 'MIT',
    ),
    License(
      name: 'dio',
      version: '5.4.3+1',
      description: 'HTTP client for Dart',
      license: 'Apache-2.0',
    ),
    License(
      name: 'sqflite',
      version: '2.3.3+1',
      description: 'SQLite plugin for Flutter',
      license: 'BSD-2-Clause',
    ),
    License(
      name: 'shared_preferences',
      version: '2.2.3',
      description: 'Persistent storage for key-value pairs',
      license: 'BSD-2-Clause',
    ),
    License(
      name: 'get_it',
      version: '7.6.7',
      description: 'Service locator for Dart and Flutter',
      license: 'MIT',
    ),
    License(
      name: 'google_fonts',
      version: '6.2.1',
      description: 'Google Fonts for Flutter',
      license: 'Apache-2.0',
    ),
    License(
      name: 'fl_chart',
      version: '0.68.0',
      description: 'Charts library for Flutter',
      license: 'MIT',
    ),
    License(
      name: 'shimmer',
      version: '3.0.0',
      description: 'Shimmer loading effect for Flutter',
      license: 'MIT',
    ),
    License(
      name: 'path_provider',
      version: '2.1.3',
      description: 'Access platform-specific file locations',
      license: 'BSD-2-Clause',
    ),
    License(
      name: 'share_plus',
      version: '9.0.0',
      description: 'Share content via platform share dialog',
      license: 'BSD-3-Clause',
    ),
    License(
      name: 'intl',
      version: '0.19.0',
      description: 'Internationalization and localization',
      license: 'BSD-2-Clause',
    ),
    License(
      name: 'connectivity_plus',
      version: '6.0.3',
      description: 'Check network connectivity status',
      license: 'BSD-3-Clause',
    ),
    License(
      name: 'v2ray-core',
      version: '5.22.0',
      description: 'Platform for building proxies',
      license: 'MIT',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text('Open Source Licenses', style: TextStyle(color: AppColors.textPrimary)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _licenses.length,
        itemBuilder: (context, index) {
          final license = _licenses[index];
          return _buildLicenseCard(license);
        },
      ),
    );
  }

  Widget _buildLicenseCard(License license) {
    return SciFiCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  license.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  license.license,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Version ${license.version}',
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            license.description,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
