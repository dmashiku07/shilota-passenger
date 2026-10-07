import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InvitePage extends StatelessWidget {
  const InvitePage({super.key});

  static const routePath = '/invite';

  @override
  Widget build(BuildContext context) {
    const packageName = 'com.getcoregroup.shilotauser';
    const websiteUrl = 'https://shilota.tz';
    const playStoreUrl =
        'https://play.google.com/store/apps/details?id=$packageName';
    const inviteMessage =
        'Ride with Shilota. Book fast pickups, track your trip, and move around town with ease.\n\nDownload: $playStoreUrl\nWebsite: $websiteUrl';

    return Scaffold(
      appBar: AppBar(title: const Text('Invite')),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                  Text(
                    'Invite friends',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const SelectableText(
                inviteMessage,
                style: TextStyle(height: 1.5),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await Clipboard.setData(
                    const ClipboardData(text: inviteMessage),
                  );
                  if (!context.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invite message copied'),
                    ),
                  );
                },
                child: const Text('Invite friends'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
