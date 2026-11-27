import 'package:material_ui/material_ui.dart';
import 'package:image_picker/image_picker.dart';
import '../backend.dart';
import '../ui_kit.dart';

class ProductFormScreen extends StatefulWidget {
  final Map<String, dynamic>? product;
  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _stock;
  late final TextEditingController _desc;
  String? _imageUrl;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.product?['name'] ?? '');
    _price = TextEditingController(text: widget.product?['price_usd']?.toString() ?? '');
    _stock = TextEditingController(text: widget.product?['stock_quantity']?.toString() ?? '100');
    _desc = TextEditingController(text: widget.product?['description'] ?? '');
    _imageUrl = widget.product?['image_url'];
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _isBusy = true);
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: source);
      if (image == null) {
        setState(() => _isBusy = false);
        return;
      }
      final bytes = await image.readAsBytes();
      final url = await Backend.uploadFile(bytes, extension: 'jpg');
      setState(() => _imageUrl = url);
      Backend.toast('تم رفع صورة المنتج بنجاح');
    } catch (e) {
      if (e.toString().contains('permission') || e.toString().contains('denied')) {
        Backend.toast('عذراً، يرجى السماح بالوصول للصور أو الكاميرا من إعدادات الهاتف');
      } else {
        Backend.toast('فشل رفع الصورة: $e');
      }
    } finally {
      setState(() => _isBusy = false);
    }
  }

  void _showImagePickerChoice() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C2541),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('صورة المنتج الطبي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF00E5FF)),
              title: const Text('التقاط صورة بالكاميرا', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF00E5FF)),
              title: const Text('اختيار من معرض الصور', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isBusy = true);
    try {
      final data = {
        'name': _name.text,
        'price_usd': double.tryParse(_price.text) ?? 0.0,
        'stock_quantity': int.tryParse(_stock.text) ?? 100,
        'description': _desc.text,
        'image_url': _imageUrl ?? '',
      };

      if (widget.product != null) {
        await Backend.update(T.products, widget.product!['id'], data);
        Backend.toast('تم تحديث بيانات المنتج وتحديث أسعاره للزبائن');
      } else {
        await Backend.insert(T.products, data);
        Backend.toast('تمت إضافة المنتج الجديد للكتالوج بنجاح');
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (e.toString().contains('400')) {
        Backend.toast('خطأ 400: تحقق من صحة الحقول المدخلة');
      } else {
        Backend.toast('خطأ في الحفظ: $e');
      }
    } finally {
      setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: widget.product == null ? 'إضافة منتج جديد' : 'تعديل المنتج الطبي',
      back: true,
      body: Form(
        key: _formKey,
        child: ListView(
          children: [
            GestureDetector(
              onTap: _showImagePickerChoice,
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C2541),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x3000E5FF), width: 1.5),
                ),
                child: _imageUrl != null && _imageUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AppImage(
                          _imageUrl!,
                          height: 180,
                          width: double.infinity,
                        ),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_rounded, size: 48, color: Color(0xFF00E5FF)),
                          Gap.h8,
                          Text('اضغط هنا لاختيار أو التقاط صورة المنتج', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                        ],
                      ),
              ),
            ),
            Gap.h16,
            AppField(
              label: 'اسم المنتج الطبي / المستهلك',
              controller: _name,
              icon: Icons.medication_rounded,
              validator: (v) => v!.isEmpty ? 'يرجى إدخال اسم المنتج' : null,
            ),
            Gap.h12,
            AppField(
              label: 'السعر بالدولار (\$)',
              controller: _price,
              icon: Icons.attach_money_rounded,
              keyboard: TextInputType.number,
              validator: (v) => v!.isEmpty ? 'مطلوب تحديد السعر بالدولار' : null,
            ),
            Gap.h12,
            AppField(
              label: 'الكمية المتوفرة بالمخزون',
              controller: _stock,
              icon: Icons.inventory_2_rounded,
              keyboard: TextInputType.number,
            ),
            Gap.h12,
            AppField(
              label: 'وصف المنتج واستخداماته الطبية',
              controller: _desc,
              icon: Icons.description_rounded,
              lines: 3,
            ),
            Gap.h24,
            AppButton(
              widget.product == null ? 'إضافة المنتج للقائمة' : 'حفظ التعديلات وتحديث الأسعار',
              onPressed: _save,
              expand: true,
              busy: _isBusy,
              icon: Icons.save_rounded,
            ),
            Gap.h16,
          ],
        ),
      ),
    );
  }
}
