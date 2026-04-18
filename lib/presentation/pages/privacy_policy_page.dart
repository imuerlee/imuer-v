import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text('Privacy Policy', style: TextStyle(color: AppColors.textPrimary)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              '1. Information Collection',
              '''NebulaVPN is designed with privacy in mind. We collect minimal information necessary to provide the VPN service:

• Connection logs: We do NOT keep logs of your browsing activity, DNS queries, or connection metadata.
• Usage statistics: We may collect anonymous, aggregated usage data to improve our service.
• Account information: If you create an account, we store only the information you provide.
• Device information: We may collect basic device information for troubleshooting purposes.''',
            ),
            _buildSection(
              '2. Data Usage',
              '''The information we collect is used for:

• Providing and maintaining the VPN service
• Improving user experience and service performance
• Troubleshooting technical issues
• Sending service-related notifications (with your consent)''',
            ),
            _buildSection(
              '3. Data Sharing',
              '''We do NOT sell, trade, or otherwise transfer your personal information to third parties, except:

• When required by law or legal process
• To protect our rights and prevent fraud
• In connection with a merger, acquisition, or sale of assets''',
            ),
            _buildSection(
              '4. Data Security',
              '''We implement industry-standard security measures to protect your data:

• Encryption of all data in transit using strong cryptographic protocols
• Secure storage of any retained information
• Regular security audits and updates''',
            ),
            _buildSection(
              '5. Third-Party Services',
              '''Our service may include links to third-party websites or services. We are not responsible for the privacy practices of these third parties. We encourage you to review their privacy policies.''',
            ),
            _buildSection(
              "6. Children's Privacy",
              "Our service is not intended for children under 13 years of age. We do not knowingly collect personal information from children under 13.",
            ),
            _buildSection(
              '7. Changes to This Policy',
              '''We may update this Privacy Policy from time to time. We will notify you of any material changes by posting the new policy on this page and updating the "Last updated" date.''',
            ),
            _buildSection(
              '8. Contact Us',
              '''If you have questions about this Privacy Policy, please contact us at:

Email: privacy@nebula-vpn.example.com
Website: https://nebula-vpn.example.com''',
            ),
            const SizedBox(height: 32),
            Center(
              child: Text(
                'Last updated: ${_formatDate(DateTime.now())}',
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
