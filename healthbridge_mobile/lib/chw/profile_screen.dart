import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/auth_provider.dart';
import '../services/profile_service.dart';
import '../models/user.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  bool _isEditing = false;
  bool _isLoading = true;
  // REMOVED: ChwProfile? _profile;  <--- This was never read

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final uid = authProvider.user?.uid;

    if (uid != null) {
      final profile = await _profileService.getProfile(uid);
      if (mounted) {
        setState(() {
          _isLoading = false;
          
          if (profile != null) {
            _nameController.text = profile.displayName;
            _phoneController.text = profile.phoneNumber;
            _addressController.text = profile.address;
            _bioController.text = profile.bio;
          } else {
            _nameController.text = authProvider.user?.displayName ?? 'CHW User';
          }
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final uid = authProvider.user?.uid;
    final email = authProvider.user?.email ?? '';

    if (uid != null) {
      final updatedProfile = ChwProfile(
        uid: uid,
        email: email,
        displayName: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        bio: _bioController.text.trim(),
      );

      await _profileService.saveProfile(updatedProfile);
      
      if (mounted) {
        setState(() {
          _isEditing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green),
        );
      }
    }
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: _isEditing ? _saveProfile : _toggleEdit,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                  ),
                  child: Center(
                    child: Text(
                      _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              _buildEditableField(
                label: 'Full Name',
                controller: _nameController,
                icon: Icons.person,
              ),
              const SizedBox(height: 16),

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.email, color: Color(0xFF6B7280)),
                title: const Text('Email Address', style: TextStyle(color: Color(0xFF6B7280))),
                subtitle: Text(authProvider.user?.email ?? 'No email', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(height: 16),

              _buildEditableField(
                label: 'Phone Number',
                controller: _phoneController,
                icon: Icons.phone,
              ),
              const SizedBox(height: 16),

              _buildEditableField(
                label: 'Address',
                controller: _addressController,
                icon: Icons.home,
              ),
              const SizedBox(height: 16),

              _buildEditableField(
                label: 'About Me',
                controller: _bioController,
                icon: Icons.description,
                maxLines: 3,
              ),

              const SizedBox(height: 30),

              // --- BUTTONS: Smaller and more professional ---
              if (!_isEditing) ...[
                SizedBox(
                  width: 200, // Smaller width
                  height: 44, // Shorter height
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/main');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                      side: const BorderSide(color: Color(0xFF1E3A8A)),
                    ),
                    child: const Text('Back to Dashboard', style: TextStyle(fontSize: 14)),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              SizedBox(
                width: 200, // Same smaller width
                height: 44, // Shorter height
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await authProvider.logout();
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, '/login');
                    }
                  },
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Log Out', style: TextStyle(fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: !_isEditing,
          maxLines: maxLines,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF6B7280)),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1E3A8A)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          style: TextStyle(
            fontWeight: _isEditing ? FontWeight.normal : FontWeight.w500,
            color: _isEditing ? Colors.black : const Color(0xFF1A1A2E),
          ),
        ),
      ],
    );
  }
}