import 'package:material_ui/material_ui.dart';
import 'package:image_picker/image_picker.dart';
import '../backend.dart';
import '../ui_kit.dart';
import '../ui.dart';

class CheckoutScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final double totalSdg;
  final double appliedRate;

  const CheckoutScreen({
    super.key,
    required this.cartItems,
    required this.totalSdg,
    required this.appliedRate,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _phoneController = TextEditingController(text: Backend.phone);
  final _addressController = TextEditingController();
  final _senderNameController = TextEditingController();
  
  String _deliveryMethod = 'pickup'; // pickup, delivery
  String _city = 'عطبره'; // عطبره, الدامر, ابوحمد, بربر, شندي
  String _paymentMethod = 'bank_of_khartoum'; // cod, bank_of_khartoum
  String? _receiptUrl;
  bool _isUploading = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    _senderNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_phoneController.text.isEmpty) {
      Backend.toast('يرجى إدخال رقم الهاتف السوداني');
      return;
    }
    if (_paymentMethod == 'bank_of_khartoum' && (_receiptUrl == null || _senderNameController.text.isEmpty)) {
      Backend.toast('يرجى إرفاق إشعار التحويل واسم المحول');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final orderNum = 'DMC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      
      final order = await Backend.insert(T.orders, {
        'order_number': orderNum,
        'customer_id': Backend.userId,
        'customer_name': Backend.fullName,
        'customer_phone': _phoneController.text,
        'delivery_method': _deliveryMethod,
        'city': _deliveryMethod == 'delivery' ? _city : null,
        'delivery_address': _deliveryMethod == 'delivery' ? _addressController.text : null,
        'payment_method': _paymentMethod,
        'usd_exchange_rate_applied': widget.appliedRate,
        'total_sdg': widget.totalSdg,
        'transfer_sender_name': _paymentMethod == 'bank_of_khartoum' ? _senderNameController.text : null,
        'transfer_receipt_url': _receiptUrl,
        'status': _paymentMethod == 'bank_of_khartoum' ? 'pending_payment_review' : 'processing',
      });

      final List<Map<String, dynamic>> items = [];
      for (var item in widget.cartItems) {
        final p = item['product'] as Map<String, dynamic>;
        final qty = (item['quantity'] as num).toInt();
        final priceUsd = (p['price_usd'] as num).toDouble();
        final priceSdg = priceUsd * widget.appliedRate;
        
        items.add({
          'order_id': order['id'],
          'product_id': p['id'],
          'product_name': p['name'],
          'quantity': qty,
          'price_usd': priceUsd,
          'price_sdg': priceSdg,
          'subtotal_sdg': priceSdg * qty,
        });
        
        // Clean cart
        await Backend.delete(T.cartItems, item['id']);
      }
      await Backend.insertMany(T.orderItems, items);

      // Notify admin
      await Backend.notify(
        toRole: 'admin',
        title: 'طلب جديد بانتظار مطابقة التحويل',
        body: 'قام ${Backend.fullName} بطلب جديد بقيمة ${money(widget.totalSdg)}',
      );

      Backend.toast('تم إرسال طلبك بنجاح');
      if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
    } catch (e) {
      Backend.toast('حدث خطأ أثناء إرسال الطلب');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'إتمام الطلب',
      back: true,
      bottom: CheckoutBar(
        label: 'تأكيد الطلب',
        total: widget.totalSdg,
        onPressed: _submit,
        busy: _isSubmitting,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Gap.md),
        children: [
          const SectionHeader('معلومات التواصل'),
          AppField(label: 'رقم الهاتف السوداني', controller: _phoneController, icon: Icons.phone, keyboard: TextInputType.phone),
          const SizedBox(height: Gap.lg),
          
          const SectionHeader('طريقة الاستلام'),
          ChoiceRow(
            options: const {'pickup': 'استلام من المحل', 'delivery': 'توصيل'},
            selected: _deliveryMethod,
            onSelected: (v) => setState(() => _deliveryMethod = v),
          ),
          if (_deliveryMethod == 'delivery') ...[
            const SizedBox(height: Gap.md),
            ChoiceRow(
              options: const {'عطبره': 'عطبرة', 'الدامر': 'الدامر', 'ابوحمد': 'أبوحمد', 'بربر': 'بربر', 'شندي': 'شندي'},
              selected: _city,
              onSelected: (v) => setState(() => _city = v),
            ),
            const SizedBox(height: Gap.md),
            AppField(label: 'العنوان بالتفصيل', controller: _addressController, icon: Icons.location_on, lines: 2),
          ],
          const SizedBox(height: Gap.lg),

          const SectionHeader('طريقة الدفع'),
          ChoiceRow(
            options: const {'bank_of_khartoum': 'بنك الخرطوم', 'cod': 'عند الاستلام'},
            selected: _paymentMethod,
            onSelected: (v) => setState(() => _paymentMethod = v),
          ),
          if (_paymentMethod == 'bank_of_khartoum') ...[
            const SizedBox(height: Gap.md),
            LiveQuery<List<Map<String, dynamic>>>(
              load: () => Backend.list(T.settings),
              builder: (context, rows) {
                final s = rows.isNotEmpty ? rows.first : {};
                return InfoBanner(
                  'الاسم: ${s['bok_account_name'] ?? 'ديالا للمعدات الطبية'}\nرقم الحساب: ${s['bok_account_number'] ?? '123456789'}',
                  title: 'بيانات الحساب',
                  tone: Tone.info,
                );
              },
            ),
            const SizedBox(height: Gap.md),
            AppField(label: 'اسم المحول (للمطابقة)', controller: _senderNameController, icon: Icons.person),
            const SizedBox(height: Gap.md),
            AppCard(
              onTap: () async {
                setState(() => _isUploading = true);
                final url = await pickAndUploadReceipt(ImageSource.gallery);
                if (mounted) setState(() { _receiptUrl = url; _isUploading = false; });
              },
              child: _receiptUrl == null 
                ? Center(
                    child: _isUploading 
                      ? const CircularProgressIndicator() 
                      : const Column(
                          children: [
                            Icon(Icons.upload_file, size: 40),
                            SizedBox(height: Gap.sm),
                            Text('ارفق صورة الإشعار'),
                          ],
                        ),
                  )
                : AppImage(_receiptUrl!, height: 150, width: double.infinity),
            ),
          ],
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}
