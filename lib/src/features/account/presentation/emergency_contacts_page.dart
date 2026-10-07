import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/account_repository.dart';
import '../domain/account_models.dart';

class EmergencyContactsPage extends ConsumerStatefulWidget {
  const EmergencyContactsPage({
    super.key,
    required this.args,
  });

  static const routePath = '/emergency-contacts';

  final EmergencyContactsArgs args;

  @override
  ConsumerState<EmergencyContactsPage> createState() =>
      _EmergencyContactsPageState();
}

class _EmergencyContactsPageState extends ConsumerState<EmergencyContactsPage> {
  late List<EmergencyContact> _contacts;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _contacts = [...widget.args.contacts];
  }

  Future<void> _saveContacts() async {
    setState(() => _isSaving = true);
    try {
      await ref
          .read(accountRepositoryProvider)
          .updateEmergencyContacts(_contacts);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Emergency contacts updated')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _openEditor({EmergencyContact? contact, int? index}) async {
    final result = await showModalBottomSheet<EmergencyContact>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _EmergencyContactEditor(
        initial: contact,
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      if (index == null) {
        _contacts = [..._contacts, result];
      } else {
        _contacts = [
          for (var i = 0; i < _contacts.length; i++)
            if (i == index) result else _contacts[i],
        ];
      }
    });
  }

  void _remove(int index) {
    setState(() {
      _contacts = [
        for (var i = 0; i < _contacts.length; i++)
          if (i != index) _contacts[i],
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF9),
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _contacts.length >= 3 ? null : _openEditor,
        backgroundColor: const Color(0xFFF04E29),
        label: const Text('Add Contact'),
        icon: const Icon(Icons.add_rounded),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Add up to 3 people who should be contacted during an Emergency Alert.',
              style: TextStyle(color: Color(0xFF6A5D57), height: 1.5),
            ),
          ),
          const SizedBox(height: 18),
          if (_contacts.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'No emergency contacts added yet.',
                style: TextStyle(color: Color(0xFF6A5D57)),
              ),
            )
          else
            for (var index = 0; index < _contacts.length; index++) ...[
              _ContactTile(
                contact: _contacts[index],
                onEdit: () => _openEditor(
                  contact: _contacts[index],
                  index: index,
                ),
                onDelete: () => _remove(index),
              ),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveContacts,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save Contacts'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.contact,
    required this.onEdit,
    required this.onDelete,
  });

  final EmergencyContact contact;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFFFEEE8),
            child: Icon(Icons.shield_outlined, color: Color(0xFFF04E29)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name ?? 'Contact',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  contact.phoneNumber ?? '-',
                  style: const TextStyle(color: Color(0xFF6A5D57)),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            tooltip: 'Edit contact',
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            onPressed: onDelete,
            tooltip: 'Delete contact',
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _EmergencyContactEditor extends StatefulWidget {
  const _EmergencyContactEditor({
    this.initial,
  });

  final EmergencyContact? initial;

  @override
  State<_EmergencyContactEditor> createState() =>
      _EmergencyContactEditorState();
}

class _EmergencyContactEditorState extends State<_EmergencyContactEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initial?.name ?? '');
    _phoneController =
        TextEditingController(text: widget.initial?.phoneNumber ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.initial == null ? 'Add Contact' : 'Edit Contact',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter name'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone number'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter phone number'
                    : null,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) {
                      return;
                    }
                    Navigator.of(context).pop(
                      EmergencyContact(
                        id: widget.initial?.id,
                        name: _nameController.text.trim(),
                        phoneNumber: _phoneController.text.trim(),
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
