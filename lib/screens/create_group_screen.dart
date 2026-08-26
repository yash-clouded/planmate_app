import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
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

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addMember() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: AppTheme.inputDecoration(hintText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: AppTheme.inputDecoration(hintText: 'Phone number'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              if (name.isNotEmpty) {
                setState(() {
                  _members.add(_MemberChip(
                    name: name,
                    phone: phone.isNotEmpty ? phone : '',
                  ));
                });
              }
              Navigator.pop(ctx);
            },
            style: AppTheme.primaryButtonStyle,
            child: const Text('Add'),
          ),
        ],
      ),
    );
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

  Widget _buildPhotoButton() {
    return Center(
      child: GestureDetector(
        onTap: () {},
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
          child: const Icon(
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
