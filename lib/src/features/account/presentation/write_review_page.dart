import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../data/account_repository.dart';
import '../domain/account_models.dart';

class WriteReviewPage extends ConsumerStatefulWidget {
  const WriteReviewPage({
    super.key,
    required this.args,
  });

  static const routePath = '/write-review';

  final ReviewArgs args;

  @override
  ConsumerState<WriteReviewPage> createState() => _WriteReviewPageState();
}

class _WriteReviewPageState extends ConsumerState<WriteReviewPage> {
  late double _rating;
  late TextEditingController _controller;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _rating = double.tryParse(widget.args.rating ?? '0') ?? 0;
    _controller = TextEditingController(text: widget.args.reviewMessage ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating')),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      await ref.read(accountRepositoryProvider).submitReview(
            onRideId: widget.args.onRideId,
            rating: _rating,
            reviewMessage: _controller.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF9),
      appBar: AppBar(title: const Text('Rate Your Ride')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: BoxDecoration(
              color: const Color(AppConfig.secondaryColorHex),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(AppConfig.lineColorHex)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFCE7E1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 34,
                      color: Color(AppConfig.primaryColorHex),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Center(
                  child: Text(
                    'Ride completed',
                    style: TextStyle(
                      fontSize: AppConfig.textSizeHeader,
                      fontWeight: FontWeight.w700,
                      color: Color(AppConfig.textPrimaryColorHex),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Center(
                  child: Text(
                    'How was your experience with the driver?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppConfig.textSizeSmall,
                      color: Color(AppConfig.textSecondaryColorHex),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'YOUR RATING',
                    style: TextStyle(
                      fontSize: AppConfig.textSizeVerySmall,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: Color(AppConfig.textTertiaryColorHex),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final value = index + 1;
                    return IconButton(
                      tooltip: '$value star${value == 1 ? '' : 's'}',
                      iconSize: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      onPressed: () =>
                          setState(() => _rating = value.toDouble()),
                      icon: Icon(
                        value <= _rating
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: const Color(AppConfig.primaryColorHex),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    _rating == 0
                        ? 'Tap a star to rate'
                        : '${_rating.toInt()} out of 5',
                    style: const TextStyle(
                      fontSize: AppConfig.textSizeSmall,
                      fontWeight: FontWeight.w600,
                      color: Color(AppConfig.textSecondaryColorHex),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                TextField(
                  controller: _controller,
                  minLines: 3,
                  maxLines: 5,
                  style: const TextStyle(fontSize: AppConfig.textSizeMedium),
                  decoration: const InputDecoration(
                    labelText: 'COMMENT (OPTIONAL)',
                    hintText: 'Tell us about your ride',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Submit Rating'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
