import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/realtime_service.dart';
import '../data/account_repository.dart';
import '../domain/account_models.dart';

class RideChatPage extends ConsumerStatefulWidget {
  const RideChatPage({
    super.key,
    required this.args,
  });

  static const routePath = '/ride-chat';

  final RideChatArgs args;

  @override
  ConsumerState<RideChatPage> createState() => _RideChatPageState();
}

class _RideChatPageState extends ConsumerState<RideChatPage> {
  static const _quickPhrases = <String>[
    "I'm at the gate",
    'Please call when you arrive',
    'I will be there in 2 minutes',
    'Use the main entrance',
    'I am wearing red',
  ];
  final _controller = TextEditingController();
  final List<RideChatMessage> _messages = <RideChatMessage>[];
  StreamSubscription<RideChatMessage>? _chatSubscription;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_bootstrap);
  }

  Future<void> _bootstrap() async {
    await ref.read(realtimeServiceProvider).connect();
    _chatSubscription =
        ref.read(realtimeServiceProvider).incomingChats.listen((message) {
      if (!mounted || message.onRideId != widget.args.onRideId) {
        return;
      }
      setState(() {
        _messages.add(message);
      });
    });
    await _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    try {
      final response = await ref
          .read(accountRepositoryProvider)
          .getRideChatMessages(widget.args.onRideId);
      if (!mounted) {
        return;
      }
      setState(() {
        _messages
          ..clear()
          ..addAll(response.items);
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    setState(() {
      _sending = true;
    });
    try {
      final message =
          await ref.read(accountRepositoryProvider).sendRideChatMessage(
                onRideId: widget.args.onRideId,
                message: text,
              );
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(message);
        _controller.clear();
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF9),
      appBar: AppBar(
        title: Text('Chat with ${widget.args.driverName}'),
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
            child: const Text(
              'This is a protected in-trip chat. Your direct personal contact details stay hidden while you coordinate pickup and trip updates.',
              style: TextStyle(
                color: Color(0xFF6A5D57),
                height: 1.5,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: _quickPhrases.map((phrase) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(phrase),
                    onPressed: () {
                      _controller.text = phrase;
                      _controller.selection = TextSelection.collapsed(
                        offset: _controller.text.length,
                      );
                      setState(() {});
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _loading
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
                          constraints: const BoxConstraints(maxWidth: 300),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: message.isOutgoing
                                ? const Color(0xFFF04E29)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            message.message,
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
                        hintText: 'Type a protected trip message',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _sending ? null : _send,
                    child: _sending
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
