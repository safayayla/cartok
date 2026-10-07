import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/cartok_colors.dart';
import '../providers/event_list_provider.dart';

const _eventTypes = <String, String>{
  'CARS_AND_COFFEE': 'Cars & Coffee',
  'DRIVE_TOGETHER': 'Drive Together',
  'TRACK_DAY': 'Track Day',
  'MEETUP': 'Meetup',
  'OTHER': 'Other',
};

class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _capacityController = TextEditingController();

  String _type = _eventTypes.keys.first;
  DateTime? _startTime;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _pickStartTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (time == null) return;

    setState(() {
      _startTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a date and time for the event')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final event = await ref.read(eventsRepositoryProvider).create(
            type: _type,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
            locationName: _locationController.text.trim(),
            startTime: _startTime!,
            capacity: _capacityController.text.trim().isEmpty ? null : int.parse(_capacityController.text.trim()),
          );
      ref.read(eventListProvider.notifier).prepend(event);
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
      appBar: AppBar(title: const Text('New event')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Type', style: textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _eventTypes.entries.map((entry) {
                  final selected = _type == entry.key;
                  return ChoiceChip(
                    label: Text(entry.value),
                    selected: selected,
                    onSelected: (_) => setState(() => _type = entry.key),
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
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Description (optional)'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                style: textTheme.bodyLarge,
                decoration: const InputDecoration(labelText: 'Location'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Where is this happening?' : null,
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickStartTime,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date & time'),
                  child: Text(
                    _startTime == null
                        ? 'Select date and time'
                        : '${_startTime!.month}/${_startTime!.day}/${_startTime!.year} at '
                            '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}',
                    style: textTheme.bodyLarge?.copyWith(
                      color: _startTime == null ? CartokColors.textTertiary : CartokColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _capacityController,
                style: textTheme.bodyLarge,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Capacity (optional)'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final n = int.tryParse(v.trim());
                  if (n == null || n < 1) return 'Enter a valid number';
                  return null;
                },
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
                    : const Text('Create event'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
