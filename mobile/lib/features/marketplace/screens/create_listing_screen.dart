import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/cartok_colors.dart';
import '../providers/marketplace_providers.dart';
import '../providers/listing_browse_provider.dart';

const _listingTypes = [
  'CAR',
  'MOTORCYCLE',
  'PART',
  'ACCESSORY',
  'WHEELS',
  'TIRES',
  'TOOLS',
  'ELECTRONICS',
  'GARAGE_EQUIPMENT',
  'TRANSPORT',
  'WANTED',
];

const _conditions = ['NEW', 'USED', 'FOR_PARTS'];

class CreateListingScreen extends ConsumerStatefulWidget {
  const CreateListingScreen({super.key});

  @override
  ConsumerState<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends ConsumerState<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();

  String _type = _listingTypes.first;
  String? _condition;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final dollars = double.parse(_priceController.text.trim());
    final priceCents = (dollars * 100).round();

    try {
      final listing = await ref.read(marketplaceRepositoryProvider).create(
            type: _type,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            priceCents: priceCents,
            condition: _condition,
            location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
            // Photo upload isn't wired up yet — it needs an object-storage
            // decision (S3/Cloudflare R2/etc.) that hasn't been made.
            // Listings can be created and edited without photos for now.
            imageUrls: const [],
          );
      ref.read(listingBrowseProvider.notifier).prepend(listing);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('New listing')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Category', style: textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _listingTypes.map((type) {
                  final selected = _type == type;
                  return ChoiceChip(
                    label: Text(type.replaceAll('_', ' ')),
                    selected: selected,
                    onSelected: (_) => setState(() => _type = type),
                    selectedColor: CartokColors.redline,
                    backgroundColor: CartokColors.surfaceElevated,
                    labelStyle: TextStyle(
                      color: selected ? CartokColors.textOnAccent : CartokColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(color: selected ? CartokColors.redline : CartokColors.borderSubtle),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _titleController,
                style: textTheme.bodyLarge,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => (v == null || v.trim().length < 3) ? 'At least 3 characters' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                style: textTheme.bodyLarge,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Describe what you\'re selling' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      style: textTheme.bodyLarge,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Price', prefixText: '\$ '),
                      validator: (v) {
                        final value = double.tryParse(v?.trim() ?? '');
                        if (value == null || value <= 0) return 'Enter a valid price';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _locationController,
                      style: textTheme.bodyLarge,
                      decoration: const InputDecoration(labelText: 'Location (optional)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Condition (optional)', style: textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _conditions.map((c) {
                  final selected = _condition == c;
                  return ChoiceChip(
                    label: Text(c.replaceAll('_', ' ')),
                    selected: selected,
                    onSelected: (_) => setState(() => _condition = selected ? null : c),
                    selectedColor: CartokColors.telemetry,
                    backgroundColor: CartokColors.surfaceElevated,
                    labelStyle: TextStyle(
                      color: selected ? CartokColors.textOnAccent : CartokColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(color: selected ? CartokColors.telemetry : CartokColors.borderSubtle),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: CartokColors.textOnAccent),
                      )
                    : const Text('Publish listing'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
