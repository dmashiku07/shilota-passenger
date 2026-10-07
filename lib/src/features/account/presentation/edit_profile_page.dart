import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../data/account_repository.dart';
import '../domain/account_models.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  static const routePath = '/edit-profile';

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _countryCodeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _imagePicker = ImagePicker();

  ProfileData? _profile;
  Uint8List? _selectedImageBytes;
  String _selectedImageName = 'profile.jpg';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _countryCodeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ref.read(accountRepositoryProvider).getProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _nameController.text = profile.fullName ?? '';
        _countryCodeController.text = profile.countryCode ?? '+255';
        _phoneController.text = profile.phoneNumber ?? '';
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('$error');
    }
  }

  Future<void> _pickImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _selectedImageBytes = bytes;
      _selectedImageName = image.name.isEmpty ? 'profile.jpg' : image.name;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      final repository = ref.read(accountRepositoryProvider);
      await repository.updateProfile(
        fullName: _nameController.text.trim(),
        countryCode: _countryCodeController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
      );
      if (_selectedImageBytes != null) {
        await repository.uploadProfileImage(
          bytes: _selectedImageBytes!,
          fileName: _selectedImageName,
        );
      }
      if (!mounted) return;
      _showMessage('Profile updated successfully');
      context.pop(true);
    } catch (error) {
      if (mounted) _showMessage('$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF9),
      appBar: AppBar(title: const Text('Edit Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 54,
                          backgroundColor: const Color(0xFFFCE7E1),
                          backgroundImage: _selectedImageBytes != null
                              ? MemoryImage(_selectedImageBytes!)
                              : ((_profile?.userImage?.isNotEmpty ?? false)
                                  ? NetworkImage(_profile!.userImage!)
                                  : null) as ImageProvider<Object>?,
                          child: _selectedImageBytes == null &&
                                  !(_profile?.userImage?.isNotEmpty ?? false)
                              ? const Icon(Icons.person,
                                  size: 48, color: Color(0xFFF04E29))
                              : null,
                        ),
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: IconButton.filled(
                            onPressed: _saving ? null : _pickImage,
                            tooltip: 'Choose profile photo',
                            icon: const Icon(Icons.camera_alt_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (value) => (value?.trim().length ?? 0) < 2
                        ? 'Enter your full name'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: _profile?.email ?? '',
                    enabled: false,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 105,
                        child: TextFormField(
                          controller: _countryCodeController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'Code'),
                          validator: (value) => (value?.trim().isEmpty ?? true)
                              ? 'Required'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone number',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          validator: (value) => (value?.trim().length ?? 0) < 7
                              ? 'Enter a valid phone number'
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(_saving ? 'Saving...' : 'Save changes'),
                  ),
                ],
              ),
            ),
    );
  }
}
