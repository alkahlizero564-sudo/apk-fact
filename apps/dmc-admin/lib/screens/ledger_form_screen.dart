import 'package:material_ui/material_ui.dart';
import '../backend.dart';
import '../ui_kit.dart';

class LedgerFormScreen extends StatefulWidget {
  final Map<String, dynamic>? record;
  const LedgerFormScreen({super.key, this.record});

  @override
  State<LedgerFormScreen> createState() => _LedgerFormScreenState();
}

class _LedgerFormScreenState extends State<LedgerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late final TextEditingController _invoice;
  late final TextEditingController _desc;
  String _type = 'purchase';
  String _city = 'عطبره';
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    _title = TextEditingController(text: r?['title'] ?? '');
    _amount = TextEditingController(text: r?['amount_sdg']?.toString() ?? '');
    _invoice = TextEditingController(text: r?['invoice_number'] ?? '');
    _desc = TextEditingController(text: r?['description'] ?? '');
    _type = r?['record_type'] ?? 'purchase';
    _city = r?['city'] ?? 'عطبره';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isBusy = true);
    try {
      final data = {
        'title': _title.text,
        'amount_sdg': double.tryParse(_amount.text) ?? 0.0,
        'invoice_number': _invoice.text,
        'description': _desc.text,
        'record_type': _type,
        'city': _city,
        'invoice_image_url': widget.record?['invoice_image_url'],
        'is_ai_parsed': widget.record?['is_ai_parsed'] ?? false,
        'record_date': DateTime.now().toIso8601String().split('T')[0],
      };

      if (widget.record?['id'] != null) {
        await Backend.update(T.ledgerRecords, widget.record!['id'], data);
        Backend.toast('تم تحديث الفاتورة بالسجل بنجاح');
      } else {
        await Backend.insert(T.ledgerRecords, data);
        Backend.toast('تم إدراج الفاتورة في السجل المالي الموحد');
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      Backend.toast('خطأ في الحفظ: $e');
    } finally {
      setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: widget.record?['id'] == null ? 'إضافة سجل مالي' : 'تعديل السجل المالي',
      back: true,
      body: Form(
        key: _formKey,
        child: ListView(
          children: [
            ChoiceRow(
              options: const {'purchase': 'مشتريات (-)', 'sale': 'مبيعات (+)'},
              selected: _type,
              onSelected: (v) => setState(() => _type = v),
            ),
            Gap.h16,
            AppField(
              label: 'البيان / عنوان المعاملة',
              controller: _title,
              icon: Icons.title_rounded,
              validator: (v) => v!.isEmpty ? 'يرجى كتابة البيان' : null,
            ),
            Gap.h12,
            AppField(
              label: 'المبلغ الإجمالي (ج.س)',
              controller: _amount,
              icon: Icons.payments_rounded,
              keyboard: TextInputType.number,
              validator: (v) => v!.isEmpty ? 'يرجى إدخال المبلغ' : null,
            ),
            Gap.h12,
            AppField(
              label: 'رقم الفاتورة',
              controller: _invoice,
              icon: Icons.numbers_rounded,
            ),
            Gap.h12,
            ChoiceRow(
              options: const {'عطبره': 'عطبره', 'الدامر': 'الدامر', 'ابوحمد': 'ابوحمد', 'بربر': 'بربر', 'شندي': 'شندي'},
              selected: _city,
              onSelected: (v) => setState(() => _city = v),
            ),
            Gap.h12,
            AppField(
              label: 'ملاحظات وتفاصيل الأصناف',
              controller: _desc,
              icon: Icons.notes_rounded,
              lines: 3,
            ),
            Gap.h16,
            if (widget.record?['invoice_image_url'] != null && widget.record!['invoice_image_url'].toString().isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AppImage(widget.record!['invoice_image_url'], height: 160, width: double.infinity),
              ),
            Gap.h24,
            AppButton(
              'حفظ السجل المالي',
              onPressed: _save,
              expand: true,
              busy: _isBusy,
              icon: Icons.check_circle_rounded,
            ),
            Gap.h16,
          ],
        ),
      ),
    );
  }
}
