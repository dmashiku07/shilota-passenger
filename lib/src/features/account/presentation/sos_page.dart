import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/config/app_config.dart';
import '../data/account_repository.dart';
import '../domain/account_models.dart';

class SosPage extends ConsumerStatefulWidget {
  const SosPage({
    super.key,
    required this.rideId,
  });

  static const routePath = '/sos';

  final String rideId;

  @override
  ConsumerState<SosPage> createState() => _SosPageState();
}

class _SosPageState extends ConsumerState<SosPage> {
  final _detailsController = TextEditingController();
  bool _isSending = false;
  Position? _position;
  AdminData? _adminData;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_bootstrap);
  }

  Future<void> _bootstrap() async {
    await _loadAdminData();
    await _loadPosition();
  }

  Future<void> _loadAdminData() async {
    try {
      final data = await ref.read(accountRepositoryProvider).getAdminData();
      if (!mounted) {
        return;
      }
      setState(() {
        _adminData = data;
      });
    } catch (_) {}
  }

  Future<void> _loadPosition() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _position = position;
      });
    } catch (_) {}
  }

  Future<void> _sendAlert({
    required String actionType,
    required String message,
    required String contactTarget,
  }) async {
    final position = _position;
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current location is unavailable')),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      await ref.read(accountRepositoryProvider).sendSosAlert(
            SosAlertPayload(
              actionType: actionType,
              message: _detailsController.text.trim().isEmpty
                  ? message
                  : '$message: ${_detailsController.text.trim()}',
              latitude: position.latitude,
              longitude: position.longitude,
              rideId: widget.rideId,
              contactTarget: contactTarget,
            ),
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Emergency Alert sent')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF9),
      appBar: AppBar(title: const Text('Emergency Alert')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF04E29), Color(0xFFFF7A59)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_moon_rounded, color: Colors.white, size: 34),
                SizedBox(height: 12),
                Text(
                  'Emergency Help',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Use this only in an actual emergency. Your current location and ride context will be attached to the alert.',
                  style: TextStyle(color: Colors.white, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _detailsController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'What is happening?',
              hintText: 'Add details that can help the response team',
            ),
          ),
          const SizedBox(height: 12),
          _SosActionTile(
            icon: Icons.local_police_outlined,
            title: 'Alert police / operations',
            subtitle: (_adminData?.emergencyContact?.trim().isNotEmpty ?? false)
                ? 'Emergency line: ${_adminData!.emergencyContact}'
                : 'Alert operations and police support',
            onTap: _isSending
                ? null
                : () => _sendAlert(
                      actionType: 'police',
                      message: 'Rider called police control room',
                      contactTarget:
                          (_adminData?.emergencyContact?.trim().isNotEmpty ??
                                  false)
                              ? _adminData!.emergencyContact!.trim()
                              : AppConfig.emergencyContact,
                    ),
          ),
          const SizedBox(height: 12),
          _SosActionTile(
            icon: Icons.people_alt_outlined,
            title: 'Alert emergency contacts',
            subtitle: 'Send an emergency alert to your saved contacts',
            onTap: _isSending
                ? null
                : () => _sendAlert(
                      actionType: 'emergency_contact',
                      message: 'Rider alerted emergency contacts',
                      contactTarget: 'emergency_contacts',
                    ),
          ),
          const SizedBox(height: 18),
          if (_position != null)
            Text(
              'Current location: ${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}',
              style: const TextStyle(color: Color(0xFF6A5D57)),
            ),
        ],
      ),
    );
  }
}

class _SosActionTile extends StatelessWidget {
  const _SosActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFFFEEE8),
                child: Icon(icon, color: const Color(0xFFF04E29)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF6A5D57),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
