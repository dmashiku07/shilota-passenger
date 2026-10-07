import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/account_repository.dart';
import '../domain/account_models.dart';

class HelpPage extends ConsumerWidget {
  const HelpPage({super.key});

  static const routePath = '/help';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(accountRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Help'),
        actions: [
          IconButton(
            onPressed: () => _openContactSheet(context, ref),
            tooltip: 'Contact support',
            icon: const Icon(Icons.mail_outline_rounded),
          ),
        ],
      ),
      body: FutureBuilder<ApiListResponse<HelpPageData>>(
        future: repository.getHelpPages(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }

          final pages = snapshot.data?.items ?? const <HelpPageData>[];
          if (pages.isEmpty) {
            return const Center(child: Text('No help pages available'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: pages.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final page = pages[index];
              return ExpansionTile(
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                collapsedShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                backgroundColor: Colors.white,
                collapsedBackgroundColor: Colors.white,
                title: Text(
                  page.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(page.pageType),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        page.content,
                        style: const TextStyle(
                            height: 1.5, color: Color(0xFF4F4742)),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openContactSheet(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        var isBusy = false;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              Future<void> submit() async {
                if (!formKey.currentState!.validate()) {
                  return;
                }

                setState(() => isBusy = true);
                try {
                  await ref.read(accountRepositoryProvider).contactUs(
                        name: nameController.text.trim(),
                        email: emailController.text.trim(),
                        subject: subjectController.text.trim(),
                        message: messageController.text.trim(),
                      );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Message sent')),
                    );
                  }
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$error')),
                    );
                  }
                } finally {
                  setState(() => isBusy = false);
                }
              }

              return Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Contact Support',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? 'Enter your name'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? 'Enter your email'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: subjectController,
                        decoration: const InputDecoration(labelText: 'Subject'),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? 'Enter a subject'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: messageController,
                        decoration: const InputDecoration(labelText: 'Message'),
                        minLines: 4,
                        maxLines: 6,
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? 'Enter a message'
                                : null,
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isBusy ? null : submit,
                          child: isBusy
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Send'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
