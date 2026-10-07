import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/cartok_colors.dart';
import '../providers/forum_providers.dart';
import '../providers/thread_list_provider.dart';

class CreateThreadSheet extends ConsumerStatefulWidget {
  const CreateThreadSheet({super.key, required this.categoryId});

  final String categoryId;

  @override
  ConsumerState<CreateThreadSheet> createState() => _CreateThreadSheetState();
}

class _CreateThreadSheetState extends ConsumerState<CreateThreadSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final thread = await ref.read(forumRepositoryProvider).createThread(
            widget.categoryId,
            title: _titleController.text.trim(),
            content: _contentController.text.trim(),
          );
      ref.read(threadListProvider(widget.categoryId).notifier).prepend(thread);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Start a thread', style: textTheme.headlineSmall),
            const SizedBox(height: 20),
            TextFormField(
              controller: _titleController,
              autofocus: true,
              style: textTheme.bodyLarge,
              maxLength: 140,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) => (v == null || v.trim().length < 3) ? 'At least 3 characters' : null,
            ),
            TextFormField(
              controller: _contentController,
              style: textTheme.bodyLarge,
              maxLines: 5,
              minLines: 3,
              decoration: const InputDecoration(labelText: 'What do you want to say?'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Say something to get started' : null,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: CartokColors.textOnAccent),
                    )
                  : const Text('Post thread'),
            ),
          ],
        ),
      ),
    );
  }
}
