import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_theme.dart';
import '../services/api_config.dart';
import '../services/backend_service.dart';
import 'chat_list_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  bool _autoAddAgent = true;
  final List<_MemberChip> _members = [];
  File? _selectedImage;
  String? _uploadedImageUrl;
  bool _isUploading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addMember() async {
    final status = await Permission.contacts.status;
    if (!status.isGranted) {
      final rationale = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Contacts Permission'),
          content: const Text('PlanMate needs access to your contacts to add group members quickly.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Deny')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Allow')),
          ],
        ),
      );
      if (rationale != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contacts permission denied — you can still add members manually.')),
          );
        }
        return;
      }
      final requested = await Permission.contacts.request();
      if (!requested.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contacts permission denied')),
          );
        }
        return;
      }
    }

    final contacts = await FlutterContacts.getContacts(withProperties: true, withPhoto: true);
    if (!mounted) return;

    final selected = await showModalBottomSheet<Contact>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Select Contact', style: AppTheme.titleLarge),
            ),
            SizedBox(
              height: 400,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: contacts.length,
                itemBuilder: (ctx, i) {
                  final c = contacts[i];
                  final displayName = c.displayName;
                  final phone = c.phones.isNotEmpty ? c.phones.first.number : '';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primary.withOpacity(0.1),
                      backgroundImage: c.thumbnail != null ? MemoryImage(c.thumbnail!) : null,
                      child: c.thumbnail == null
                          ? Text(
                              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            )
                          : null,
                    ),
                    title: Text(displayName, style: AppTheme.bodyLarge),
                    subtitle: Text(phone, style: AppTheme.bodySmall),
                    onTap: () => Navigator.pop(ctx, c),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (selected != null) {
      final name = selected.displayName.trim();
      final phone = selected.phones.isNotEmpty ? selected.phones.first.number.replaceAll(RegExp(r'[^0-9+]'), '') : '';
      if (name.isNotEmpty) {
        setState(() {
          _members.add(_MemberChip(name: name, phone: phone));
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Create New Group'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPhotoButton(),
            const SizedBox(height: 24),
            _buildNameField(),
            const SizedBox(height: 28),
            _buildMembersSection(),
            const SizedBox(height: 20),
            _buildAgentToggle(),
            const SizedBox(height: 32),
            _buildCreateButton(),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage() async {
    final photoStatus = await Permission.photos.status;
    if (!photoStatus.isGranted) {
      final rationale = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Photos Permission'),
          content: const Text('PlanMate needs access to your photos to set a group picture.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Deny')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Allow')),
          ],
        ),
      );
      if (rationale != true) return;
      final requested = await Permission.photos.request();
      if (!requested.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photos permission denied')),
          );
        }
        return;
      }
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() {
      _selectedImage = File(picked.path);
      _isUploading = true;
    });

    try {
      final result = await BackendService.instance.uploadImage(picked.path);
      final url = result['url'] as String? ?? '';
      setState(() {
        _uploadedImageUrl = url.startsWith('http')
            ? url
            : '${ApiConfig.backendUrl}$url';
        _isUploading = false;
      });
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  Widget _buildPhotoButton() {
    return Center(
      child: GestureDetector(
        onTap: _isUploading ? null : _pickAndUploadImage,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.08),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.primary.withOpacity(0.2),
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
          child: _isUploading
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : _selectedImage != null
                  ? ClipOval(
                      child: Image.file(
                        _selectedImage!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Icon(
                      Icons.add_a_photo_outlined,
                      size: 28,
                      color: AppTheme.primary,
                    ),
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Group Name', style: AppTheme.labelLarge.copyWith(
          color: AppTheme.textSecondary,
        )),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          style: AppTheme.bodyLarge,
          decoration: AppTheme.inputDecoration(
            hintText: 'e.g., Weekend Trip 2025',
          ),
        ),
      ],
    );
  }

  Widget _buildMembersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Add Members', style: AppTheme.labelLarge.copyWith(
              color: AppTheme.textSecondary,
            )),
            const Spacer(),
            Text(
              '${_members.length} selected',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.primary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_members.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              'No members added yet. Tap below to add.',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textHint),
              textAlign: TextAlign.center,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _members.map((m) => _buildChip(m)).toList(),
          ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _addMember,
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_add_outlined,
                  size: 18,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Add by phone number',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChip(_MemberChip member) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                member.name[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            member.name,
            style: AppTheme.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              setState(() => _members.remove(member));
            },
            child: const Icon(
              Icons.close,
              size: 16,
              color: AppTheme.textHint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.agentBubble.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.agentBubble),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.agentBubbleDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Auto-add AI agent',
                  style: AppTheme.labelLarge.copyWith(
                    color: AppTheme.primaryDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Agent helps summarize and plan',
                  style: AppTheme.bodySmall.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: _autoAddAgent,
            onChanged: (val) => setState(() => _autoAddAgent = val),
            activeColor: AppTheme.agentBubbleDark,
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: () {
          final name = _nameController.text.trim();
          if (name.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please enter a group name'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }

          final memberNames = _members.map((m) => m.name).toList();

          // Add to store
          final group = GroupData(
            name: name,
            imagePath: _uploadedImageUrl,
            memberNames: memberNames,
            autoAddAgent: _autoAddAgent,
            creatorName: 'You',
          );
          GroupStore.instance.addGroup(group);

          // Navigate to that group's chat
          Navigator.of(context).pushReplacementNamed(
            '/group-chat',
            arguments: group,
          );
        },
        style: AppTheme.primaryButtonStyle,
        child: const Text('Create Group'),
      ),
    );
  }
}

class _MemberChip {
  final String name;
  final String phone;
  const _MemberChip({required this.name, this.phone = ''});
}
