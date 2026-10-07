import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/storage_providers.dart';
import '../data/account_repository.dart';
import '../domain/account_models.dart';

class SupportConversationPage extends ConsumerStatefulWidget {
  const SupportConversationPage({
    super.key,
    required this.args,
  });

  static const routePath = '/support-conversation';

  final SupportConversationArgs args;

  @override
  ConsumerState<SupportConversationPage> createState() =>
      _SupportConversationPageState();
}

class _SupportConversationPageState
    extends ConsumerState<SupportConversationPage> {
  final _controller = TextEditingController();
  final List<_SupportMessage> _messages = <_SupportMessage>[];
  LostItemCaseSummary? _lostItemCase;
  bool _isSending = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_bootstrap);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (widget.args.lostItemId != null && widget.args.lostItemId!.isNotEmpty) {
      await _loadLostItemMessages();
      return;
    }

    final prefill = widget.args.prefillMessage?.trim();
    if (prefill != null && prefill.isNotEmpty) {
      setState(() {
        _messages.add(
          _SupportMessage(
            body: prefill,
            isOutgoing: false,
          ),
        );
      });
    }
  }

  Future<void> _loadLostItemMessages() async {
    setState(() => _isLoading = true);
    try {
      final repository = ref.read(accountRepositoryProvider);
      final caseSummary =
          await repository.getLostItemCase(widget.args.lostItemId!);
      final response =
          await repository.getLostItemMessages(widget.args.lostItemId!);
      if (!mounted) {
        return;
      }
      setState(() {
        _lostItemCase = caseSummary;
        _messages
          ..clear()
          ..addAll(
            response.items.map(
              (item) => _SupportMessage(
                body: item.message,
                isOutgoing: item.isOutgoing,
              ),
            ),
          );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _escalateCase() async {
    final lostItemId = widget.args.lostItemId;
    if (lostItemId == null || lostItemId.isEmpty) {
      return;
    }
    try {
      await ref.read(accountRepositoryProvider).escalateLostItemCase(
            lostItemId: lostItemId,
            reason: 'Rider requested escalation from the follow-up screen.',
          );
      await _loadLostItemMessages();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Case escalated to support')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _confirmReturned() async {
    final lostItemId = widget.args.lostItemId;
    if (lostItemId == null || lostItemId.isEmpty) {
      return;
    }
    try {
      await ref.read(accountRepositoryProvider).confirmLostItemReturned(
            lostItemId,
          );
      await _loadLostItemMessages();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lost item marked as returned')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }

    final session = ref.read(sessionStorageProvider);
    setState(() {
      _isSending = true;
      _messages.add(_SupportMessage(body: text, isOutgoing: true));
      _controller.clear();
    });

    try {
      if (widget.args.lostItemId != null &&
          widget.args.lostItemId!.isNotEmpty) {
        await ref.read(accountRepositoryProvider).sendLostItemMessage(
              lostItemId: widget.args.lostItemId!,
              message: text,
            );
      } else {
        await ref.read(accountRepositoryProvider).contactUs(
              name: session.fullName ?? 'Shilota Rider',
              email: session.email ?? 'support@shilota.tz',
              subject: widget.args.subject,
              message: text,
            );
      }
      if (!mounted) {
        return;
      }
      if (widget.args.lostItemId != null &&
          widget.args.lostItemId!.isNotEmpty) {
        return;
      }
      setState(() {
        _messages.add(
          const _SupportMessage(
            body:
                'Support has received your message and will follow up shortly.',
            isOutgoing: false,
          ),
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  String? _formatCaseDate(String? value) {
    final parsed = DateTime.tryParse(value ?? '');
    if (parsed == null) {
      return null;
    }
    final local = parsed.toLocal();
    final month = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ][local.month - 1];
    final hour = local.hour == 0
        ? 12
        : local.hour > 12
            ? local.hour - 12
            : local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.day} $month, $hour:$minute $suffix';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF9),
      appBar: AppBar(
        title: Text(widget.args.title),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Messages are routed through ${widget.args.recipientLabel} so you can follow up without exposing direct personal contact details.',
              style: const TextStyle(
                color: Color(0xFF6A5D57),
                height: 1.5,
              ),
            ),
          ),
          if (_lostItemCase != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _lostItemCase!.isEscalated
                    ? const Color(0xFFFFF3EE)
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _lostItemCase!.isEscalated
                      ? const Color(0xFFF4D6CD)
                      : const Color(0xFFF0E4DF),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Case status: ${_lostItemCase!.caseStatus}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF231814),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _lostItemCase!.isEscalated
                        ? 'This lost item case has been escalated to support.'
                        : 'Support can escalate this case if pickup handoff is stalled.',
                    style: const TextStyle(color: Color(0xFF6A5D57)),
                  ),
                  if (_formatCaseDate(_lostItemCase!.responseDueAt) != null ||
                      _formatCaseDate(_lostItemCase!.lastMessageAt) !=
                          null) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_formatCaseDate(_lostItemCase!.responseDueAt) !=
                            null)
                          _CaseMetaChip(
                            icon: Icons.schedule_rounded,
                            label:
                                'Response due ${_formatCaseDate(_lostItemCase!.responseDueAt)!}',
                          ),
                        if (_formatCaseDate(_lostItemCase!.lastMessageAt) !=
                            null)
                          _CaseMetaChip(
                            icon: Icons.mark_chat_read_rounded,
                            label:
                                'Last update ${_formatCaseDate(_lostItemCase!.lastMessageAt)!}',
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (!_lostItemCase!.isEscalated)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _escalateCase,
                            child: const Text('Escalate'),
                          ),
                        ),
                      if (!_lostItemCase!.isEscalated &&
                          _lostItemCase!.canConfirmReturned)
                        const SizedBox(width: 12),
                      if (_lostItemCase!.canConfirmReturned)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _confirmReturned,
                            child: const Text('Confirm Returned'),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return Align(
                        alignment: message.isOutgoing
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 280),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: message.isOutgoing
                                ? const Color(0xFFF04E29)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            message.body,
                            style: TextStyle(
                              color: message.isOutgoing
                                  ? Colors.white
                                  : const Color(0xFF231814),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Type your message',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSending ? null : _send,
                    child: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Send'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportMessage {
  const _SupportMessage({
    required this.body,
    required this.isOutgoing,
  });

  final String body;
  final bool isOutgoing;
}

class _CaseMetaChip extends StatelessWidget {
  const _CaseMetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F3),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFF4D6CD)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: const Color(0xFFF04E29),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6A5D57),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
