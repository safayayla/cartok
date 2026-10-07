import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/cartok_colors.dart';
import '../../../core/theme/cartok_typography.dart';
import '../providers/garage_providers.dart';
import '../repository/garage_repository.dart';

final _vinRegex = RegExp(r'^[A-HJ-NPR-Z0-9]{17}$', caseSensitive: false);

class AddVehicleScreen extends ConsumerStatefulWidget {
  const AddVehicleScreen({super.key, required this.garageId});

  final String garageId;

  @override
  ConsumerState<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends ConsumerState<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _vinController = TextEditingController();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _trimController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _odometerController = TextEditingController();

  bool _decoding = false;
  bool _submitting = false;
  VinDecodeResult? _decodeResult;
  String? _decodeError;

  @override
  void dispose() {
    _vinController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _trimController.dispose();
    _nicknameController.dispose();
    _odometerController.dispose();
    super.dispose();
  }

  Future<void> _decodeVin() async {
    final vin = _vinController.text.trim().toUpperCase();
    if (!_vinRegex.hasMatch(vin)) {
      setState(() {
        _decodeError = 'VIN must be 17 characters (no I, O, or Q)';
        _decodeResult = null;
      });
      return;
    }

    setState(() {
      _decoding = true;
      _decodeError = null;
    });

    final result = await ref.read(garageRepositoryProvider).decodeVin(vin);

    if (!mounted) return;
    setState(() {
      _decoding = false;
      _decodeResult = result;
      if (result == null) {
        _decodeError = "Couldn't decode that VIN — you can still enter details manually.";
      } else {
        if (result.make != null) _makeController.text = result.make!;
        if (result.model != null) _modelController.text = result.model!;
        if (result.modelYear != null) _yearController.text = result.modelYear!;
        if (result.trim != null) _trimController.text = result.trim!;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      await ref.read(garageRepositoryProvider).addVehicle(
            garageId: widget.garageId,
            vin: _vinController.text.trim().isEmpty ? null : _vinController.text.trim().toUpperCase(),
            make: _makeController.text.trim(),
            model: _modelController.text.trim(),
            year: int.parse(_yearController.text.trim()),
            trim: _trimController.text.trim(),
            nickname: _nicknameController.text.trim(),
            odometer: _odometerController.text.trim().isEmpty ? null : int.parse(_odometerController.text.trim()),
          );
      ref.invalidate(myGaragesProvider);
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
      appBar: AppBar(title: const Text('Add a vehicle')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('VIN (optional)', style: textTheme.labelLarge),
              const SizedBox(height: 8),
              Text(
                "We'll pull the make, model, and year for you.",
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _vinController,
                textCapitalization: TextCapitalization.characters,
                maxLength: 17,
                style: CartokTypography.telemetry(size: 15),
                decoration: InputDecoration(
                  labelText: 'VIN',
                  hintText: '1HGCM82633A004352',
                  counterText: '',
                  suffixIcon: _decoding
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: CartokColors.telemetry),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.search_rounded, color: CartokColors.telemetry),
                          tooltip: 'Decode VIN',
                          onPressed: _decodeVin,
                        ),
                ),
              ),
              if (_decodeError != null) ...[
                const SizedBox(height: 8),
                Text(_decodeError!, style: textTheme.bodyMedium?.copyWith(color: CartokColors.danger)),
              ],
              if (_decodeResult != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CartokColors.telemetryDim.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: CartokColors.telemetry.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 18, color: CartokColors.telemetry),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Decoded ${_decodeResult!.modelYear ?? ''} ${_decodeResult!.make ?? ''} ${_decodeResult!.model ?? ''}'
                              .trim(),
                          style: textTheme.bodyMedium?.copyWith(color: CartokColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              Divider(color: CartokColors.borderSubtle),
              const SizedBox(height: 20),
              Text('Vehicle details', style: textTheme.labelLarge),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _makeController,
                      style: textTheme.bodyLarge,
                      decoration: const InputDecoration(labelText: 'Make'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _modelController,
                      style: textTheme.bodyLarge,
                      decoration: const InputDecoration(labelText: 'Model'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _yearController,
                      keyboardType: TextInputType.number,
                      style: textTheme.bodyLarge,
                      decoration: const InputDecoration(labelText: 'Year'),
                      validator: (v) {
                        final year = int.tryParse(v ?? '');
                        if (year == null || year < 1886 || year > DateTime.now().year + 2) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _trimController,
                style: textTheme.bodyLarge,
                decoration: const InputDecoration(labelText: 'Trim (optional)'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nicknameController,
                style: textTheme.bodyLarge,
                decoration: const InputDecoration(labelText: 'Nickname (optional)', hintText: 'e.g. The Widowmaker'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _odometerController,
                keyboardType: TextInputType.number,
                style: textTheme.bodyLarge,
                decoration: const InputDecoration(labelText: 'Odometer (optional)'),
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
                    : const Text('Add to garage'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
