import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/cartok_colors.dart';
import '../providers/garage_providers.dart';

class CreateGarageSheet extends ConsumerStatefulWidget {
  const CreateGarageSheet({super.key});

  @override
  ConsumerState<CreateGarageSheet> createState() => _CreateGarageSheetState();
}

class _CreateGarageSheetState extends ConsumerState<CreateGarageSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await ref.read(garageRepositoryProvider).createGarage(name: _nameController.text.trim());
      ref.invalidate(myGaragesProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() => _submitting = false);
      }
    }
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name your garage', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              "This is where all your vehicles live — you can add more garages later.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              autofocus: true,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: const InputDecoration(labelText: 'Garage name', hintText: "e.g. Dave's Builds"),
              validator: (v) => (v == null || v.isEmpty) ? 'Enter a name' : null,
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
                  : const Text('Create garage'),
            ),
          ],
        ),
      ),
    );
  }
}
