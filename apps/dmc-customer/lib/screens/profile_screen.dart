import 'package:material_ui/material_ui.dart';
import '../backend.dart';
import '../ui_kit.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController(text: Backend.fullName);
  final _phoneController = TextEditingController(text: Backend.phone);
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'حسابي',
      body: ListView(
        padding: const EdgeInsets.all(Gap.md),
        children: [
          ProfileHeader(
            name: Backend.fullName,
            subtitle: Backend.phone,
          ),
          const SizedBox(height: Gap.lg),
          AppField(label: 'الاسم الكامل', controller: _nameController, icon: Icons.person),
          const SizedBox(height: Gap.md),
          AppField(label: 'رقم الهاتف', controller: _phoneController, icon: Icons.phone),
          const SizedBox(height: Gap.lg),
          AppButton(
            'تحديث الملف الشخصي',
            onPressed: () async {
              setState(() => _busy = true);
              try {
                await Backend.updateProfile({
                  'full_name': _nameController.text,
                  'phone': _phoneController.text,
                });
                Backend.toast('تم تحديث البيانات بنجاح');
              } catch (e) {
                Backend.toast('فشل تحديث البيانات');
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
            busy: _busy,
          ),
          const SizedBox(height: Gap.xl),
          SettingsGroup(
            title: 'الإعدادات',
            children: [
              SettingsTile(
                title: 'تسجيل الخروج',
                icon: Icons.logout,
                danger: true,
                onTap: () => Backend.signOut(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
