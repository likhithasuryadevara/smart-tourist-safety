import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EditProfileDialog extends StatefulWidget {
  final Map<String, dynamic>? userData;
  final VoidCallback onSaved;

  const EditProfileDialog({
    super.key,
    required this.userData,
    required this.onSaved,
  });

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _nationalityController;
  late final TextEditingController _bloodGroupController;
  late final TextEditingController _emergencyNameController;
  late final TextEditingController _emergencyPhoneController;
  late final TextEditingController _emergencyRelationshipController;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.userData?['name']?.toString() ?? '',
    );

    _phoneController = TextEditingController(
      text: widget.userData?['phone']?.toString() ?? '',
    );

    _nationalityController = TextEditingController(
      text: widget.userData?['nationality']?.toString() ?? '',
    );

       _bloodGroupController = TextEditingController(
      text: widget.userData?['bloodGroup']?.toString() ?? '',
    );

    _emergencyNameController = TextEditingController(
      text: widget.userData?['emergencyContactName']?.toString() ?? '',
    );

    _emergencyPhoneController = TextEditingController(
      text: widget.userData?['emergencyContactPhone']?.toString() ?? '',
    );

    _emergencyRelationshipController = TextEditingController(
      text: widget.userData?['emergencyContactRelationship']?.toString() ?? '',
    );
  }
  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _nationalityController.dispose();
    _bloodGroupController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _emergencyRelationshipController.dispose();

    super.dispose();
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    if (_nameController.text.trim().isEmpty) {
      _showError('Name cannot be empty.');
      return;
    }

    if (_phoneController.text.trim().isEmpty) {
      _showError('Phone number cannot be empty.');
      return;
    }
    final phone = _phoneController.text.trim();

    if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(phone)) {
      _showError('Enter a valid 10-digit Indian mobile number.');
      return;
    }
    final emergencyName = _emergencyNameController.text.trim();
    final emergencyPhone = _emergencyPhoneController.text.trim();
    final emergencyRelationship =
        _emergencyRelationshipController.text.trim();

    final emergencyFieldsFilled =
        emergencyName.isNotEmpty ||
        emergencyPhone.isNotEmpty ||
        emergencyRelationship.isNotEmpty;

    if (emergencyFieldsFilled) {
      if (emergencyName.isEmpty ||
          emergencyPhone.isEmpty ||
          emergencyRelationship.isEmpty) {
        _showError('Please complete all emergency contact fields.');
        return;
      }

      if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(emergencyPhone)) {
        _showError(
          'Enter a valid 10-digit emergency contact number.',
        );
        return;
      }
    }

    setState(() {
      _saving = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'nationality': _nationalityController.text.trim(),
        'bloodGroup': _bloodGroupController.text.trim(),
        'emergencyContactName': _emergencyNameController.text.trim(),
        'emergencyContactPhone': _emergencyPhoneController.text.trim(),
        'emergencyContactRelationship':
            _emergencyRelationshipController.text.trim(),
      });

      if (!mounted) return;

      Navigator.pop(context);
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _showError('Unable to update profile.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),

            const SizedBox(height: 14),

            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),

            const SizedBox(height: 14),

            TextField(
              controller: _nationalityController,
              decoration: const InputDecoration(
                labelText: 'Nationality',
                prefixIcon: Icon(Icons.public),
              ),
            ),

            const SizedBox(height: 14),

            TextField(
              controller: _bloodGroupController,
              decoration: const InputDecoration(
                labelText: 'Blood Group',
                prefixIcon: Icon(Icons.bloodtype_outlined),
              ),
            ),
                        const SizedBox(height: 14),

            TextField(
              controller: _emergencyNameController,
              decoration: const InputDecoration(
                labelText: 'Emergency Contact Name',
                prefixIcon: Icon(Icons.contact_emergency_outlined),
              ),
            ),

            const SizedBox(height: 14),

            TextField(
              controller: _emergencyPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Emergency Contact Phone',
                prefixIcon: Icon(Icons.phone_in_talk_outlined),
              ),
            ),

            const SizedBox(height: 14),

            TextField(
              controller: _emergencyRelationshipController,
              decoration: const InputDecoration(
                labelText: 'Emergency Relationship',
                prefixIcon: Icon(Icons.people_outline),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),

        ElevatedButton(
          onPressed: _saving ? null : _saveProfile,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Text('Save Changes'),
        ),
      ],
    );
  }
}