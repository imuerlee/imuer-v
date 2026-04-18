import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/sci_fi_widgets.dart';
import '../../domain/entities/server_node.dart';
import '../blocs/server/server_bloc.dart';
import '../blocs/server/server_event.dart';
import '../blocs/server/server_state.dart';
import '../blocs/vpn/vpn_bloc.dart';
import '../blocs/vpn/vpn_event.dart';

class ServersPage extends StatelessWidget {
  const ServersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ServerBloc, ServerState>(
      builder: (context, state) {
        if (state.status == ServerStatus.loading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        return Column(
          children: [
            _buildHeader(context, state),
            Expanded(
              child: state.servers.isEmpty
                  ? _buildEmptyState(context)
                  : _buildServerList(context, state),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, ServerState state) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Server List',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${state.servers.length} servers',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          _buildActionButton(
            icon: Icons.sync,
            label: 'Test All',
            onTap: () {
              context.read<ServerBloc>().add(const TestAllServersLatency());
            },
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            icon: Icons.add,
            label: 'Add',
            isPrimary: true,
            onTap: () => _showAddServerDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.primary : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPrimary ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isPrimary ? AppColors.background : AppColors.primary,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? AppColors.background : AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off,
            size: 80,
            color: AppColors.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Servers',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add a server to get started',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddServerDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Server'),
          ),
        ],
      ),
    );
  }

  Widget _buildServerList(BuildContext context, ServerState state) {
    final sortedServers = state.serversByLatency;

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: sortedServers.length,
      itemBuilder: (context, index) {
        final server = sortedServers[index];
        return _buildServerCard(context, server);
      },
    );
  }

  Widget _buildServerCard(BuildContext context, ServerNode server) {
    final latencyColor = _getLatencyColor(server.latency);

    return SciFiCard(
      showGlow: false,
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () {
        context.read<VpnBloc>().add(ConnectVpn(server.id));
      },
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                _getCountryFlag(server.country ?? ''),
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  server.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      _getProtocolIcon(server.protocol),
                      color: AppColors.textTertiary,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      server.protocol.name.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      server.address,
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: latencyColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  server.latency != null ? '${server.latency} ms' : '--',
                  style: TextStyle(
                    color: latencyColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () {
                  context.read<ServerBloc>().add(TestServerLatency(server.id));
                },
                child: const Icon(
                  Icons.refresh,
                  color: AppColors.textTertiary,
                  size: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getLatencyColor(int? latency) {
    if (latency == null) return AppColors.textTertiary;
    if (latency < 100) return AppColors.success;
    if (latency < 200) return AppColors.warning;
    return AppColors.error;
  }

  String _getCountryFlag(String country) {
    final flags = {
      'United States': '🇺🇸',
      'United Kingdom': '🇬🇧',
      'Japan': '🇯🇵',
      'Singapore': '🇸🇬',
      'Hong Kong': '🇭🇰',
      'Germany': '🇩🇪',
      'France': '🇫🇷',
      'Australia': '🇦🇺',
      'Canada': '🇨🇦',
      'Netherlands': '🇳🇱',
      'Unknown': '🌐',
    };
    return flags[country] ?? '🌐';
  }

  IconData _getProtocolIcon(ServerProtocol protocol) {
    switch (protocol) {
      case ServerProtocol.vmess:
        return Icons.flash_on;
      case ServerProtocol.vless:
        return Icons.bolt;
      case ServerProtocol.shadowsocks:
        return Icons.visibility_off;
      case ServerProtocol.trojan:
        return Icons.security;
    }
  }

  void _showAddServerDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (dialogContext) => _AddServerForm(
        onAdd: (server) {
          context.read<ServerBloc>().add(AddServer(server));
          Navigator.pop(dialogContext);
        },
      ),
    );
  }
}

class _AddServerForm extends StatefulWidget {
  final Function(ServerNode) onAdd;

  const _AddServerForm({required this.onAdd});

  @override
  State<_AddServerForm> createState() => _AddServerFormState();
}

class _AddServerFormState extends State<_AddServerForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _portController = TextEditingController();
  final _uuidController = TextEditingController();
  ServerProtocol _protocol = ServerProtocol.vmess;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _portController.dispose();
    _uuidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Server',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              _buildTextField(
                controller: _nameController,
                label: 'Server Name',
                hint: 'My Server',
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              _buildProtocolSelector(),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _addressController,
                label: 'Server Address',
                hint: 'example.com',
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _portController,
                label: 'Port',
                hint: '443',
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              if (_protocol == ServerProtocol.vmess ||
                  _protocol == ServerProtocol.vless) ...[
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _uuidController,
                  label: 'UUID',
                  hint: 'Enter UUID',
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Add Server'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
    );
  }

  Widget _buildProtocolSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Protocol',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ServerProtocol.values.map((protocol) {
            final isSelected = _protocol == protocol;
            return ChoiceChip(
              label: Text(protocol.name.toUpperCase()),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _protocol = protocol);
                }
              },
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.surfaceLight,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.background : AppColors.textPrimary,
                fontSize: 12,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final server = ServerNode(
        id: const Uuid().v4(),
        name: _nameController.text,
        address: _addressController.text,
        port: int.tryParse(_portController.text) ?? 443,
        protocol: _protocol,
        uuid: _protocol == ServerProtocol.vmess || _protocol == ServerProtocol.vless
            ? _uuidController.text
            : null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      widget.onAdd(server);
    }
  }
}
