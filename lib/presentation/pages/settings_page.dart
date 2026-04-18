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
              _buildRoutingSettings(context, state),
              const SizedBox(height: 24),
              _buildAdvancedSettings(context, state),
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
          _buildSwitchTile(
            title: 'Enable DNS',
            subtitle: 'Use custom DNS configuration',
            value: state.enableDns,
            onChanged: (value) {
              context.read<SettingsBloc>().add(ToggleEnableDns(value));
            },
          ),
          if (state.enableDns) ...[
            const Divider(color: AppColors.border, height: 24),
            _buildInfoTile(
              title: 'Primary DNS',
              subtitle: state.customDns,
              trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
              onTap: () => _showDnsDialog(context, state.customDns, true),
            ),
            const Divider(color: AppColors.border, height: 24),
            _buildInfoTile(
              title: 'Secondary DNS',
              subtitle: state.dnsFallback,
              trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
              onTap: () => _showDnsDialog(context, state.dnsFallback, false),
            ),
          ],
          const Divider(color: AppColors.border, height: 24),
          _buildSwitchTile(
            title: 'IPv6 Support',
            subtitle: 'Enable IPv6 routing',
            value: state.ipv6Support,
            onChanged: (value) {
              context.read<SettingsBloc>().add(ToggleIpv6Support(value));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRoutingSettings(BuildContext context, SettingsState state) {
    return SciFiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Routing', Icons.route_outlined),
          const SizedBox(height: 16),
          _buildDropdownTile(
            title: 'Routing Mode',
            value: _getRoutingModeName(state.routingMode),
            onTap: () => _showRoutingModeDialog(context, state.routingMode),
          ),
          const Divider(color: AppColors.border, height: 24),
          _buildSwitchTile(
            title: 'Bypass LAN',
            subtitle: "Don't proxy local network",
            value: state.bypassLan,
            onChanged: (value) {
              context.read<SettingsBloc>().add(ToggleBypassLan(value));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSettings(BuildContext context, SettingsState state) {
    return SciFiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Advanced', Icons.tune_outlined),
          const SizedBox(height: 16),
          _buildSwitchTile(
            title: 'Multiplexing (MUX)',
            subtitle: 'Enable connection multiplexing',
            value: state.muxEnabled,
            onChanged: (value) {
              context.read<SettingsBloc>().add(ToggleMux(value));
            },
          ),
          if (state.muxEnabled) ...[
            const Divider(color: AppColors.border, height: 24),
            _buildInfoTile(
              title: 'MUX Count',
              subtitle: '${state.muxCount} concurrent streams',
              trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
              onTap: () => _showMuxCountDialog(context, state.muxCount),
            ),
          ],
          const Divider(color: AppColors.border, height: 24),
          _buildSwitchTile(
            title: 'Debug Mode',
            subtitle: 'Enable debug logging',
            value: state.debugMode,
            onChanged: (value) {
              context.read<SettingsBloc>().add(ToggleDebugMode(value));
            },
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
            trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            onTap: () {},
          ),
          const Divider(color: AppColors.border, height: 24),
          _buildInfoTile(
            title: 'Privacy Policy',
            subtitle: 'View privacy policy',
            trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            onTap: () {},
          ),
          const Divider(color: AppColors.border, height: 24),
          _buildInfoTile(
            title: 'Logs',
            subtitle: 'View connection logs',
            trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
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

  Widget _buildDropdownTile({
    required String title,
    required String value,
    required VoidCallback onTap,
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
                    value,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  String _getRoutingModeName(RoutingMode mode) {
    switch (mode) {
      case RoutingMode.geographic:
        return 'Geographic Routing';
      case RoutingMode.bypassLan:
        return 'Bypass LAN';
      case RoutingMode.global:
        return 'Global Proxy';
    }
  }

  void _showDnsDialog(BuildContext context, String currentDns, bool isPrimary) {
    final controller = TextEditingController(text: currentDns);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          isPrimary ? 'Primary DNS' : 'Secondary DNS',
          style: const TextStyle(color: AppColors.textPrimary),
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
              if (isPrimary) {
                context.read<SettingsBloc>().add(UpdateDns(controller.text));
              } else {
                context.read<SettingsBloc>().add(UpdateDnsFallback(controller.text));
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showRoutingModeDialog(BuildContext context, RoutingMode currentMode) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Routing Mode',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: RoutingMode.values.map((mode) {
            return RadioListTile<RoutingMode>(
              title: Text(
                _getRoutingModeName(mode),
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              value: mode,
              groupValue: currentMode,
              activeColor: AppColors.primary,
              onChanged: (value) {
                if (value != null) {
                  context.read<SettingsBloc>().add(UpdateRoutingMode(value));
                  Navigator.pop(dialogContext);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showMuxCountDialog(BuildContext context, int currentCount) {
    final controller = TextEditingController(text: currentCount.toString());

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'MUX Count',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AppColors.textPrimary),
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Enter MUX count (1-16)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final count = int.tryParse(controller.text) ?? 8;
              context.read<SettingsBloc>().add(UpdateMuxCount(count.clamp(1, 16)));
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
