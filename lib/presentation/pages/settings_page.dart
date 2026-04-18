import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/sci_fi_widgets.dart';
import '../blocs/settings/settings_bloc.dart';
import '../blocs/settings/settings_event.dart';
import '../blocs/settings/settings_state.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildConnectionSettings(context, state),
              const SizedBox(height: 24),
              _buildNetworkSettings(context, state),
              const SizedBox(height: 24),
              _buildAboutSection(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Settings',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Configure app settings',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionSettings(BuildContext context, SettingsState state) {
    return SciFiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Connection', Icons.vpn_key_outlined),
          const SizedBox(height: 16),
          _buildSwitchTile(
            title: 'Auto Connect',
            subtitle: 'Automatically connect on app launch',
            value: state.autoConnect,
            onChanged: (value) {
              context.read<SettingsBloc>().add(ToggleAutoConnect(value));
            },
          ),
          const Divider(color: AppColors.border, height: 24),
          _buildSwitchTile(
            title: 'Auto Start',
            subtitle: 'Start VPN when device boots',
            value: state.autoStart,
            onChanged: (value) {
              context.read<SettingsBloc>().add(ToggleAutoStart(value));
            },
          ),
          const Divider(color: AppColors.border, height: 24),
          _buildSwitchTile(
            title: 'Kill Switch',
            subtitle: 'Block internet if VPN disconnects',
            value: state.killSwitch,
            onChanged: (value) {
              context.read<SettingsBloc>().add(ToggleKillSwitch(value));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkSettings(BuildContext context, SettingsState state) {
    return SciFiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Network', Icons.wifi_outlined),
          const SizedBox(height: 16),
          _buildInfoTile(
            title: 'Custom DNS',
            subtitle: state.customDns,
            trailing: const Icon(
              Icons.chevron_right,
              color: AppColors.textTertiary,
            ),
            onTap: () => _showDnsDialog(context, state.customDns),
          ),
          const Divider(color: AppColors.border, height: 24),
          _buildInfoTile(
            title: 'DNS Fallback',
            subtitle: '1.1.1.1',
            trailing: const Icon(
              Icons.chevron_right,
              color: AppColors.textTertiary,
            ),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return SciFiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('About', Icons.info_outline),
          const SizedBox(height: 16),
          _buildInfoTile(
            title: 'Version',
            subtitle: '1.0.0',
            trailing: const SizedBox.shrink(),
          ),
          const Divider(color: AppColors.border, height: 24),
          _buildInfoTile(
            title: 'Licenses',
            subtitle: 'Open source licenses',
            trailing: const Icon(
              Icons.chevron_right,
              color: AppColors.textTertiary,
            ),
            onTap: () {},
          ),
          const Divider(color: AppColors.border, height: 24),
          _buildInfoTile(
            title: 'Privacy Policy',
            subtitle: 'View privacy policy',
            trailing: const Icon(
              Icons.chevron_right,
              color: AppColors.textTertiary,
            ),
            onTap: () {},
          ),
          const Divider(color: AppColors.border, height: 24),
          _buildInfoTile(
            title: 'Logs',
            subtitle: 'View connection logs',
            trailing: const Icon(
              Icons.chevron_right,
              color: AppColors.textTertiary,
            ),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile({
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  void _showDnsDialog(BuildContext context, String currentDns) {
    final controller = TextEditingController(text: currentDns);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Custom DNS',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Enter DNS server',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<SettingsBloc>().add(UpdateDns(controller.text));
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
