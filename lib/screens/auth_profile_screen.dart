import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_theme.dart';
import '../services/api_config.dart';

class AuthProfileScreen extends StatefulWidget {
  const AuthProfileScreen({super.key});

  @override
  State<AuthProfileScreen> createState() => _AuthProfileScreenState();
}

class _AuthProfileScreenState extends State<AuthProfileScreen> {
  final _nameController = TextEditingController();
  bool _isValid = false;
  File? _selectedImage;
  String? _uploadedImageUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_validate);
  }

  void _validate() {
    final valid = _nameController.text.trim().length >= 2;
    if (valid != _isValid) {
      setState(() => _isValid = valid);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - kToolbarHeight,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    'Complete your profile',
                    style: AppTheme.headlineLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Add your name and photo so your group can recognize you.',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildAvatarPicker(),
                  const SizedBox(height: 32),
                  _buildNameField(),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isValid ? () {
                        Navigator.of(context).pushReplacementNamed('/home');
                      } : null,
                      style: AppTheme.primaryButtonStyle.copyWith(
                        backgroundColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.disabled)) {
                            return AppTheme.primary.withOpacity(0.4);
                          }
                          return AppTheme.primary;
                        }),
                        foregroundColor: WidgetStateProperty.all(Colors.white),
                      ),
                      child: const Text('Continue to Home'),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickAvatar() async {
    final photoStatus = await Permission.photos.status;
    if (!photoStatus.isGranted) {
      final rationale = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Photos Permission'),
          content: const Text('PlanMate needs access to your photos to set a profile picture.'),
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
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() {
      _selectedImage = File(picked.path);
      _isUploading = true;
    });

    try {
      final uri = Uri.parse('${ApiConfig.backendUrl}/webhooks/upload/image');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('file', picked.path));
      final streamed = await request.send().timeout(const Duration(seconds: 20));
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final url = data['url'] as String? ?? '';
        setState(() {
          _uploadedImageUrl = url.startsWith('http') ? url : '${ApiConfig.backendUrl}$url';
          _isUploading = false;
        });
      } else {
        throw Exception('Upload failed: ${resp.statusCode}');
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }
  Widget _buildAvatarPicker() {
    return Center(
      child: GestureDetector(
        onTap: _isUploading ? null : _pickAvatar,
        child: Stack(
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.primary.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: _selectedImage != null
                  ? ClipOval(
                      child: Image.file(
                        _selectedImage!,
                        width: 110,
                        height: 110,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Icon(
                      Icons.person,
                      size: 50,
                      color: AppTheme.primary,
                    ),
            ),
            if (!_isUploading)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.3),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            if (_isUploading)
              Positioned.fill(
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: const BoxDecoration(
                    color: Colors.black26,
                    shape: BoxShape.circle,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Name', style: AppTheme.labelLarge.copyWith(color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          style: AppTheme.bodyLarge,
          decoration: AppTheme.inputDecoration(
            hintText: 'Enter your name',
          ),
        ),
      ],
    );
  }
}
