import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:google_fonts/google_fonts.dart';

import 'native_api.dart';
import 'account_statement.dart';
import 'bulk_trusted_import.dart';
import 'manual_debt_dialog.dart';
import 'package_rules.dart';
import 'selected_features.dart';
import 'sms_templates_page.dart';
import 'service_diagnostics_page.dart';
import 'whatsapp_utils.dart';
import 'skeleton_widgets.dart';
import 'report_metrics.dart';
import 'cloud_sync_settings.dart';
import 'design_system.dart';

const emerald = Color(0xFF10B981),
    blue = Color(0xFF0284C7),
    ink = Color(0xFF0A0F1A);
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('preferences');
  await Hive.openBox('sync_queue');
  try {
    await NativeApi.instance.initialize();
  } catch (_) {}
  runApp(const CardBotApp());
}

class CardBotApp extends StatefulWidget {
  const CardBotApp({super.key});
  @override
  State<CardBotApp> createState() => _CardBotAppState();
}

class _CardBotAppState extends State<CardBotApp> {
  final box = Hive.box('preferences');
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (_, __, ___) {
          final dark = box.get('dark', defaultValue: false) as bool;
          return MaterialApp(
            title: 'القاضي نت',
            debugShowCheckedModeBanner: false,
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            theme: _theme(false),
            darkTheme: _theme(true),
            home: const MainShell(),
          );
        },
      );
}

ThemeData _theme(bool dark) => ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: emerald,
        primary: emerald,
        secondary: const Color(0xFFB08D57),
        brightness: dark ? Brightness.dark : Brightness.light,
      ),
      scaffoldBackgroundColor: dark ? ink : const Color(0xFFF5F0E6),
      textTheme: GoogleFonts.cairoTextTheme(),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: dark ? const Color(0xFF151D2A) : Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
    );

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  bool loading = true;
  Map<String, dynamic> data = {};
  final labels = [
    'الرئيسية',
    'المبيعات',
    'المخزون',
    'العملاء',
    'التقارير',
    'الإعدادات',
  ];
  final icons = [
    Icons.home_rounded,
    Icons.shopping_cart_rounded,
    Icons.inventory_2_rounded,
    Icons.people_alt_rounded,
    Icons.bar_chart_rounded,
    Icons.settings_rounded,
  ];
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    try {
      final d = await NativeApi.instance.refresh();
      if (mounted) setState(() => data = d);
    } catch (_) {
      data = NativeApi.instance.snapshot;
      if (mounted) setState(() => data = data);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = Hive.box('preferences');
    final privacyMode =
        preferences.get('privacyMode', defaultValue: false) as bool;
    final oneHanded = preferences.get('oneHanded', defaultValue: false) as bool;
    final pages = [
      HomePage(
        data: data,
        onRefresh: refresh,
        onOpen: (i) => setState(() => index = i),
      ),
      SalesPage(data: data, onRefresh: refresh),
      InventoryPage(data: data, onRefresh: refresh),
      ClientsPage(data: data, onRefresh: refresh),
      ReportsPage(data: data),
      SettingsPage(data: data, onRefresh: refresh),
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Stack(
          children: [
            SafeArea(
              child: loading
                  ? const AppSkeleton(dashboard: true, rows: 2)
                  : RefreshIndicator(
                      onRefresh: refresh,
                      child: IndexedStack(index: index, children: pages),
                    ),
            ),
            if (privacyMode)
              Positioned.fill(
                child: ColoredBox(
                  color: ink.withValues(alpha: .97),
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.visibility_off,
                          size: 54, color: Colors.white),
                      const SizedBox(height: 12),
                      const Text('وضع الخصوصية مفعّل',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: () => preferences.put('privacyMode', false),
                        icon: const Icon(Icons.visibility),
                        label: const Text('إظهار بيانات التطبيق'),
                      ),
                    ]),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => setState(() => index = i),
          destinations: List.generate(
            6,
            (i) =>
                NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
          ),
          height: oneHanded ? 78 : 68,
        ),
        floatingActionButton: index == 0 || index == 1
            ? (oneHanded
                ? FloatingActionButton.extended(
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => SaleSheet(data: data, onDone: refresh),
                    ),
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('بيع سريع'),
                  )
                : FloatingActionButton(
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => SaleSheet(data: data, onDone: refresh),
                    ),
                    child: const Icon(Icons.add),
                  ))
            : null,
      ),
    );
  }
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
List<dynamic> _list(dynamic value) => value is List ? value : <dynamic>[];
List<Map<String, dynamic>> _packages(Map<String, dynamic> data) =>
    _list(_map(data['packages'])['packages']).map(_map).toList();
List<String> _parsePackageKeywords(String value) {
  final unique = <String, String>{};
  for (final part in value.split(RegExp(r'[,،;\n\r]+'))) {
    final keyword = part.trim();
    if (keyword.isNotEmpty)
      unique.putIfAbsent(keyword.toLowerCase(), () => keyword);
  }
  return unique.values.toList();
}

List<Map<String, dynamic>> _sales(Map<String, dynamic> data) =>
    _list(data['sales']).map(_map).toList().reversed.toList();
List<Map<String, dynamic>> _debts(Map<String, dynamic> data) =>
    _list(data['debts']).map(_map).toList();
Map<String, dynamic> _inventory(Map<String, dynamic> data) =>
    _map(data['inventory']);
String _clientDisplayName(String phone, Map<String, dynamic> data) {
  String keyOf(String value) => _phoneKey(value);

  final key = keyOf(phone);
  for (final list in [
    _list(_map(data['permissions'])['clients']),
    _list(_map(data['trusted'])['clients']),
    _list(_map(data['trusted'])['archivedClients']),
  ]) {
    for (final value in list) {
      final client = _map(value);
      if (keyOf('${client['phone'] ?? ''}') == key &&
          '${client['name'] ?? ''}'.trim().isNotEmpty) {
        return '${client['name']}'.trim();
      }
    }
  }
  for (final value in _list(data['transactions']).reversed) {
    final transaction = _map(value);
    if (keyOf('${transaction['phone'] ?? ''}') == key &&
        '${transaction['clientName'] ?? ''}'.trim().isNotEmpty) {
      return '${transaction['clientName']}'.trim();
    }
  }
  return phone;
}

String _phoneKey(String value) {
  final localized = String.fromCharCodes(value.runes.map((rune) {
    if (rune >= 0x0660 && rune <= 0x0669) return rune - 0x0660 + 0x30;
    if (rune >= 0x06F0 && rune <= 0x06F9) return rune - 0x06F0 + 0x30;
    return rune;
  }));
  var digits = localized.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('00967')) {
    digits = digits.substring(5);
  } else if (digits.startsWith('967')) {
    digits = digits.substring(3);
  }
  digits = digits.replaceFirst(RegExp(r'^0+'), '');
  return digits.length <= 10 ? digits : digits.substring(digits.length - 10);
}

int _manualDebtBalance(String phone, Map<String, dynamic> data) {
  final key = _phoneKey(phone);
  for (final debt in _debts(data)) {
    if (_phoneKey('${debt['phone'] ?? ''}') == key) {
      final amount = debt['amount'];
      return amount is num ? amount.toInt() : int.tryParse('$amount') ?? 0;
    }
  }
  return 0;
}

Future<void> _addManualDebt(
  BuildContext context,
  Map<String, dynamic> data,
  Future<void> Function() onRefresh, {
  String? initialPhone,
  String? initialName,
}) async {
  final input = await showManualDebtDialog(
    context: context,
    balanceForPhone: (phone) => _manualDebtBalance(phone, data),
    initialPhone: initialPhone,
    initialName: initialName,
  );
  if (input == null) return;
  if (input.targetBalance == input.currentBalance) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرصيد المدخل يساوي الرصيد الحالي.')));
    }
    return;
  }
  try {
    await NativeApi.instance.setManualDebtBalance(
      phone: input.phone,
      targetBalance: input.targetBalance,
      reason: input.reason,
      clientName: input.name.isEmpty
          ? _clientDisplayName(input.phone, data)
          : input.name,
    );
    await onRefresh();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تم حفظ رصيد الدين وتحديث كشف الحساب.')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذر حفظ الدين: ${_err(e)}')));
    }
  }
}

List<String> _extractPdfCards(Uint8List bytes) {
  PdfDocument? document;
  try {
    document = PdfDocument(inputBytes: bytes);
    final text = PdfTextExtractor(document).extractText();
    return RegExp(r'(?<!\d)\d{4,24}(?!\d)')
        .allMatches(text)
        .map((match) => match.group(0)!)
        .toSet()
        .toList();
  } finally {
    document?.dispose();
  }
}

String _money(dynamic v) => '${v ?? 0} ر.ي';
String _whatsappStatusLabel(dynamic value) => switch ('$value') {
      'pending' => 'رد WhatsApp قيد الانتظار',
      'submitted' => 'مرّر Android الرد إلى WhatsApp؛ لم يؤكد الوصول',
      'failed' => 'فشل رد WhatsApp؛ البيع والكرت محفوظان لإعادة المحاولة',
      _ => '',
    };
String _err(Object e) =>
    e.toString().replaceFirst('PlatformException(', '').replaceAll(')', '');

class HomePage extends StatelessWidget {
  final Map<String, dynamic> data;
  final Future<void> Function() onRefresh;
  final ValueChanged<int> onOpen;
  const HomePage({
    super.key,
    required this.data,
    required this.onRefresh,
    required this.onOpen,
  });
  @override
  Widget build(BuildContext context) {
    final sales = _sales(data);
    final inv = _inventory(data);
    final trigger = _map(data['trigger']);
    final totalCards = inv.values.fold<int>(0, (a, v) => a + _list(v).length);
    final totalSales = sales.length;
    final revenue = sales.fold<num>(
      0,
      (a, s) =>
          a + (s['price'] as num? ?? int.tryParse('${s['packageId']}') ?? 0),
    );
    final readinessChecks = <MapEntry<String, bool>>[
      MapEntry('محرك استقبال الرسائل', trigger['triggerEnabled'] == true),
      MapEntry('قاعدة البيانات المحلية', data.isNotEmpty),
      MapEntry('المخزون محمّل', totalCards > 0),
      MapEntry(
          'قناة إرسال SMS', defaultTargetPlatform == TargetPlatform.android),
    ];
    final readyCount = readinessChecks.where((check) => check.value).length;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: emerald,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.wifi_tethering_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'القاضي نت',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                        Text(
                          'نظام بيع كروت الإنترنت',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  QaidiStatusPill(
                    label: trigger['triggerEnabled'] == true ? 'نشط' : 'متوقف',
                    color: trigger['triggerEnabled'] == true ? emerald : Colors.orange,
                    icon: trigger['triggerEnabled'] == true ? Icons.check_circle_outline : Icons.pause_circle_outline,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => onOpen(5),
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF059669), Color(0xFF0284C7)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bolt, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          trigger['triggerEnabled'] == true
                              ? 'المحرك نشط'
                              : 'المحرك متوقف',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.circle, size: 10, color: Colors.white),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${trigger['processedCount'] ?? 0} طلباً تمت معالجته • ${_money(revenue)} مبيعات مسجلة',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _glassStat('المخزون', '$totalCards بطاقة'),
                        _glassStat(
                          'الرسائل',
                          '${trigger['processedCount'] ?? 0} طلب',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      'المبيعات',
                      '$totalSales',
                      'هذا السجل',
                      Icons.receipt_long,
                      blue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statCard(
                      'أرصدة العملاء',
                      _money(
                        _debts(data).fold<num>(
                          0,
                          (a, d) => a + (d['amount'] as num? ?? 0),
                        ),
                      ),
                      'إجمالي الدين',
                      Icons.account_balance_wallet,
                      const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              QaidiSectionHeader(
                title: 'جاهزية النظام',
                subtitle: 'حالة المكونات المحلية والخدمات الأساسية',
                action: Text('$readyCount/${readinessChecks.length}', style: const TextStyle(color: emerald, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              Card(
                child: ExpansionTile(
                  title: Text(
                      'تفاصيل الجاهزية — $readyCount/${readinessChecks.length}'),
                  subtitle: const Text('اضغط لعرض حالة المكونات المحلية'),
                  leading: const Icon(Icons.health_and_safety_outlined),
                  children: [
                    Padding(
                      padding:
                          const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
                      child: Column(
                        children: readinessChecks
                            .map((check) => _checkRow(check.key, check.value))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
              if (_list(data['lowStockWarnings']).isNotEmpty)
                Card(
                  color: Colors.orange.withValues(alpha: .08),
                  child: Column(
                    children: [
                      const ListTile(
                        leading:
                            Icon(Icons.warning_amber, color: Colors.deepOrange),
                        title: Text('تنبيه انخفاض المخزون'),
                      ),
                      ..._list(data['lowStockWarnings'])
                          .map(_map)
                          .map((item) => ListTile(
                                dense: true,
                                title: Text('باقة ${item['packageId']}'),
                                trailing: Text(
                                    '${item['count']} متبقي (الحد ${item['threshold']})'),
                              )),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'الوصول السريع',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => onOpen(5),
                    child: const Text('إدارة الباقات'),
                  ),
                ],
              ),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  _quick(context, 'بيع كرت', Icons.shopping_cart, onOpen, 1),
                  _quick(context, 'المخزون', Icons.inventory_2, onOpen, 2),
                  _quick(context, 'العملاء', Icons.people, onOpen, 3),
                  _quick(context, 'التقارير', Icons.bar_chart, onOpen, 4),
                ],
              ),
              const SizedBox(height: 18),
              Card(
                child: ExpansionTile(
                  leading: const Icon(Icons.receipt_long, color: emerald),
                  title: const Text('آخر المبيعات'),
                  subtitle: Text('${sales.length} عملية مسجلة • عرض أحدث 4'),
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: () => onOpen(1),
                        child: const Text('عرض سجل المبيعات كاملاً'),
                      ),
                    ),
                    if (sales.isEmpty)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: EmptyCard(
                            text: 'لا توجد مبيعات بعد. أضف مخزوناً للبدء.'),
                      )
                    else
                      ...sales.take(4).map((sale) => SaleTile(sale: sale)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _requestAndStart(context),
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('تفعيل استقبال SMS والخدمة الدائمة'),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Future<void> _requestAndStart(BuildContext c) async {
    try {
      final res = await NativeApi.instance.requestPermissions();
      if (res[Permission.sms]?.isGranted != true ||
          res[Permission.notification]?.isGranted != true) {
        if (c.mounted)
          ScaffoldMessenger.of(c).showSnackBar(
            const SnackBar(
              content: Text(
                'اسمح بالرسائل والإشعارات من إعدادات أندرويد أولاً.',
              ),
            ),
          );
        return;
      }
      await NativeApi.instance.startService();
      await onRefresh();
      if (c.mounted)
        ScaffoldMessenger.of(
          c,
        ).showSnackBar(const SnackBar(content: Text('بدأت خدمة القاضي نت.')));
    } catch (e) {
      if (c.mounted)
        ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(_err(e))));
    }
  }
}

Widget _glassStat(String a, String b) => Expanded(
      child: Container(
        margin: const EdgeInsetsDirectional.only(end: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a,
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
            Text(
              b,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
Widget _statCard(
  String title,
  String value,
  String sub,
  IconData icon,
  Color color,
) =>
    Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(title,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
      ),
    );
Widget _checkRow(String text, bool ok) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: ok ? emerald : Colors.grey,
          ),
          const SizedBox(width: 9),
          Text(text),
          const Spacer(),
          Text(
            ok ? 'جاهز' : 'غير مفعل',
            style: TextStyle(color: ok ? emerald : Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
Widget _quick(
  BuildContext c,
  String label,
  IconData icon,
  ValueChanged<int> fn,
  int i,
) =>
    ActionChip(
      avatar: Icon(icon, color: emerald, size: 18),
      label: Text(label),
      onPressed: () => fn(i),
    );

class SalesPage extends StatelessWidget {
  final Map<String, dynamic> data;
  final Future<void> Function() onRefresh;
  const SalesPage({super.key, required this.data, required this.onRefresh});
  @override
  Widget build(BuildContext c) {
    final sales = _sales(data);
    final trigger = _map(data['trigger']);
    final scheduled = _list(trigger['scheduledSales'])
        .where((item) =>
            '${item['status'] ?? ''}' == 'pending' ||
            '${item['status'] ?? ''}' == 'failed' ||
            ('${item['status'] ?? ''}' == 'completed' &&
                item['smsSent'] == false))
        .toList();
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'المبيعات',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          '${sales.length} عملية • إجمالي ${_money(sales.fold<num>(0, (a, s) => a + (num.tryParse('${s['price']}') ?? 0)))}',
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () => showModalBottomSheet(
            context: c,
            isScrollControlled: true,
            builder: (_) => SaleSheet(data: data, onDone: onRefresh),
          ),
          icon: const Icon(Icons.add_shopping_cart),
          label: const Text('تسجيل بيع يدوي'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _showQr(c),
          icon: const Icon(Icons.qr_code),
          label: const Text('عرض رمز QR للمحل'),
        ),
        OutlinedButton.icon(
          onPressed: () => _shareWhatsApp(c),
          icon: const Icon(Icons.chat),
          label: const Text('مشاركة عبر واتساب'),
        ),
        if (scheduled.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('مواعيد البيع والتنبيهات (${scheduled.length})',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          ...scheduled.map((item) => Card(
                child: ListTile(
                  leading: const Icon(Icons.schedule),
                  title: Text(
                      '${item['phone'] ?? ''} • باقة ${item['packageId'] ?? ''}'),
                  subtitle: Text(
                      '${item['status'] == 'failed' ? 'فشل البيع: ${item['failureReason'] ?? ''}' : item['status'] == 'completed' ? 'تم البيع لكن تعذر إرسال SMS.' : '${item['scheduledAt'] ?? ''}\nسيُصرف الكرت عند الموعد وتُرسل رسالة SMS تلقائياً.'}'),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: item['status'] == 'pending'
                        ? 'إلغاء الموعد'
                        : 'عرض حالة التنفيذ',
                    icon: Icon(item['status'] == 'pending'
                        ? Icons.cancel_outlined
                        : Icons.error_outline),
                    onPressed: item['status'] != 'pending'
                        ? null
                        : () async {
                            final confirm = await showDialog<bool>(
                              context: c,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('إلغاء البيع المجدول؟'),
                                content: const Text(
                                    'لن يُخصم كرت أو يُرسل SMS إذا أُلغي قبل بدء التنفيذ.'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, false),
                                      child: const Text('رجوع')),
                                  FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, true),
                                      child: const Text('إلغاء الموعد')),
                                ],
                              ),
                            );
                            if (confirm != true) return;
                            try {
                              await NativeApi.instance
                                  .cancelScheduledSale('${item['id']}');
                              await onRefresh();
                              if (c.mounted)
                                ScaffoldMessenger.of(c).showSnackBar(
                                    const SnackBar(
                                        content: Text('أُلغي موعد البيع.')));
                            } catch (e) {
                              if (c.mounted)
                                ScaffoldMessenger.of(c).showSnackBar(
                                    SnackBar(content: Text(_err(e))));
                            }
                          },
                  ),
                ),
              )),
        ],
        const SizedBox(height: 14),
        if (sales.isEmpty)
          const EmptyCard(text: 'ستظهر المبيعات هنا بعد أول عملية.')
        else
          ...sales.map(
            (s) =>
                SaleTile(sale: s, onTap: () => _saleDetails(c, s, onRefresh)),
          ),
      ],
    );
  }
}

void _saleDetails(BuildContext c, Map<String, dynamic> s,
        [Future<void> Function()? onRefresh]) =>
    showDialog(
      context: c,
      builder: (_) => AlertDialog(
        title: const Text('تفاصيل العملية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('رقم: ${s['phone']}'),
            Text('الباقة: ${s['packageId']}'),
            Text('الكرت: ${s['card']}'),
            Text('الرصيد بعد البيع: ${s['debt']}'),
            Text('الوقت: ${s['time']}'),
            Text('الدفع: ${s['paymentMethod'] == 'cash' ? 'نقداً' : 'آجل'}'),
            if (_whatsappStatusLabel(s['whatsappStatus']).isNotEmpty)
              Text(_whatsappStatusLabel(s['whatsappStatus'])),
            Text('${s['receiptConfirmedAt'] ?? ''}'.trim().isNotEmpty
                ? 'الاستلام: مؤكد يدوياً (${s['receiptConfirmedAt']})'
                : 'الاستلام: لم يؤكد بعد'),
            if ('${s['returnedAt'] ?? ''}'.trim().isNotEmpty)
              Text('أُعيد للمخزون: ${s['returnedAt']}'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('إغلاق')),
          TextButton.icon(
            onPressed: () => _printSale(c, s),
            icon: const Icon(Icons.print_outlined),
            label: const Text('طباعة الوصل'),
          ),
          TextButton.icon(
            onPressed: '${s['transactionId'] ?? ''}'.isEmpty ||
                    '${s['receiptConfirmedAt'] ?? ''}'.isNotEmpty
                ? null
                : () async {
                    try {
                      await NativeApi.instance.markSaleReceived(
                        '${s['transactionId']}',
                      );
                      await onRefresh?.call();
                      if (!c.mounted) return;
                      Navigator.pop(c);
                      ScaffoldMessenger.of(c).showSnackBar(const SnackBar(
                        content: Text('تم تسجيل تأكيد استلام البطاقة.'),
                      ));
                    } catch (e) {
                      if (c.mounted) {
                        ScaffoldMessenger.of(c).showSnackBar(
                          SnackBar(content: Text(_err(e))),
                        );
                      }
                    }
                  },
            icon: const Icon(Icons.mark_email_read_outlined),
            label: const Text('تأكيد استلام البطاقة'),
          ),
          TextButton.icon(
            onPressed: '${s['transactionId'] ?? ''}'.isEmpty ||
                    '${s['returnedAt'] ?? ''}'.isNotEmpty
                ? null
                : () async {
                    final reason = TextEditingController();
                    final confirmed = await showDialog<bool>(
                      context: c,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('إرجاع البطاقة للمخزون؟'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                                'سيُعاد رقم البطاقة نفسه إلى مخزون الباقة، ويُسجّل قيد عكسي للآجل إن وُجد. لا يمكن تكرار الإرجاع.'),
                            const SizedBox(height: 10),
                            TextField(
                                controller: reason,
                                decoration: const InputDecoration(
                                    labelText: 'سبب الإرجاع (اختياري)')),
                          ],
                        ),
                        actions: [
                          TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: const Text('رجوع')),
                          FilledButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              child: const Text('تأكيد الإرجاع')),
                        ],
                      ),
                    );
                    final reasonText = reason.text.trim();
                    reason.dispose();
                    if (confirmed != true) return;
                    try {
                      await NativeApi.instance.returnSale(
                          '${s['transactionId']}',
                          reason: reasonText);
                      await onRefresh?.call();
                      if (!c.mounted) return;
                      Navigator.pop(c);
                      ScaffoldMessenger.of(c).showSnackBar(const SnackBar(
                          content: Text(
                              'تمت إعادة البطاقة للمخزون وتسجيل قيد الإرجاع.')));
                    } catch (e) {
                      if (c.mounted)
                        ScaffoldMessenger.of(c)
                            .showSnackBar(SnackBar(content: Text(_err(e))));
                    }
                  },
            icon: const Icon(Icons.undo_outlined),
            label: const Text('إرجاع البطاقة للمخزون'),
          ),
          TextButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(c);
              Navigator.pop(c);
              final error = await _openWhatsAppSaleCard(
                s,
                phone: '${s['phone'] ?? ''}',
              );
              if (!c.mounted) return;
              messenger.showSnackBar(SnackBar(
                content: Text(error == null
                    ? 'فُتحت محادثة WhatsApp للعميل؛ راجع الكرت واضغط إرسال.'
                    : 'تعذر فتح محادثة WhatsApp: $error'),
              ));
            },
            icon: const Icon(Icons.chat_outlined),
            label: const Text('فتح WhatsApp للعميل'),
          ),
          TextButton.icon(
            onPressed: () async {
              try {
                await NativeApi.instance.openSmsComposer(
                  '${s['phone'] ?? ''}',
                  _manualSmsReceiptMessage(
                    s,
                    clientName: '${s['clientName'] ?? s['name'] ?? ''}',
                    phone: '${s['phone'] ?? ''}',
                  ),
                );
                if (c.mounted) {
                  Navigator.pop(c);
                  ScaffoldMessenger.of(c).showSnackBar(const SnackBar(
                    content:
                        Text('فُتحت رسالة SMS جاهزة؛ راجع النص واضغط إرسال.'),
                  ));
                }
              } catch (e) {
                if (c.mounted)
                  ScaffoldMessenger.of(c)
                      .showSnackBar(SnackBar(content: Text(_err(e))));
              }
            },
            icon: const Icon(Icons.sms_outlined),
            label: const Text('إرسال الكرت'),
          ),
        ],
      ),
    );

String _manualSmsReceiptMessage(
  Map<String, dynamic> sale, {
  String clientName = '',
  String phone = '',
}) {
  final card = '${sale['card'] ?? ''}'.trim();
  final packageId = '${sale['packageId'] ?? sale['price'] ?? ''}';
  final price = sale['price'] ?? packageId;
  final templates =
      _map(_map(NativeApi.instance.snapshot['trigger'])['templates']);
  final template = '${templates['success'] ?? ''}'.trim();
  final source = template.isEmpty
      ? 'أهلاً {name}،\nكرتك: {card} | الباقة: {package} | السعر: {price} ر.ي\nالمتبقي عليك: {debt} ر.ي — القاضي نت'
      : template;
  return source
      .replaceAll(
          '{name}', clientName.trim().isEmpty ? 'عميلنا' : clientName.trim())
      .replaceAll('{card}', card)
      .replaceAll('{package}', packageId)
      .replaceAll('{price}', '$price')
      .replaceAll('{debt}', '${sale['debt'] ?? 0}')
      .replaceAll('{phone}', phone.trim())
      .replaceAll('{reason}', '');
}

Future<String?> _openWhatsAppSaleCard(
  Map<String, dynamic> sale, {
  String clientName = '',
  String phone = '',
  Future<bool> Function(Uri uri)? launchExternalUri,
}) async {
  final card = '${sale['card'] ?? ''}'.trim();
  if (card.isEmpty) return 'لا يوجد رقم كرت في سجل البيع.';
  final number = normalizeWhatsAppNumber(
    phone.isEmpty ? '${sale['phone'] ?? ''}' : phone,
  );
  if (number == null) {
    return 'الرقم غير صالح. أدخل رقم جوال يمني محلياً أو أضف رمز الدولة مثل +967.';
  }
  final packageId = '${sale['packageId'] ?? sale['price'] ?? ''}';
  final price = sale['price'] ?? packageId;
  final greeting = clientName.trim().isEmpty
      ? <String>[]
      : <String>['أهلاً ${clientName.trim()}،'];
  final templates =
      _map(_map(NativeApi.instance.snapshot['trigger'])['templates']);
  final receiptTemplate = '${templates['whatsappReceipt'] ?? ''}'.trim();
  final message = receiptTemplate.isEmpty
      ? [
          ...greeting,
          'كرتك: $card',
          'الباقة: $packageId — $price ر.ي',
          'شبكة القاضي نت',
        ].join('\n')
      : receiptTemplate
          .replaceAll('{name}',
              clientName.trim().isEmpty ? 'عميلنا' : clientName.trim())
          .replaceAll('{card}', card)
          .replaceAll('{package}', packageId)
          .replaceAll('{price}', '$price')
          .replaceAll('{debt}', '${sale['debt'] ?? ''}')
          .replaceAll('{phone}', number)
          .replaceAll('{reason}', '');
  final webUri = whatsappChatUri(
    phone.isEmpty ? '${sale['phone'] ?? ''}' : phone,
    message: message,
  );
  if (webUri == null) {
    return 'الرقم غير صالح. أدخل رقم جوال يمني محلياً أو أضف رمز الدولة مثل +967.';
  }
  final launch = launchExternalUri ??
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
  try {
    if (await launch(webUri)) return null;
  } catch (error) {
    return _err(error);
  }
  return 'لم يتم فتح التطبيق أو الرابط. تحقق من تثبيت WhatsApp وصحة الرقم.';
}

Future<void> _shareWhatsApp(BuildContext c) async {
  final uri = Uri.https('wa.me', '/',
      {'text': 'مرحباً، أريد الاستفسار عن كروت الإنترنت من القاضي نت.'});
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
      c.mounted) {
    ScaffoldMessenger.of(c).showSnackBar(
        const SnackBar(content: Text('تعذر فتح واتساب على هذا الجهاز.')));
  }
}

Future<void> _printSale(BuildContext c, Map<String, dynamic> sale) async {
  try {
    await Printing.layoutPdf(
        name: 'qadinet-receipt.pdf',
        onLayout: (format) async {
          final doc = pw.Document();
          doc.addPage(pw.Page(
              pageFormat: format,
              build: (_) => pw.Center(
                      child: pw.Column(
                          mainAxisSize: pw.MainAxisSize.min,
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                        pw.Text('QADI NET',
                            style: pw.TextStyle(
                                fontSize: 22, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 14),
                        pw.Text('Internet Card Receipt'),
                        pw.Divider(),
                        pw.Text('Phone: ${sale['phone']}'),
                        pw.Text('Package: ${sale['packageId']}'),
                        pw.Text('Card: ${sale['card']}'),
                        pw.Text('Balance: ${sale['debt']} YER'),
                        pw.Text(
                            'Payment: ${sale['paymentMethod'] ?? 'credit'}'),
                        pw.Text('Time: ${sale['time']}'),
                      ]))));
          return doc.save();
        });
  } catch (e) {
    if (c.mounted)
      ScaffoldMessenger.of(c)
          .showSnackBar(SnackBar(content: Text('تعذرت الطباعة: ${_err(e)}')));
  }
}

Future<void> _printerSettings(BuildContext c) async {
  try {
    final printers = await Printing.listPrinters();
    if (!c.mounted) return;
    showDialog<void>(
        context: c,
        builder: (_) => AlertDialog(
                title: const Text('الطابعة'),
                content: printers.isEmpty
                    ? const Text(
                        'لم يُكتشف جهاز طباعة. اربط طابعة تدعم خدمة الطباعة في Android.')
                    : SizedBox(width: 360, child: ListView(shrinkWrap: true, children: printers.map((p) => ListTile(leading: const Icon(Icons.print), title: Text(p.name), subtitle: Text(p.url))).toList())),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('إغلاق'))
                ]));
  } catch (e) {
    if (c.mounted)
      ScaffoldMessenger.of(c).showSnackBar(
          SnackBar(content: Text('تعذر فحص الطابعات: ${_err(e)}')));
  }
}

void _showQr(BuildContext c) => showDialog(
      context: c,
      builder: (_) => AlertDialog(
        title: const Text('QR القاضي نت'),
        content: SizedBox(
          width: 220,
          height: 220,
          child: PrettyQrView.data(
            data: 'القاضي نت - طلب بطاقات الإنترنت',
            decoration: const PrettyQrDecoration(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('إغلاق')),
        ],
      ),
    );

class SaleSheet extends StatefulWidget {
  final Map<String, dynamic> data;
  final Future<void> Function() onDone;
  final String? initialPhone;
  final String? initialName;
  final Future<bool> Function(Uri uri)? launchExternalUri;
  const SaleSheet(
      {super.key,
      required this.data,
      required this.onDone,
      this.initialPhone,
      this.initialName,
      this.launchExternalUri});
  @override
  State<SaleSheet> createState() => _SaleSheetState();
}

class _SaleSheetState extends State<SaleSheet> {
  final phone = TextEditingController(), name = TextEditingController();
  String? selected;
  String paymentMethod = 'cash';
  String deliveryChannel = 'none';
  bool scheduleEnabled = false;
  DateTime scheduledAt = DateTime.now().add(const Duration(hours: 1));
  bool busy = false;
  @override
  void initState() {
    super.initState();
    phone.text = widget.initialPhone ?? '';
    name.text = widget.initialName ?? '';
    final ps = _packages(widget.data);
    selected = ps.isNotEmpty ? '${ps.first['id']}' : '500';
  }

  @override
  Widget build(BuildContext c) {
    final ps = _packages(widget.data);
    final selectedPackage =
        ps.where((p) => '${p['id']}' == (selected ?? '')).firstOrNull ??
            (ps.isEmpty ? <String, dynamic>{} : ps.first);
    final actualPrice = SelectedFeatures.effectivePrice(
      permissions: _map(widget.data['permissions']),
      phone: phone.text,
      packageId: '${selectedPackage['id'] ?? selected ?? ''}',
      basePrice: int.tryParse('${selectedPackage['price'] ?? 0}') ?? 0,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(c).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('بيع كرت يدوياً', style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: 'اسم العميل (اختياري)',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'رقم الهاتف',
                suffixIcon: IconButton(
                  tooltip: 'جهات الاتصال',
                  icon: const Icon(Icons.contacts),
                  onPressed: () async {
                    try {
                      final contact = await NativeApi.instance.pickContact();
                      if (contact != null)
                        setState(() {
                          phone.text = contact.phone;
                          if (contact.name.isNotEmpty) name.text = contact.name;
                        });
                    } catch (e) {
                      if (c.mounted)
                        ScaffoldMessenger.of(c)
                            .showSnackBar(SnackBar(content: Text(_err(e))));
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: selected,
              decoration: const InputDecoration(labelText: 'الباقة'),
              items: ps
                  .map(
                    (p) => DropdownMenuItem(
                      value: '${p['id']}',
                      child: Text(
                        '${p['label'] ?? p['id']} — ${p['price']} ر.ي (${_list(_inventory(widget.data)['${p['id']}']).length} متبقي)',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => selected = v),
            ),
            if (selectedPackage.isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 6, bottom: 10),
                child: Text(
                  'السعر المعتمد لهذا العميل: $actualPrice ر.ي',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            DropdownButtonFormField<String>(
              initialValue: paymentMethod,
              decoration: const InputDecoration(labelText: 'طريقة الدفع'),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('نقداً')),
                DropdownMenuItem(
                    value: 'credit', child: Text('آجل / على الحساب')),
              ],
              onChanged: (v) => setState(() => paymentMethod = v ?? 'cash'),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: scheduleEnabled,
              onChanged: (value) => setState(() => scheduleEnabled = value),
              title: const Text('جدولة البيع والتسليم'),
              subtitle: const Text(
                  'صرف الكرت وإرسال SMS تلقائياً عند الموعد المحدد.'),
            ),
            if (scheduleEnabled)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.event_available),
                  title: const Text('موعد التنفيذ'),
                  subtitle: Text(_scheduledDateLabel(scheduledAt)),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: () => _chooseScheduledTime(c),
                ),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: deliveryChannel,
                decoration: const InputDecoration(
                    labelText: 'طريقة إرسال الكرت بعد البيع'),
                items: const [
                  DropdownMenuItem(
                      value: 'none', child: Text('بدون إرسال الآن')),
                  DropdownMenuItem(
                      value: 'sms',
                      child: Text('فتح SMS برسالة جاهزة (تأكيد يدوي)')),
                  DropdownMenuItem(
                      value: 'whatsapp',
                      child: Text('فتح محادثة WhatsApp للرقم')),
                ],
                onChanged: (value) =>
                    setState(() => deliveryChannel = value ?? 'none'),
              ),
            FilledButton(
              onPressed: busy ? null : () => submit(c),
              child: busy
                  ? const CircularProgressIndicator()
                  : const Text('إتمام البيع'),
            ),
          ],
        ),
      ),
    );
  }

  String _scheduledDateLabel(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} • ${TimeOfDay.fromDateTime(value).format(context)}';

  Future<void> _chooseScheduledTime(BuildContext c) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: c,
      initialDate: scheduledAt.isBefore(now) ? now : scheduledAt,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, now.month, now.day),
      helpText: 'اختر تاريخ تنفيذ البيع',
    );
    if (date == null || !c.mounted) return;
    final time = await showTimePicker(
      context: c,
      initialTime: TimeOfDay.fromDateTime(scheduledAt),
      helpText: 'اختر وقت تنفيذ البيع',
    );
    if (time == null || !c.mounted) return;
    final candidate =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (candidate.isBefore(DateTime.now().add(const Duration(seconds: 30)))) {
      ScaffoldMessenger.of(c).showSnackBar(const SnackBar(
          content: Text('اختر موعداً مستقبلياً بعد 30 ثانية على الأقل.')));
      return;
    }
    setState(() => scheduledAt = candidate);
  }

  Future<void> submit(BuildContext c) async {
    if (phone.text.trim().isEmpty) {
      ScaffoldMessenger.of(c)
          .showSnackBar(const SnackBar(content: Text('أدخل رقم العميل.')));
      return;
    }
    if (deliveryChannel == 'whatsapp' &&
        normalizeWhatsAppNumber(phone.text) == null) {
      ScaffoldMessenger.of(c).showSnackBar(const SnackBar(
        content: Text(
          'أدخل رقم جوال يمني محلياً أو أضف رمز الدولة مثل +967 قبل البيع.',
        ),
      ));
      return;
    }
    if (scheduleEnabled &&
        scheduledAt.isBefore(DateTime.now().add(const Duration(seconds: 30)))) {
      ScaffoldMessenger.of(c).showSnackBar(const SnackBar(
          content: Text('اختر موعداً مستقبلياً بعد 30 ثانية على الأقل.')));
      return;
    }
    final packageId = selected ?? '500';
    final package = _packages(widget.data)
            .where((item) => '${item['id']}' == packageId)
            .firstOrNull ??
        <String, dynamic>{};
    final scheduledPrice = SelectedFeatures.effectivePrice(
      permissions: _map(widget.data['permissions']),
      phone: phone.text.trim(),
      packageId: packageId,
      basePrice: int.tryParse('${package['price'] ?? 0}') ?? 0,
    );
    setState(() => busy = true);
    try {
      if (scheduleEnabled) {
        await NativeApi.instance.scheduleSale(
          packageId,
          phone.text.trim(),
          name: name.text.trim(),
          price: scheduledPrice,
          paymentMethod: paymentMethod,
          scheduledAt: scheduledAt,
        );
        await widget.onDone();
        if (c.mounted) {
          final messenger = ScaffoldMessenger.of(c);
          Navigator.pop(c);
          messenger.showSnackBar(SnackBar(
            content: Text(
                'تمت جدولة البيع لـ ${_scheduledDateLabel(scheduledAt)}. سيتم صرف الكرت وإرسال SMS تلقائياً.'),
          ));
        }
        return;
      }
      final result = await NativeApi.instance.sell(
        selected ?? '500',
        phone.text.trim(),
        name: name.text.trim(),
        sendSms: false,
        paymentMethod: paymentMethod,
      );
      if (result['ok'] == false) {
        if (c.mounted) {
          ScaffoldMessenger.of(c).showSnackBar(
            SnackBar(content: Text('${result['message'] ?? 'تعذر البيع'}')),
          );
        }
        return;
      }
      await widget.onDone();
      String? shareError;
      String? smsComposerError;
      if (deliveryChannel == 'whatsapp') {
        shareError = await _openWhatsAppSaleCard(
          result,
          clientName: name.text.trim(),
          phone: phone.text.trim(),
          launchExternalUri: widget.launchExternalUri,
        );
      } else if (deliveryChannel == 'sms') {
        try {
          await NativeApi.instance.openSmsComposer(
            phone.text.trim(),
            _manualSmsReceiptMessage(
              result,
              clientName: name.text.trim(),
              phone: phone.text.trim(),
            ),
          );
        } catch (error) {
          smsComposerError = _err(error);
        }
      }
      if (c.mounted) {
        Navigator.pop(c);
        final message = '${result['message'] ?? 'تم البيع'}';
        final deliveryStatus = deliveryChannel == 'whatsapp'
            ? shareError == null
                ? ' • فُتحت محادثة WhatsApp للرقم؛ راجع الرسالة واضغط إرسال. لا تعِد البيع.'
                : ' • تم تسجيل البيع لكن تعذر فتح WhatsApp ($shareError). افتح المحادثة من تفاصيل البيع ولا تعِد البيع.'
            : deliveryChannel == 'sms'
                ? smsComposerError == null
                    ? ' • فُتحت رسالة SMS جاهزة؛ راجع النص واضغط إرسال. لا تعِد البيع.'
                    : ' • تم تسجيل البيع لكن تعذر فتح تطبيق SMS ($smsComposerError). افتح تفاصيل البيع وحاول فتح الرسالة مجدداً؛ لا تعِد البيع.'
                : '';
        ScaffoldMessenger.of(c).showSnackBar(
          SnackBar(content: Text('$message$deliveryStatus')),
        );
      }
    } catch (e) {
      if (c.mounted)
        ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(_err(e))));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    phone.dispose();
    name.dispose();
    super.dispose();
  }
}

class InventoryPage extends StatefulWidget {
  final Map<String, dynamic> data;
  final Future<void> Function() onRefresh;
  const InventoryPage({super.key, required this.data, required this.onRefresh});
  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  String filter = '';
  final Map<String, Set<String>> selected = {};
  final Set<String> revealedCards = {};

  String _revealKey(String packageId, String card) => '$packageId\u0000$card';

  String _maskedCard(String card) =>
      card.length > 4 ? '****${card.substring(card.length - 4)}' : '••••';

  int get selectedCount =>
      selected.values.fold(0, (sum, cards) => sum + cards.length);

  List<String> _matchingCards(Map<String, dynamic> inventory, String id) =>
      _list(inventory[id])
          .map((value) => '$value')
          .where((card) => card.toLowerCase().contains(filter.toLowerCase()))
          .take(5000)
          .toList();

  void _toggle(String id, String card, bool checked) {
    if (checked &&
        !(selected[id]?.contains(card) ?? false) &&
        selectedCount >= 5000) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('يمكن معالجة 5000 بطاقة كحد أقصى في العملية الواحدة.')));
      return;
    }
    setState(() {
      final values = selected.putIfAbsent(id, () => <String>{});
      if (checked) {
        values.add(card);
      } else {
        values.remove(card);
      }
      selected.removeWhere((_, values) => values.isEmpty);
    });
  }

  void _selectVisible(String id, List<String> cards, bool checked) {
    final currentCount = selected[id]?.length ?? 0;
    final capacity = 5000 - (selectedCount - currentCount);
    if (checked && cards.length - currentCount > capacity) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('يمكن معالجة 5000 بطاقة كحد أقصى في العملية الواحدة.')));
    }
    setState(() {
      if (checked) {
        selected.putIfAbsent(id, () => <String>{}).addAll(
              cards
                  .where((card) => !(selected[id]?.contains(card) ?? false))
                  .take(capacity),
            );
      } else {
        selected[id]?.removeAll(cards);
        selected.removeWhere((_, values) => values.isEmpty);
      }
    });
  }

  @override
  Widget build(BuildContext c) {
    final inv = _inventory(widget.data);
    final ids = _packages(widget.data);
    final totalMatches = ids.fold<int>(
      0,
      (sum, package) => sum + _matchingCards(inv, '${package['id']}').length,
    );
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'المخزون',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ids
              .map(
                (p) => Chip(
                  label: Text('${p['id']}: ${_list(inv['${p['id']}']).length}'),
                ),
              )
              .toList(),
        ),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'ابحث في أرقام الكروت',
          ),
          onChanged: (v) => setState(() {
            filter = v;
            selected.clear();
            revealedCards.clear();
          }),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 9,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => importPdf(c),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('استيراد PDF'),
            ),
            OutlinedButton.icon(
              onPressed: () => pasteCards(c),
              icon: const Icon(Icons.add),
              label: const Text('إضافة بطاقات نصية'),
            ),
          ],
        ),
        if (selectedCount > 0) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('تم تحديد $selectedCount بطاقة',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    OutlinedButton.icon(
                      onPressed: _shareSelected,
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('تصدير المحدد'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _printSelected,
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('طباعة'),
                    ),
                    OutlinedButton.icon(
                      onPressed: selectedCount == 1 ? _editSelected : null,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('تعديل بطاقة'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _moveSelected,
                      icon: const Icon(Icons.drive_file_move_outline),
                      label: const Text('نقل إلى باقة'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _deleteSelected,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('حذف المحدد'),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(selected.clear),
                      icon: const Icon(Icons.deselect),
                      label: const Text('إلغاء التحديد'),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  const Text(
                    'الإجراءات تخص البطاقات المتاحة في المخزون فقط؛ سجل المبيعات لا يتغير.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (totalMatches > 0)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => setState(() {
                selected.clear();
                var remaining = 5000;
                for (final package in ids) {
                  if (remaining == 0) break;
                  final id = '${package['id']}';
                  final cards =
                      _matchingCards(inv, id).take(remaining).toList();
                  if (cards.isNotEmpty) {
                    selected[id] = cards.toSet();
                    remaining -= cards.length;
                  }
                }
              }),
              icon: const Icon(Icons.select_all),
              label: Text('تحديد نتائج البحث حتى 5000 بطاقة ($totalMatches)'),
            ),
          ),
        if (ids.isEmpty)
          const EmptyCard(
              text: 'لا توجد باقات لعرض مخزونها. أضف باقة من الإعدادات أولاً.')
        else if (totalMatches == 0)
          EmptyCard(
            text: filter.isEmpty
                ? 'المخزون فارغ. أضف بطاقات نصية أو استورد ملف PDF.'
                : 'لا توجد بطاقات تطابق «$filter».',
          ),
        const SizedBox(height: 12),
        ...ids.map((p) {
          final id = '${p['id']}';
          final allMatches = _matchingCards(inv, id);
          final cards = allMatches.take(100).toList();
          final chosen = selected[id] ?? const <String>{};
          final allSelected =
              allMatches.isNotEmpty && allMatches.every(chosen.contains);
          return ExpansionTile(
            title: Text('باقة $id — ${_list(inv[id]).length} بطاقة'),
            subtitle: Text(filter.isEmpty
                ? 'عرض ${cards.length} من ${allMatches.length} بطاقة'
                : 'عرض ${cards.length} من ${allMatches.length} نتيجة بحث'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Checkbox(
                value: allSelected,
                tristate: chosen.isNotEmpty && !allSelected,
                onChanged: (value) =>
                    _selectVisible(id, allMatches, value == true),
              ),
              const Icon(Icons.expand_more),
            ]),
            children: cards.map(
              (card) {
                final key = _revealKey(id, card);
                final isRevealed = revealedCards.contains(key);
                return CheckboxListTile(
                  dense: true,
                  value: chosen.contains(card),
                  title: Row(children: [
                    const Icon(Icons.credit_card, color: emerald, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isRevealed ? card : _maskedCard(card),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                  ]),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (value) => _toggle(id, card, value == true),
                  secondary: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: 'نسخ الرقم الكامل',
                      icon: const Icon(Icons.copy),
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: card)),
                    ),
                    IconButton(
                      tooltip: isRevealed ? 'إخفاء البطاقة' : 'إظهار البطاقة',
                      icon: Icon(isRevealed
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () => setState(() {
                        if (isRevealed) {
                          revealedCards.remove(key);
                        } else {
                          revealedCards.add(key);
                        }
                      }),
                    ),
                  ]),
                );
              },
            ).toList(),
          );
        }),
      ],
    );
  }

  List<Map<String, dynamic>> _selectedChanges(String action) => [
        for (final entry in selected.entries)
          for (final card in entry.value)
            {'action': action, 'packageId': entry.key, 'card': card},
      ];

  Future<void> _applyChanges(
    BuildContext c,
    List<Map<String, dynamic>> changes,
    String successMessage,
  ) async {
    try {
      await NativeApi.instance.updateInventory(changes);
      await widget.onRefresh();
      if (!mounted || !c.mounted) return;
      setState(selected.clear);
      ScaffoldMessenger.of(c).showSnackBar(SnackBar(
        content: Text(successMessage),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'تراجع',
          onPressed: () async {
            try {
              await NativeApi.instance.undoInventoryChange();
              await widget.onRefresh();
              if (mounted) setState(selected.clear);
            } catch (e) {
              if (c.mounted) {
                ScaffoldMessenger.of(c).showSnackBar(
                    SnackBar(content: Text('تعذر التراجع: ${_err(e)}')));
              }
            }
          },
        ),
      ));
    } catch (e) {
      if (c.mounted) {
        ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(_err(e))));
      }
    }
  }

  Future<void> _deleteSelected() async {
    final c = context;
    final count = selectedCount;
    final approved = await showDialog<bool>(
          context: c,
          builder: (dialogContext) => AlertDialog(
            title: const Text('حذف البطاقات المحددة؟'),
            content: Text(
                'سيُحذف $count بطاقة متاحة من المخزون فقط. لا تتأثر سجلات المبيعات، ويمكن التراجع خلال خمس ثوانٍ.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('إلغاء')),
              FilledButton.tonal(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('حذف المحدد')),
            ],
          ),
        ) ??
        false;
    if (!approved || !mounted) return;
    await _applyChanges(c, _selectedChanges('delete'), 'تم حذف $count بطاقة.');
  }

  Future<void> _editSelected() async {
    final entry = selected.entries.first;
    final oldCard = entry.value.first;
    final controller = TextEditingController(text: oldCard);
    final replacement = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تعديل رقم البطاقة'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'رقم البطاقة الجديد'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('حفظ')),
        ],
      ),
    );
    controller.dispose();
    if (replacement == null || replacement.trim() == oldCard || !mounted)
      return;
    await _applyChanges(
        context,
        [
          {
            'action': 'edit',
            'packageId': entry.key,
            'card': oldCard,
            'newCard': replacement.trim(),
          }
        ],
        'تم تعديل رقم البطاقة.');
  }

  Future<void> _moveSelected() async {
    final ids = _packages(widget.data);
    final target = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('نقل المحدد إلى باقة'),
        children: ids.map((package) {
          final id = '${package['id']}';
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, id),
            child: Text('${package['label'] ?? id} (${package['price']} ر.ي)'),
          );
        }).toList(),
      ),
    );
    if (target == null || !mounted) return;
    final changes = [
      for (final entry in selected.entries)
        if (entry.key != target)
          for (final card in entry.value)
            {
              'action': 'move',
              'packageId': entry.key,
              'targetPackageId': target,
              'card': card,
            },
    ];
    if (changes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('البطاقات المحددة موجودة في هذه الباقة.')));
      return;
    }
    await _applyChanges(context, changes, 'تم نقل ${changes.length} بطاقة.');
  }

  Future<void> _shareSelected() async {
    final lines = [
      for (final entry in selected.entries)
        for (final card in entry.value) 'باقة ${entry.key}: $card',
    ];
    await Share.share(lines.join('\n'), subject: 'بطاقات مخزون القاضي نت');
  }

  Future<void> _printSelected() async {
    final lines = [
      for (final entry in selected.entries)
        for (final card in entry.value) 'Package ${entry.key}: $card',
    ];
    try {
      await Printing.layoutPdf(
        name: 'qadinet-selected-inventory.pdf',
        onLayout: (format) async {
          final document = pw.Document();
          document.addPage(pw.MultiPage(
            pageFormat: format,
            build: (_) => [
              pw.Text('Al-Qaidi Net — Selected Inventory'),
              pw.SizedBox(height: 12),
              ...lines.map((line) => pw.Text(line)),
            ],
          ));
          return document.save();
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذرت الطباعة: ${_err(e)}')));
      }
    }
  }

  Future<void> importPdf(BuildContext c) async {
    try {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: false,
      );
      if (r == null) return;
      final selected = r.files.single;
      if (selected.size > 50 * 1024 * 1024) {
        throw Exception('حجم الملف يتجاوز الحد المسموح (50 ميغابايت).');
      }
      final bytes = selected.bytes ?? await File(selected.path!).readAsBytes();
      if (!c.mounted) return;
      showDialog<void>(
        context: c,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Row(children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('جارٍ تحليل PDF في الخلفية…'))
          ]),
        ),
      );
      List<String> cards;
      try {
        cards = await compute(_extractPdfCards, bytes);
      } finally {
        if (c.mounted) Navigator.of(c, rootNavigator: true).pop();
      }
      if (cards.isEmpty)
        throw Exception(
            'لم أعثر على أرقام بطاقات نصية واضحة. ملفات PDF المصوّرة تحتاج OCR.');
      final id = await _choosePackage(c);
      if (id == null) return;
      final existing =
          _list(_inventory(widget.data)[id]).map((v) => '$v').toSet();
      final uniqueCards =
          cards.where((card) => !existing.contains(card)).toList();
      if (uniqueCards.isEmpty)
        throw Exception('كل البطاقات المستخرجة موجودة مسبقاً في هذه الباقة.');
      final added = await _confirmCards(c, uniqueCards);
      if (!added) return;
      await NativeApi.instance.addCards(id, uniqueCards);
      await widget.onRefresh();
      if (c.mounted)
        ScaffoldMessenger.of(c).showSnackBar(
          SnackBar(
            content: Text(
                'تم استيراد ${uniqueCards.length} بطاقة جديدة إلى باقة $id.'),
          ),
        );
    } catch (e) {
      if (c.mounted)
        ScaffoldMessenger.of(
          c,
        ).showSnackBar(SnackBar(content: Text('تعذر استيراد PDF: ${_err(e)}')));
    }
  }

  Future<void> pasteCards(BuildContext c) async {
    final ctl = TextEditingController();
    final text = await showDialog<String>(
      context: c,
      builder: (_) => AlertDialog(
        title: const Text('إضافة بطاقات'),
        content: TextField(
          controller: ctl,
          minLines: 5,
          maxLines: 10,
          decoration: const InputDecoration(hintText: 'بطاقة واحدة في كل سطر'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, ctl.text),
            child: const Text('التالي'),
          ),
        ],
      ),
    );
    if (text == null) return;
    final cards = text
        .split(RegExp(r'[\s,;]+'))
        .where((e) => e.trim().isNotEmpty)
        .toSet()
        .toList();
    final id = await _choosePackage(c);
    if (id == null || cards.isEmpty) return;
    try {
      await NativeApi.instance.addCards(id, cards);
      await widget.onRefresh();
    } catch (e) {
      if (c.mounted)
        ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(_err(e))));
    }
  }

  Future<String?> _choosePackage(BuildContext c) => showDialog<String>(
        context: c,
        builder: (_) => SimpleDialog(
          title: const Text('اختر الباقة'),
          children: _packages(widget.data)
              .map(
                (p) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(c, '${p['id']}'),
                  child: Text('${p['label'] ?? p['id']} (${p['price']} ر.ي)'),
                ),
              )
              .toList(),
        ),
      );
  Future<bool> _confirmCards(BuildContext c, List<String> cards) =>
      showDialog<bool>(
        context: c,
        builder: (_) => AlertDialog(
          title: Text('تم العثور على ${cards.length} بطاقة'),
          content: SizedBox(
            height: 180,
            child: ListView(
              children: cards.take(12).map((v) => Text(v)).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('استيراد'),
            ),
          ],
        ),
      ).then((v) => v ?? false);
}

class ClientsPage extends StatefulWidget {
  final Map<String, dynamic> data;
  final Future<void> Function() onRefresh;
  const ClientsPage({super.key, required this.data, required this.onRefresh});
  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  String q = '';
  bool showingArchived = false;
  @override
  Widget build(BuildContext c) {
    final debts = _debts(widget.data);
    final sales = _sales(widget.data);
    final trustedData = _map(widget.data['trusted']);
    final archived = _list(trustedData['archivedClients']).map(_map).toList();
    final archivedKeys = archived
        .map((entry) => _phoneKey('${entry['phone'] ?? ''}'))
        .where((key) => key.isNotEmpty)
        .toSet();
    final phones = <String>{
      ...debts.map((d) => '${d['phone']}'),
      ...sales.map((s) => '${s['phone']}'),
      ..._list(widget.data['transactions'])
          .map((t) => '${_map(t)['phone'] ?? ''}'),
      ..._list(_map(widget.data['permissions'])['clients'])
          .map((t) => '${_map(t)['phone'] ?? ''}'),
      ..._list(_map(widget.data['trusted'])['clients'])
          .map((t) => '${_map(t)['phone'] ?? ''}'),
      ...archived.map((t) => '${t['phone'] ?? ''}'),
    }.toList()
      ..sort();
    final filtered = phones.where((p) {
      final isArchived = archivedKeys.contains(_phoneKey(p));
      return p.isNotEmpty && p.contains(q) && isArchived == showingArchived;
    }).toList();
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'العملاء',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'بحث برقم الهاتف',
            suffixIcon: IconButton(
              tooltip: 'اختيار جهة اتصال',
              icon: const Icon(Icons.contacts),
              onPressed: () async {
                try {
                  final contact = await NativeApi.instance.pickContact();
                  if (contact != null) setState(() => q = contact.phone);
                } catch (e) {
                  if (c.mounted)
                    ScaffoldMessenger.of(c)
                        .showSnackBar(SnackBar(content: Text(_err(e))));
                }
              },
            ),
          ),
          onChanged: (v) => setState(() => q = v),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _editClient(c, null, widget.data, widget.onRefresh),
          icon: const Icon(Icons.person_add),
          label: const Text('إضافة عميل / صلاحيات'),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            try {
              final contact = await NativeApi.instance.pickContact();
              if (contact != null && c.mounted) {
                await _editClient(
                    c, contact.phone, widget.data, widget.onRefresh,
                    initialName: contact.name);
              }
            } catch (e) {
              if (c.mounted) {
                ScaffoldMessenger.of(c)
                    .showSnackBar(SnackBar(content: Text(_err(e))));
              }
            }
          },
          icon: const Icon(Icons.contacts),
          label: const Text('اختيار عميل من جهات الاتصال'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => _addManualDebt(c, widget.data, widget.onRefresh),
          icon: const Icon(Icons.edit_note),
          label: const Text('إضافة / تعديل دين يدوي'),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: Text(
                  'النشط (${phones.where((p) => !archivedKeys.contains(_phoneKey(p))).length})'),
              selected: !showingArchived,
              onSelected: (_) => setState(() => showingArchived = false),
            ),
            ChoiceChip(
              label: Text('الأرشيف (${archivedKeys.length})'),
              selected: showingArchived,
              onSelected: (_) => setState(() => showingArchived = true),
            ),
          ],
        ),
        if (filtered.isEmpty)
          const EmptyCard(
            text: 'لا توجد سجلات في هذا العرض.',
          )
        else
          ...filtered.map((p) {
            final d = debts.where((x) => '${x['phone']}' == p).firstOrNull;
            final count = sales.where((x) => '${x['phone']}' == p).length;
            final isArchived = archivedKeys.contains(_phoneKey(p));
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: emerald.withValues(alpha: .12),
                  child: const Icon(Icons.person, color: emerald),
                ),
                title: Text(_clientDisplayName(p, widget.data)),
                subtitle: Text(
                  '$count عملية • الرصيد ${_money(d?['amount'] ?? 0)}${isArchived ? ' • مؤرشف' : ''}',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'access') {
                      _editClient(c, p, widget.data, widget.onRefresh);
                    } else if (v == 'debt') {
                      final clientName = _clientDisplayName(p, widget.data);
                      await _addManualDebt(
                        c,
                        widget.data,
                        widget.onRefresh,
                        initialPhone: p,
                        initialName: clientName == p ? '' : clientName,
                      );
                    } else if (v == 'archive') {
                      await _archiveClient(c, p);
                    } else if (v == 'restore') {
                      await _restoreClient(c, p);
                    } else if (v == 'history') {
                      showDialog(
                        context: c,
                        builder: (_) => AlertDialog(
                          title: Text('سجل $p'),
                          content: SizedBox(
                            width: 400,
                            child: ListView(
                              shrinkWrap: true,
                              children: sales
                                  .where((x) => '${x['phone']}' == p)
                                  .map(
                                    (s) => ListTile(
                                      title: Text('باقة ${s['packageId']}'),
                                      subtitle: Text(
                                        '${s['time']} • ${s['card']}',
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c),
                              child: const Text('إغلاق'),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  itemBuilder: (_) => [
                    if (isArchived)
                      const PopupMenuItem(
                          value: 'restore', child: Text('استعادة العميل'))
                    else ...[
                      const PopupMenuItem(
                          value: 'access', child: Text('تعديل')),
                      const PopupMenuItem(
                          value: 'debt', child: Text('إضافة / تعديل دين يدوي')),
                      const PopupMenuItem(
                          value: 'history', child: Text('سجل المبيعات')),
                      const PopupMenuItem(value: 'archive', child: Text('حذف')),
                    ],
                    if (isArchived)
                      const PopupMenuItem(
                        value: 'debt_archived',
                        enabled: false,
                        child: Text('الدين اليدوي يتطلب استعادة العميل'),
                      ),
                    if (isArchived)
                      const PopupMenuItem(
                          value: 'history', child: Text('سجل المبيعات')),
                  ],
                ),
                onTap: () => _openAccount(c, p),
              ),
            );
          }),
      ],
    );
  }

  Future<void> _archiveClient(BuildContext c, String phone) async {
    final name = _clientDisplayName(phone, widget.data);
    final confirmed = await showDialog<bool>(
      context: c,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف العميل من القائمة؟'),
        content: const Text(
            'سيُزال العميل من القوائم النشطة والصلاحيات والموثقين، وينتقل إلى الأرشيف. لن تُحذف المبيعات أو الدفعات أو كشف الحساب؛ ويمكن استعادته من تبويب الأرشيف.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء')),
          FilledButton.tonal(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('حذف إلى الأرشيف')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final permissions =
          jsonDecode(jsonEncode(_map(widget.data['permissions'])))
              as Map<String, dynamic>;
      final trusted = jsonDecode(jsonEncode(_map(widget.data['trusted'])))
          as Map<String, dynamic>;
      final permissionClients =
          _list(permissions['clients']).map(_map).toList();
      final savedPermission = permissionClients
          .where((entry) =>
              _phoneKey('${entry['phone'] ?? ''}') == _phoneKey(phone))
          .firstOrNull;
      permissionClients.removeWhere(
          (entry) => _phoneKey('${entry['phone'] ?? ''}') == _phoneKey(phone));
      final trustedClients = _list(trusted['clients'])
          .map((entry) =>
              entry is Map ? _map(entry) : <String, dynamic>{'phone': '$entry'})
          .toList();
      final savedTrusted = trustedClients
          .where((entry) =>
              _phoneKey('${entry['phone'] ?? ''}') == _phoneKey(phone))
          .firstOrNull;
      trustedClients.removeWhere(
          (entry) => _phoneKey('${entry['phone'] ?? ''}') == _phoneKey(phone));
      final archive = _list(trusted['archivedClients']).map(_map).toList();
      archive.removeWhere(
          (entry) => _phoneKey('${entry['phone'] ?? ''}') == _phoneKey(phone));
      archive.add({
        'phone': phone,
        'name': name,
        'permissions': savedPermission,
        'trusted': savedTrusted,
        'archivedAt': DateTime.now().toIso8601String(),
      });
      permissions['clients'] = permissionClients;
      trusted['clients'] = trustedClients;
      trusted['archivedClients'] = archive;
      await NativeApi.instance.saveClientAndTrusted(permissions, trusted);
      await widget.onRefresh();
      if (mounted) setState(() => showingArchived = true);
      if (c.mounted) {
        ScaffoldMessenger.of(c).showSnackBar(
          SnackBar(
            content: const Text('نُقل العميل إلى الأرشيف. يمكنك التراجع الآن.'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'تراجع',
              onPressed: () => _restoreClient(c, phone),
            ),
          ),
        );
      }
    } catch (e) {
      if (c.mounted)
        ScaffoldMessenger.of(c).showSnackBar(
            SnackBar(content: Text('تعذر حذف العميل: ${_err(e)}')));
    }
  }

  Future<void> _restoreClient(BuildContext c, String phone) async {
    try {
      final permissions =
          jsonDecode(jsonEncode(_map(widget.data['permissions'])))
              as Map<String, dynamic>;
      final trusted = jsonDecode(jsonEncode(_map(widget.data['trusted'])))
          as Map<String, dynamic>;
      final archive = _list(trusted['archivedClients']).map(_map).toList();
      final index = archive.indexWhere(
          (entry) => _phoneKey('${entry['phone'] ?? ''}') == _phoneKey(phone));
      if (index < 0) return;
      final entry = archive.removeAt(index);
      final permissionClients =
          _list(permissions['clients']).map(_map).toList();
      final savedPermission = entry['permissions'];
      if (savedPermission is Map &&
          !permissionClients.any((item) =>
              _phoneKey('${item['phone'] ?? ''}') == _phoneKey(phone))) {
        permissionClients.add(_map(savedPermission));
      }
      final trustedClients = _list(trusted['clients'])
          .map((item) =>
              item is Map ? _map(item) : <String, dynamic>{'phone': '$item'})
          .toList();
      final savedTrusted = entry['trusted'];
      if (savedTrusted is Map &&
          !trustedClients.any((item) =>
              _phoneKey('${item['phone'] ?? ''}') == _phoneKey(phone))) {
        trustedClients.add(_map(savedTrusted));
      }
      permissions['clients'] = permissionClients;
      trusted['clients'] = trustedClients;
      trusted['archivedClients'] = archive;
      await NativeApi.instance.saveClientAndTrusted(permissions, trusted);
      await widget.onRefresh();
      if (mounted) setState(() => showingArchived = false);
      if (c.mounted)
        ScaffoldMessenger.of(c).showSnackBar(const SnackBar(
            content: Text('تمت استعادة العميل وإعداداته السابقة.')));
    } catch (e) {
      if (c.mounted)
        ScaffoldMessenger.of(c).showSnackBar(
            SnackBar(content: Text('تعذرت استعادة العميل: ${_err(e)}')));
    }
  }

  void _openAccount(BuildContext c, String phone) {
    final name = _clientDisplayName(phone, widget.data);
    Navigator.push(
        c,
        MaterialPageRoute(
          builder: (_) => AccountStatementPage(
            data: widget.data,
            phone: phone,
            onRefresh: widget.onRefresh,
            onSell: () async {
              await showModalBottomSheet<void>(
                context: c,
                isScrollControlled: true,
                builder: (_) => SaleSheet(
                    data: widget.data,
                    onDone: widget.onRefresh,
                    initialPhone: phone,
                    initialName: name),
              );
            },
          ),
        ));
  }
}

class ReportsPage extends StatefulWidget {
  final Map<String, dynamic> data;
  const ReportsPage({super.key, required this.data});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  int periodDays = 0;

  @override
  Widget build(BuildContext c) {
    final allSales = _sales(widget.data);
    final sales = allSales
        .where((s) => isInReportPeriod(s['time'], periodDays))
        .toList();
    final todaySales = allSales.where((s) => isInReportPeriod(s['time'], 1)).toList();
    final total = sales.fold<int>(0, (a, s) => a + reportAmount(s));
    final byPackage = salesByPackage(sales);
    final inventory = _inventory(widget.data);
    final stockTotal = inventory.values.fold<int>(0, (a, v) => a + _list(v).length);
    final lowStock = _list(widget.data['lowStockWarnings']).length;
    final debtorCount = _debts(widget.data)
        .where((d) => (d['amount'] as num? ?? 0) > 0)
        .length;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('التقارير', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            ),
            PopupMenuButton<int>(
              initialValue: periodDays,
              tooltip: 'الفترة الزمنية',
              onSelected: (value) => setState(() => periodDays = value),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 0, child: Text('كل الفترة')),
                PopupMenuItem(value: 1, child: Text('اليوم')),
                PopupMenuItem(value: 7, child: Text('آخر 7 أيام')),
                PopupMenuItem(value: 30, child: Text('آخر 30 يوماً')),
              ],
              child: Chip(
                avatar: const Icon(Icons.date_range, size: 18),
                label: Text(reportPeriodLabel(periodDays)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (sales.isEmpty)
          const EmptyCard(text: 'لا توجد مبيعات في الفترة المحددة.'),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            _statCard('إجمالي المبيعات', '${sales.length}', reportPeriodLabel(periodDays), Icons.receipt, emerald),
            _statCard('قيمة المبيعات', _money(total), 'الفترة المحددة', Icons.payments, blue),
            _statCard('مبيعات اليوم', '${todaySales.length}', 'كل اليوم', Icons.today, Colors.orange),
            _statCard('عملاء لديهم دين', '$debtorCount', 'حساب', Icons.people, Colors.purple),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _statCard('المخزون المتاح', '$stockTotal', 'كرت', Icons.inventory_2, emerald)),
            const SizedBox(width: 10),
            Expanded(child: _statCard('تنبيهات المخزون', '$lowStock', 'باقة منخفضة', Icons.warning_amber, Colors.deepOrange)),
          ],
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('المبيعات حسب الباقة — ${reportPeriodLabel(periodDays)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 18),
                SizedBox(
                  height: 190,
                  child: byPackage.isEmpty
                      ? const Center(child: Text('لا توجد بيانات كافية'))
                      : BarChart(
                          BarChartData(
                            barGroups: byPackage.entries.toList().asMap().entries.map((e) => BarChartGroupData(
                              x: e.key,
                              barRods: [BarChartRodData(toY: e.value.value.toDouble(), color: emerald, width: 20, borderRadius: BorderRadius.circular(5))],
                            )).toList(),
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (x, _) {
                                final i = x.toInt();
                                return i >= 0 && i < byPackage.length ? Padding(padding: const EdgeInsets.only(top: 8), child: Text(byPackage.keys.elementAt(i), style: const TextStyle(fontSize: 10))) : const SizedBox();
                              })),
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: () => _shareReport(c, sales), icon: const Icon(Icons.share), label: const Text('مشاركة تقرير المبيعات')),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => Share.share(buildSalesCsv(sales), subject: 'CSV — تقرير مبيعات القاضي نت — ${reportPeriodLabel(periodDays)}'),
          icon: const Icon(Icons.table_view_outlined),
          label: const Text('تصدير CSV / فتح في تطبيق الجداول'),
        ),
      ],
    );
  }
}

Future<void> _shareReport(
  BuildContext c,
  List<Map<String, dynamic>> sales,
) async {
  final content = [
    'تقرير مبيعات القاضي نت',
    'الوقت | الباقة | العميل | الكرت | الرصيد',
    ...sales.map(
      (s) =>
          '${s['time']} | ${s['packageId']} | ${s['phone']} | ${s['card']} | ${s['debt']}',
    ),
  ].join('\n');
  await Share.share(content, subject: 'تقرير مبيعات القاضي نت');
}

class SettingsPage extends StatelessWidget {
  final Map<String, dynamic> data;
  final Future<void> Function() onRefresh;
  const SettingsPage({super.key, required this.data, required this.onRefresh});
  @override
  Widget build(BuildContext c) {
    final trigger = _map(data['trigger']);
    final active = trigger['triggerEnabled'] == true;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'الإعدادات',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        Card(
          child: ExpansionTile(
            leading: const Icon(Icons.settings_outlined, color: emerald),
            title: const Text('عام'),
            subtitle: const Text('حالة المحرك والخيارات الأساسية'),
            children: [
              SwitchListTile(
                value: active,
                onChanged: (value) async {
                  await NativeApi.instance.toggleService();
                  if (value) await NativeApi.instance.startService();
                  await onRefresh();
                },
                title: const Text('محرك استقبال SMS'),
                subtitle:
                    Text(active ? 'نشط ويعمل عند وصول طلب' : 'متوقف مؤقتاً'),
                secondary: const Icon(Icons.bolt, color: emerald),
              ),
            ],
          ),
        ),
        Card(
          child: ExpansionTile(
            leading: const Icon(Icons.palette_outlined, color: emerald),
            title: const Text('الواجهة'),
            subtitle: const Text('الخصوصية وطريقة العرض وسهولة الاستخدام'),
            children: [
              ValueListenableBuilder(
                valueListenable: Hive.box('preferences').listenable(),
                builder: (_, box, __) => Column(children: [
                  SwitchListTile(
                    value: box.get('privacyMode', defaultValue: false) as bool,
                    onChanged: (value) => box.put('privacyMode', value),
                    title: const Text('وضع الخصوصية السريع'),
                    subtitle: const Text(
                        'يخفي الشاشة فوراً حتى تختار إظهارها مجدداً.'),
                    secondary: const Icon(Icons.visibility_off),
                  ),
                  SwitchListTile(
                    value: box.get('oneHanded', defaultValue: false) as bool,
                    onChanged: (value) => box.put('oneHanded', value),
                    title: const Text('وضع الاستخدام بيد واحدة'),
                    subtitle:
                        const Text('زر بيع سريع أكبر وشريط تنقل أسهل للمس.'),
                    secondary: const Icon(Icons.pan_tool_alt_outlined),
                  ),
                  SwitchListTile(
                    value: box.get('dark', defaultValue: false) as bool,
                    onChanged: (value) => box.put('dark', value),
                    title: const Text('الوضع الليلي'),
                    secondary: const Icon(Icons.dark_mode_outlined),
                  ),
                ]),
              ),
            ],
          ),
        ),
        Card(
          child: ExpansionTile(
            leading: const Icon(Icons.tune, color: emerald),
            title: const Text('السلوك'),
            subtitle: const Text('الرسائل والرد الآلي والصلاحيات والباقات'),
            children: [
              _settingTile(
                c,
                'قوالب الرسائل',
                'ردود البيع والرفض والإيصال والتحصيل والترحيب',
                Icons.text_snippet_outlined,
                () => Navigator.push(
                    c,
                    MaterialPageRoute(
                      builder: (_) =>
                          SmsTemplatesPage(data: data, onRefresh: onRefresh),
                    )),
              ),
              _settingTile(
                c,
                'تشخيص خدمة الرسائل',
                'الأذونات والشريحة والخدمة وأسباب عدم البيع',
                Icons.health_and_safety_outlined,
                () => Navigator.push(
                    c,
                    MaterialPageRoute(
                      builder: (_) => ServiceDiagnosticsPage(
                          data: data, onRefresh: onRefresh),
                    )),
              ),
              _settingTile(
                c,
                'المشغّل والعملاء الموثقون',
                'أنماط الرسائل والفئات وقائمة الموثقين',
                Icons.tune,
                () => Navigator.push(
                  c,
                  MaterialPageRoute(
                    builder: (_) =>
                        EnginePage(data: data, onRefresh: onRefresh),
                  ),
                ),
              ),
              _settingTile(
                c,
                'الصلاحيات العامة',
                'من يمكنه الشراء والحدود والأوقات',
                Icons.admin_panel_settings,
                () => Navigator.push(
                  c,
                  MaterialPageRoute(
                    builder: (_) =>
                        GlobalPermissionsPage(data: data, onRefresh: onRefresh),
                  ),
                ),
              ),
              _settingTile(
                c,
                'الباقات',
                'إدارة أسعار الباقات وكلمات الطلب',
                Icons.card_membership,
                () => Navigator.push(
                  c,
                  MaterialPageRoute(
                    builder: (_) =>
                        PackagesPage(data: data, onRefresh: onRefresh),
                  ),
                ),
              ),
            ],
          ),
        ),
        Card(
          child: ExpansionTile(
            leading: const Icon(Icons.storage_outlined, color: emerald),
            title: const Text('متقدم'),
            subtitle: const Text('النسخ الاحتياطي والطباعة والتخزين والسجلات'),
            children: [
              _settingTile(
                c,
                'النسخ الاحتياطي',
                'تصدير ومشاركة نسخة كاملة من البيانات',
                Icons.backup,
                () => _backup(c),
              ),
              _settingTile(
                c,
                'المزامنة السحابية',
                'تسجيل الدخول إلى خادم PostgreSQL/API ومزامنة الأجهزة',
                Icons.cloud_sync_outlined,
                () => Navigator.push(
                  c,
                  MaterialPageRoute(builder: (_) => const CloudSyncSettingsPage()),
                ),
              ),
              _settingTile(
                c,
                'استعادة نسخة احتياطية',
                'استبدال البيانات بنسخة أو دمج البطاقات فقط',
                Icons.restore,
                () => _restoreBackup(c, onRefresh),
              ),
              _settingTile(
                c,
                'جهوزية الخلفية',
                'إعفاء التطبيق من تحسين البطارية',
                Icons.battery_saver,
                () => NativeApi.instance.openBatterySettings(),
              ),
              _settingTile(
                c,
                'الطابعة',
                'عرض الطابعات المتاحة وطباعة الإيصالات من سجل البيع',
                Icons.print_outlined,
                () => _printerSettings(c),
              ),
              _settingTile(
                c,
                'مكان التخزين',
                'عرض موقع بيانات التطبيق',
                Icons.folder_open,
                () async {
                  final p = await NativeApi.instance.dataPath();
                  if (c.mounted)
                    showDialog(
                      context: c,
                      builder: (_) => AlertDialog(
                        title: const Text('مجلد بيانات القاضي نت'),
                        content: SelectableText(p),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: const Text('حسناً'),
                          ),
                        ],
                      ),
                    );
                },
              ),
              _settingTile(
                c,
                'سجل العمليات',
                'آخر المبيعات المسجلة',
                Icons.history,
                () => _showLog(c, data),
              ),
              _settingTile(
                c,
                'حول التطبيق',
                'القاضي نت • الإصدار 1.3.3',
                Icons.info_outline,
                () => showAboutDialog(
                  context: c,
                  applicationName: 'القاضي نت',
                  applicationVersion: '1.3.3',
                  applicationLegalese: 'إدارة محلية لبيع كروت الإنترنت.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Widget _settingTile(
  BuildContext c,
  String title,
  String subtitle,
  IconData icon,
  VoidCallback onTap,
) =>
    Card(
      child: ListTile(
        leading: Icon(icon, color: emerald),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_left),
        onTap: onTap,
      ),
    );
Future<void> _showLog(BuildContext c, Map<String, dynamic> data) => showDialog(
      context: c,
      builder: (_) => AlertDialog(
        title: const Text('السجل'),
        content: SizedBox(
          width: 450,
          height: 400,
          child: ListView(
            children: _sales(data)
                .map(
                  (s) => ListTile(
                    title: Text('باقة ${s['packageId']} — ${s['phone']}'),
                    subtitle: Text('${s['time']} • ${s['card']}'),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('إغلاق')),
        ],
      ),
    );
Map<String, dynamic> _appPreferencesSnapshot() {
  final values = Hive.box('preferences').toMap();
  return <String, dynamic>{
    for (final entry in values.entries) entry.key.toString(): entry.value,
  };
}

Future<void> _backup(BuildContext c) async {
  try {
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final password = await showDialog<String>(
      context: c,
      builder: (_) => AlertDialog(
        title: const Text('حماية النسخة الاحتياطية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'تتضمن النسخة المخزون والسجل المالي والباقات والصلاحيات والمشغّل والعملاء المؤرشفين وتفضيلات التطبيق مثل الوضع الليلي. يفضل تشفيرها بكلمة مرور من 8 أحرف على الأقل؛ لا يمكن استعادة النسخة المشفرة من دونها. أذونات Android والشريحة تظل خاصة بالجهاز.'),
            TextField(
                controller: passwordController,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'كلمة المرور (اختيارية)')),
            TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'تأكيد كلمة المرور')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(c, ''),
              child: const Text('متابعة بلا تشفير')),
          FilledButton(
              onPressed: () => Navigator.pop(c, passwordController.text),
              child: const Text('تشفير وتصدير')),
        ],
      ),
    );
    if (password != null &&
        password.isNotEmpty &&
        password != confirmPasswordController.text) {
      passwordController.dispose();
      confirmPasswordController.dispose();
      throw Exception('كلمتا المرور غير متطابقتين.');
    }
    if (password != null && password.isNotEmpty && password.trim().isEmpty) {
      passwordController.dispose();
      confirmPasswordController.dispose();
      throw Exception('كلمة المرور لا يمكن أن تكون مسافات فقط.');
    }
    passwordController.dispose();
    confirmPasswordController.dispose();
    if (password == null) return;
    if (password.isNotEmpty && password.length < 8)
      throw Exception('كلمة المرور يجب أن تتكون من 8 أحرف على الأقل.');
    if (password.isEmpty) {
      final confirmed = await showDialog<bool>(
            context: c,
            builder: (_) => AlertDialog(
              title: const Text('نسخة غير مشفرة'),
              content: const Text(
                  'ستتضمن النسخة كل بيانات التطبيق وإعداداته، ومنها أرقام البطاقات والعملاء والدفتر المالي. لا تشارك الملف إلا عبر مكان موثوق. هل تريد المتابعة؟'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('إلغاء')),
                FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('متابعة')),
              ],
            ),
          ) ??
          false;
      if (!confirmed) return;
    }
    final content = await NativeApi.instance.exportBackup(
      password: password,
      appPreferences: _appPreferencesSnapshot(),
    );
    if (content.isEmpty) throw Exception('تعذر إنشاء ملف النسخة الاحتياطية.');
    final file = File(
      '${Directory.systemTemp.path}/qadinet-backup-${DateTime.now().millisecondsSinceEpoch}.json',
    );
    await file.writeAsString(content);
    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'نسخة احتياطية من القاضي نت');
  } catch (e) {
    if (c.mounted)
      ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(_err(e))));
  }
}

Future<void> _restoreBackup(
    BuildContext c, Future<void> Function() onRefresh) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      // Android 7 devices may not map the json extension to a MIME type.
      // Pick any file and validate it locally after the user selects it.
      type: FileType.any,
      withData: false,
    );
    if (result == null) return;
    final selected = result.files.single;
    if (!selected.name.toLowerCase().endsWith('.json')) {
      throw Exception('اختر ملف نسخة احتياطية بامتداد .json.');
    }
    if (selected.size > 80 * 1024 * 1024)
      throw Exception('حجم النسخة يتجاوز 80 ميغابايت.');
    final bytes = selected.bytes ?? await File(selected.path!).readAsBytes();
    final content = utf8.decode(bytes);
    final preview = _map(jsonDecode(content));
    final encrypted = preview['format'] == 'qadinet-encrypted-backup-v1';
    String password = '';
    if (encrypted) {
      final controller = TextEditingController();
      password = await showDialog<String>(
            context: c,
            builder: (_) => AlertDialog(
              title: const Text('نسخة مشفرة'),
              content: TextField(
                  controller: controller,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'كلمة مرور النسخة')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('إلغاء')),
                FilledButton(
                    onPressed: () => Navigator.pop(c, controller.text),
                    child: const Text('متابعة')),
              ],
            ),
          ) ??
          '';
      controller.dispose();
      if (password.isEmpty) return;
    }
    final inventory = _map(preview['inventory']);
    final cardCount = inventory.values
        .fold<int>(0, (sum, cards) => sum + _list(cards).length);
    final transactionCount = _list(preview['transactions']).length;
    final debtCount = _list(preview['debts']).length;
    final packageCount = _list(_map(preview['packages'])['packages']).length;
    final appPreferencesCount = _map(preview['appPreferences']).length;
    final archivedClientCount =
        _list(_map(preview['trusted'])['archivedClients']).length;
    if (!c.mounted) return;
    final mode = await showDialog<String>(
      context: c,
      builder: (_) => AlertDialog(
        title: const Text('استعادة نسخة احتياطية'),
        content: Text(encrypted
            ? 'الملف: ${selected.name}\nالنسخة محمية بتشفير. بعد إدخال كلمة المرور يتحقق التطبيق من البيانات، ثم يستعيد إعدادات التطبيق المضمنة مع البيانات عند اختيار الاستبدال. أذونات Android تظل خاصة بهذا الجهاز.\n\nيمكنك دمج البطاقات فقط أو استبدال البيانات والإعدادات. عند الاستبدال تُحفظ نسخة أمان كاملة من الحالة الحالية أولاً.'
            : 'الملف: ${selected.name}\nالبطاقات: $cardCount • الحركات: $transactionCount • العملاء ذوو الرصيد: $debtCount\nالإعدادات: $packageCount باقات • $archivedClientCount عملاء مؤرشفون • $appPreferencesCount تفضيلات واجهة\n\nيمكنك دمج البطاقات فقط، أو استبدال البيانات والإعدادات المحلية كاملة. لا تُنقل أذونات Android أو حالة الشريحة بين الأجهزة.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          OutlinedButton(
              onPressed: () => Navigator.pop(c, 'merge_cards'),
              child: const Text('دمج البطاقات فقط')),
          FilledButton(
              onPressed: () => Navigator.pop(c, 'replace_all'),
              child: const Text('استبدال البيانات كاملة')),
        ],
      ),
    );
    if (mode == null) return;
    final restored = await NativeApi.instance.restoreBackup(
      content,
      mode: mode,
      password: password,
      currentAppPreferences: _appPreferencesSnapshot(),
    );
    if (mode == 'replace_all' && restored['hasAppPreferences'] == true) {
      final incomingPreferences = restored['appPreferences'];
      if (incomingPreferences is Map) {
        final preferences = Hive.box('preferences');
        final normalizedPreferences = <String, dynamic>{
          for (final entry in incomingPreferences.entries)
            entry.key.toString(): entry.value,
        };
        await preferences.clear();
        if (normalizedPreferences.isNotEmpty) {
          await preferences.putAll(normalizedPreferences);
        }
      }
    }
    await onRefresh();
    if (c.mounted) {
      ScaffoldMessenger.of(c).showSnackBar(SnackBar(
        content: Text(mode == 'merge_cards'
            ? 'تم دمج البطاقات الجديدة فقط.'
            : 'تمت استعادة البيانات والإعدادات. توجد نسخة أمان سابقة داخل مساحة التطبيق؛ تحقق من أذونات Android على هذا الجهاز.'),
      ));
    }
  } catch (e) {
    if (c.mounted)
      ScaffoldMessenger.of(c)
          .showSnackBar(SnackBar(content: Text('تعذرت الاستعادة: ${_err(e)}')));
  }
}

class EnginePage extends StatefulWidget {
  final Map<String, dynamic> data;
  final Future<void> Function() onRefresh;
  const EnginePage({super.key, required this.data, required this.onRefresh});
  @override
  State<EnginePage> createState() => _EnginePageState();
}

class _EnginePageState extends State<EnginePage> {
  late Map<String, dynamic> packages;
  late Map<String, dynamic> trusted;
  int selectedSection = 0;
  @override
  void initState() {
    super.initState();
    packages = jsonDecode(jsonEncode(_map(widget.data['packages'])));
    trusted = jsonDecode(jsonEncode(_map(widget.data['trusted'])));
  }

  @override
  Widget build(BuildContext c) {
    final ps = _list(packages['packages']).map(_map).toList();
    final keywordConflicts = SelectedFeatures.keywordConflicts(ps);
    final clients = _list(trusted['clients']);
    return Scaffold(
      appBar: AppBar(title: const Text('المشغّل والعملاء الموثقون')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => setState(() => selectedSection = 0),
                    child: const Text('المشغّل والباقات'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => setState(() => selectedSection = 1),
                    child: const Text('العملاء الموثقون'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => setState(() => selectedSection = 2),
                icon: const Icon(Icons.chat),
                label: const Text('الرد الآلي عبر WhatsApp'),
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: selectedSection,
              children: [
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'كلمات الطلب تُستخرج من ملف الباقات؛ تطابق الفئة الأعلى أولاً.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    if (ps.isEmpty)
                      const EmptyCard(
                          text:
                              'لا توجد باقات للمشغّل. أضف باقة لبدء مطابقة الطلبات.'),
                    if (keywordConflicts.isNotEmpty)
                      Card(
                        color: Colors.deepOrange.withValues(alpha: .08),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('تنبيه: توجد كلمات طلب متعارضة',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepOrange)),
                              ...keywordConflicts
                                  .map((conflict) => Text('• $conflict')),
                            ],
                          ),
                        ),
                      ),
                    ...ps.map((p) {
                      final words =
                          _list(p['keywords']).map((v) => '$v').toList();
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.sms, color: emerald),
                                title: Text(
                                    'باقة ${p['label'] ?? p['id']} — ${p['price']} ر.ي'),
                                subtitle: Text(
                                    'المعرّف: ${p['id']}  •  كلمات مطابقة: ${words.length}'),
                                trailing: IconButton(
                                  tooltip: 'تعديل كلمات الطلب',
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _editKeywords(c, p),
                                ),
                              ),
                              if (words.isNotEmpty)
                                Wrap(
                                    spacing: 6,
                                    runSpacing: 2,
                                    children: words
                                        .map((word) => Chip(label: Text(word)))
                                        .toList())
                              else
                                const Text(
                                    'لا توجد كلمات طلب لهذه الباقة؛ أضفها من تعديل الباقة.',
                                    style: TextStyle(color: Colors.deepOrange)),
                            ],
                          ),
                        ),
                      );
                    }),
                    FilledButton.icon(
                      onPressed: () async {
                        final latest = NativeApi.instance.snapshot;
                        final latestPackages = _map(latest['packages']).isEmpty
                            ? packages
                            : _map(latest['packages']);
                        await _editPackage(
                          c,
                          null,
                          {...widget.data, 'packages': latestPackages},
                          _reloadState,
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة باقة'),
                    ),
                    FilledButton.icon(
                      onPressed: () => _save(c),
                      icon: const Icon(Icons.save),
                      label: const Text('حفظ إعدادات المشغّل'),
                    ),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SwitchListTile(
                      value: trusted['filterEnabled'] == true,
                      onChanged: (v) =>
                          setState(() => trusted['filterEnabled'] = v),
                      title: const Text('حصر الشراء بالعملاء الموثقين'),
                    ),
                    FilledButton.icon(
                      onPressed: () => _addTrusted(c),
                      icon: const Icon(Icons.person_add),
                      label: const Text('إضافة من جهات الاتصال أو يدوياً'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _addTrustedBatch(c),
                      icon: const Icon(Icons.playlist_add),
                      label: const Text('إضافة عدة أرقام دفعة واحدة'),
                    ),
                    if (clients.isEmpty)
                      const EmptyCard(
                          text:
                              'لا يوجد عملاء موثقون بعد. أضف عميلًا أو فعّل وضع التوثيق عند الحاجة.'),
                    ...clients.map((v) {
                      final phone = v is Map ? '${v['phone']}' : '$v';
                      return ListTile(
                        leading: const Icon(
                          Icons.verified_user,
                          color: emerald,
                        ),
                        title: Text(
                          v is Map ? '${v['name'] ?? phone}' : phone,
                        ),
                        subtitle: Text(phone),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => setState(() => clients.remove(v)),
                        ),
                      );
                    }),
                    FilledButton.icon(
                      onPressed: () => _save(c),
                      icon: const Icon(Icons.save),
                      label: const Text('حفظ قائمة الموثقين'),
                    ),
                  ],
                ),
                WhatsAppAutoReplyPanel(
                  data: widget.data,
                  onRefresh: widget.onRefresh,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reloadState() async {
    await widget.onRefresh();
    if (!mounted) return;
    final latest = NativeApi.instance.snapshot;
    setState(() {
      packages = jsonDecode(jsonEncode(_map(latest['packages'])))
          as Map<String, dynamic>;
      trusted = jsonDecode(jsonEncode(_map(latest['trusted'])))
          as Map<String, dynamic>;
    });
  }

  Future<void> _editKeywords(BuildContext c, Map<String, dynamic> p) async {
    final ctl = TextEditingController(text: _list(p['keywords']).join(', '));
    final text = await showDialog<String>(
      context: c,
      builder: (_) => AlertDialog(
        title: Text('كلمات باقة ${p['id']}'),
        content: TextField(
          controller: ctl,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(hintText: 'افصل الكلمات بفواصل'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, ctl.text),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (text == null) return;
    final keywords = _parsePackageKeywords(text);
    final id = '${p['id']}';
    if (keywords.isEmpty) {
      if (c.mounted)
        ScaffoldMessenger.of(c).showSnackBar(
            const SnackBar(content: Text('أدخل كلمة طلب واحدة على الأقل.')));
      return;
    }
    if (!keywords.any((word) => word.toLowerCase() == id.toLowerCase()))
      keywords.add(id);
    final items = _list(packages['packages']);
    final index = items.indexWhere((item) => '${_map(item)['id']}' == id);
    if (index < 0) return;
    final previous = _map(items[index]);
    items[index] = {...previous, 'keywords': keywords};
    setState(() {});
    try {
      await NativeApi.instance.saveConfig('packages.json', packages);
      await _reloadState();
      if (c.mounted)
        ScaffoldMessenger.of(c)
            .showSnackBar(const SnackBar(content: Text('تم حفظ كلمات الطلب.')));
    } catch (e) {
      items[index] = previous;
      if (mounted) setState(() {});
      if (c.mounted)
        ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(_err(e))));
    }
  }

  Future<void> _addTrusted(BuildContext c) async {
    PickedContact? contact;
    try {
      contact = await NativeApi.instance.pickContact();
    } catch (_) {
      // The client editor still permits manual entry when contacts access is denied.
    }
    await _editClient(
      c,
      contact?.phone,
      widget.data,
      widget.onRefresh,
      initialName: contact?.name,
      onSave: (client, permissions) async {
        final nextTrusted =
            jsonDecode(jsonEncode(trusted)) as Map<String, dynamic>;
        final clients = _list(nextTrusted['clients']).map(_map).toList();
        final index = clients.indexWhere((value) =>
            _phoneKey('${value['phone'] ?? ''}') ==
            _phoneKey('${client['phone']}'));
        final trustedClient = {
          'phone': client['phone'],
          'name': client['name']
        };
        if (index < 0) {
          clients.add(trustedClient);
        } else {
          clients[index] = {...clients[index], ...trustedClient};
        }
        nextTrusted['clients'] = clients;
        await NativeApi.instance.saveClientAndTrusted(permissions, nextTrusted);
        if (mounted) setState(() => trusted = nextTrusted);
      },
    );
  }

  Future<void> _addTrustedBatch(BuildContext c) async {
    final controller = TextEditingController();
    final raw = await showDialog<String>(
      context: c,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إضافة أرقام موثوقة متعددة'),
        content: SizedBox(
          width: 460,
          child: TextField(
            controller: controller,
            minLines: 6,
            maxLines: 12,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              labelText: 'الأرقام',
              hintText:
                  'رقم في كل سطر أو افصل بفاصلة\nمثال: 0771234567\nأحمد | +967771234568',
              alignLabelWithHint: true,
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('معاينة الأرقام')),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (raw == null || !mounted) return;

    Set<String> currentNumbers() => {
          ..._list(trusted['clients']).map(
              (entry) => entry is Map ? '${entry['phone'] ?? ''}' : '$entry'),
          ..._list(trusted['archivedClients'])
              .map((entry) => '${_map(entry)['phone'] ?? ''}'),
        };

    var preview = parseTrustedImport(raw, existingNumbers: currentNumbers());
    if (preview.valid.isEmpty) {
      ScaffoldMessenger.of(c).showSnackBar(SnackBar(
        content: Text(preview.duplicates.isNotEmpty
            ? 'لم توجد أرقام جديدة؛ ${preview.duplicates.length} مكرر و${preview.invalid.length} غير صالح.'
            : 'لم توجد أرقام صحيحة للإضافة.'),
      ));
      return;
    }
    final approved = await showDialog<bool>(
          context: c,
          builder: (dialogContext) => AlertDialog(
            title: const Text('مراجعة الأرقام'),
            content: SizedBox(
              width: 460,
              height: 300,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                      'جديد: ${preview.valid.length} • مكرر: ${preview.duplicates.length} • غير صالح: ${preview.invalid.length}'),
                  const SizedBox(height: 8),
                  const Text(
                      'سيُضاف الجديد كعميل موثوق مع صلاحيات تبدأ من إعدادات المشغّل العامة.'),
                  const Divider(),
                  Expanded(
                    child: ListView(children: [
                      ...preview.valid.take(20).map((entry) => ListTile(
                            dense: true,
                            title: Text(
                                entry.name.isEmpty ? entry.phone : entry.name),
                            subtitle:
                                entry.name.isEmpty ? null : Text(entry.phone),
                            leading:
                                const Icon(Icons.verified_user, color: emerald),
                          )),
                      if (preview.valid.length > 20)
                        Text('و ${preview.valid.length - 20} رقم إضافي…'),
                      if (preview.duplicates.isNotEmpty)
                        Text('مكرر: ${preview.duplicates.take(5).join('، ')}'),
                      if (preview.invalid.isNotEmpty)
                        Text('غير صالح: ${preview.invalid.take(5).join('، ')}'),
                    ]),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('إلغاء')),
              FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text('إضافة ${preview.valid.length}')),
            ],
          ),
        ) ??
        false;
    if (!approved || !mounted) return;

    try {
      final latest = await NativeApi.instance.refresh();
      final latestTrusted = jsonDecode(jsonEncode(_map(latest['trusted'])))
          as Map<String, dynamic>;
      final latestPermissions =
          jsonDecode(jsonEncode(_map(latest['permissions'])))
              as Map<String, dynamic>;
      final known = <String>{
        ..._list(latestTrusted['clients']).map(
            (entry) => entry is Map ? '${entry['phone'] ?? ''}' : '$entry'),
        ..._list(latestTrusted['archivedClients'])
            .map((entry) => '${_map(entry)['phone'] ?? ''}'),
      };
      preview = parseTrustedImport(raw, existingNumbers: known);
      if (preview.valid.isEmpty) {
        if (c.mounted) {
          ScaffoldMessenger.of(c).showSnackBar(const SnackBar(
              content: Text(
                  'أُضيفت هذه الأرقام أو تكررت أثناء المراجعة؛ لم يُكرر أي رقم.')));
        }
        return;
      }

      final trustedClients = _list(latestTrusted['clients'])
          .map((entry) =>
              entry is Map ? _map(entry) : <String, dynamic>{'phone': '$entry'})
          .toList();
      final permissionClients =
          _list(latestPermissions['clients']).map(_map).toList();
      final global = _map(latestPermissions['global']);
      final globalPackages = _list(global['allowedPackages']).isEmpty
          ? _packages(latest).map((entry) => '${entry['id']}').toList()
          : _list(global['allowedPackages']).map((entry) => '$entry').toList();
      final globalMethods = _list(global['paymentMethods']).isEmpty
          ? <String>['cash', 'credit']
          : _list(global['paymentMethods']).map((entry) => '$entry').toList();
      for (final entry in preview.valid) {
        trustedClients.add({'phone': entry.phone, 'name': entry.name});
        final permissionIndex = permissionClients.indexWhere((value) =>
            normalizeWhatsAppNumber('${value['phone'] ?? ''}') ==
            normalizeWhatsAppNumber(entry.phone));
        if (permissionIndex < 0) {
          permissionClients.add({
            'phone': entry.phone,
            'name': entry.name,
            'enabled': true,
            'blocked': false,
            'allowedPackages': globalPackages,
            'maxDebt': global['maxDebt'] ?? 50000,
            'maxDailyTransactions': global['maxDailyTransactions'] ?? 10,
            'maxDailyAmount': global['maxDailyAmount'] ?? 100000,
            'paymentMethods': globalMethods,
            'timeRestriction': _map(global['timeRestriction']).isEmpty
                ? {'enabled': false, 'from': '08:00', 'to': '22:00'}
                : _map(global['timeRestriction']),
            'notes': '',
          });
        }
      }
      latestTrusted['clients'] = trustedClients;
      latestPermissions['clients'] = permissionClients;
      await NativeApi.instance
          .saveClientAndTrusted(latestPermissions, latestTrusted);
      await _reloadState();
      if (c.mounted) {
        ScaffoldMessenger.of(c).showSnackBar(SnackBar(
            content: Text('تمت إضافة ${preview.valid.length} أرقام موثوقة.')));
      }
    } catch (e) {
      if (c.mounted) {
        ScaffoldMessenger.of(c).showSnackBar(
            SnackBar(content: Text('تعذرت إضافة الأرقام: ${_err(e)}')));
      }
    }
  }

  Future<void> _save(BuildContext c) async {
    try {
      await NativeApi.instance.saveConfig('packages.json', packages);
      await NativeApi.instance.saveConfig('trusted_clients.json', trusted);
      await _reloadState();
      if (c.mounted)
        ScaffoldMessenger.of(c)
            .showSnackBar(const SnackBar(content: Text('تم الحفظ')));
    } catch (e) {
      if (c.mounted)
        ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(_err(e))));
    }
  }
}

class WhatsAppAutoReplyPanel extends StatefulWidget {
  final Map<String, dynamic> data;
  final Future<void> Function() onRefresh;
  const WhatsAppAutoReplyPanel({
    super.key,
    required this.data,
    required this.onRefresh,
  });

  @override
  State<WhatsAppAutoReplyPanel> createState() => _WhatsAppAutoReplyPanelState();
}

class _WhatsAppAutoReplyPanelState extends State<WhatsAppAutoReplyPanel>
    with WidgetsBindingObserver {
  bool accessGranted = false;
  bool saving = false;
  late bool enabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    enabled = _map(widget.data['trigger'])['whatsappAutoReplyEnabled'] == true;
    _refreshAccess();
  }

  @override
  void didUpdateWidget(covariant WhatsAppAutoReplyPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    enabled = _map(widget.data['trigger'])['whatsappAutoReplyEnabled'] == true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshAccess();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refreshAccess() async {
    try {
      final granted = await NativeApi.instance.hasWhatsAppNotificationAccess();
      if (mounted) setState(() => accessGranted = granted);
    } catch (_) {
      if (mounted) setState(() => accessGranted = false);
    }
  }

  Future<void> _openSystemAccess() async {
    try {
      await NativeApi.instance.openWhatsAppNotificationSettings();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر فتح إعدادات الإشعارات: $error')),
        );
      }
    }
  }

  Future<void> _setEnabled(bool value) async {
    if (value && _map(widget.data['trigger'])['triggerEnabled'] == false) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'شغّل المحرك العام أولاً؛ إيقافه يعطل جميع طلبات البيع الآلي.'),
      ));
      return;
    }
    if (value && !accessGranted) {
      final openSettings = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('يتطلب الوصول إلى الإشعارات'),
              content: const Text(
                'تتيح صلاحية Android هذه للتطبيق تقنياً الوصول إلى إشعارات الجهاز. لن يعالج التطبيق إلا إشعارات WhatsApp عند تفعيل الميزة، ولن يحفظ نصوص الإشعارات. لا يبيع عبر الإشعار إلا إذا أمكن تحديد رقم المرسل بثقة.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('ليس الآن'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('فتح إعدادات النظام'),
                ),
              ],
            ),
          ) ??
          false;
      if (openSettings) await _openSystemAccess();
      return;
    }

    setState(() => saving = true);
    try {
      final latest = await NativeApi.instance.refresh();
      final trigger = Map<String, dynamic>.from(_map(latest['trigger']));
      trigger['whatsappAutoReplyEnabled'] = value;
      await NativeApi.instance.saveConfig('trigger_config.json', trigger);
      await widget.onRefresh();
      if (!mounted) return;
      setState(() => enabled = value);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(value
            ? 'تم تفعيل الرد الآلي عبر WhatsApp.'
            : 'تم إيقاف الرد الآلي عبر WhatsApp.'),
      ));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حفظ الإعداد: ${_err(error)}')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('الرد المباشر من إشعار WhatsApp',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text(
                    'لا يحتاج هذا الخيار إلى خادم أو متصفح. يعتمد على إشعار الرسالة وزر الرد المباشر الذي يتيحه تطبيق WhatsApp؛ إذا أُخفيت معاينة الرسالة أو لم يتوفر زر الرد فلن ينفذ البيع. هذا ليس تكاملاً رسمياً عبر WhatsApp Business Platform، ولا يضمن استمرار التوافق أو عدم تقييد حساب WhatsApp.',
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      accessGranted ? Icons.check_circle : Icons.error_outline,
                      color: accessGranted ? Colors.green : Colors.deepOrange,
                    ),
                    title: const Text('صلاحية إشعارات النظام'),
                    subtitle: Text(accessGranted
                        ? 'ممنوحة لهذا التطبيق'
                        : 'غير ممنوحة — يلزم تفعيلها يدوياً من Android'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openSystemAccess,
                    icon: const Icon(Icons.settings),
                    label: const Text('إدارة صلاحية الإشعارات'),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: enabled,
                    onChanged: saving ? null : _setEnabled,
                    title: const Text('تفعيل بيع الباقات والرد تلقائياً'),
                    subtitle: Text(saving
                        ? 'جارٍ حفظ الإعداد…'
                        : enabled
                            ? 'الرد الآلي مفعّل'
                            : 'متوقف افتراضياً'),
                  ),
                ],
              ),
            ),
          ),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ضوابط الأمان',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  SizedBox(height: 8),
                  Text(
                    '• صلاحية Notification Access واسعة على مستوى Android، لكن الخدمة لا تفحص بيانات الإشعار إلا لحزمتي WhatsApp وWhatsApp Business وبعد تفعيل الخيار، ولا تخزن نص الرسالة.\n'
                    '• تُتجاهل المجموعات والإشعارات التي لا تحمل زر رد مباشر.\n'
                    '• يجب أن يظهر رقم يمني في الإشعار أو أن يطابق اسم المرسل اسماً واحداً فقط في قائمة العملاء الموثوقين. الاسم المكرر أو المجهول يُتجاهل.\n'
                    '• لا يُصرف الكرت إلا عند وجود زر رد مباشر في الإشعار. يُمنع تكرار الطلب نفسه لتفادي صرف بطاقة ثانية عند تحديث الإشعار.\n'
                    '• يخضع البيع نفسه لكلمات الباقات والأذونات والحدود والمخزون المسجلة في التطبيق. لا تُحفظ نصوص الإشعارات في سجل الأحداث.',
                  ),
                ],
              ),
            ),
          ),
        ],
      );
}

class GlobalPermissionsPage extends StatefulWidget {
  final Map<String, dynamic> data;
  final Future<void> Function() onRefresh;
  const GlobalPermissionsPage({
    super.key,
    required this.data,
    required this.onRefresh,
  });
  @override
  State<GlobalPermissionsPage> createState() => _GlobalPermissionsPageState();
}

class _GlobalPermissionsPageState extends State<GlobalPermissionsPage> {
  late Map<String, dynamic> config;
  final blocked = TextEditingController();
  @override
  void initState() {
    super.initState();
    config = jsonDecode(jsonEncode(_map(widget.data['permissions'])));
    final global = _map(config['global']);
    global.putIfAbsent('allowedPackages',
        () => _packages(widget.data).map((p) => '${p['id']}').toList());
    global.putIfAbsent('paymentMethods', () => ['cash', 'credit']);
    global.putIfAbsent('blockedClients', () => <String>[]);
    global.putIfAbsent('priceGroups', () => <Map<String, dynamic>>[]);
    global.putIfAbsent('timeRestriction',
        () => {'enabled': false, 'from': '08:00', 'to': '22:00'});
    config['global'] = global;
  }

  @override
  Widget build(BuildContext c) {
    final g = config['global'] as Map<String, dynamic>;
    final tr = g['timeRestriction'] as Map<String, dynamic>;
    final ids = _packages(widget.data).map((p) => '${p['id']}').toList();
    final allowed = _list(g['allowedPackages']).map((e) => '$e').toSet();
    return Scaffold(
      appBar: AppBar(title: const Text('الصلاحيات العامة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            value: g['allowAllClients'] != false,
            onChanged: (v) => setState(() => g['allowAllClients'] = v),
            title: const Text('السماح لجميع العملاء'),
            subtitle: const Text('عند التعطيل، الشراء للعملاء المسجلين فقط'),
          ),
          SwitchListTile(
            value: g['onlyTrusted'] == true,
            onChanged: (v) => setState(() => g['onlyTrusted'] = v),
            title: const Text('حصر الشراء بالموثقين'),
          ),
          const Divider(),
          const Text(
            'الباقات المسموحة',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          if (ids.isEmpty)
            const EmptyCard(
                text: 'لا توجد باقات للصلاحيات. أضف باقة أولاً من الإعدادات.'),
          ...ids.map(
            (id) => CheckboxListTile(
              value: allowed.contains(id),
              onChanged: (v) {
                setState(() {
                  if (v == true)
                    allowed.add(id);
                  else
                    allowed.remove(id);
                  g['allowedPackages'] = allowed.toList();
                });
              },
              title: Text('باقة $id'),
            ),
          ),
          const Divider(),
          const Text('مجموعات التسعير والخصم',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const Text(
              'يُطبّق خصم المجموعة تلقائياً على كل باقة، ويمكن تعيين خصم أو سعر خاص للعميل من ملفه.'),
          if (_list(g['priceGroups']).isEmpty)
            const ListTile(title: Text('لا توجد مجموعات تسعير بعد.')),
          ..._list(g['priceGroups']).map(_map).map((group) => Card(
                child: ListTile(
                  leading: const Icon(Icons.sell_outlined),
                  title: Text('${group['name'] ?? 'مجموعة'}'),
                  subtitle: Text('خصم ${group['discountPercent'] ?? 0}%'),
                  trailing: IconButton(
                    tooltip: 'حذف المجموعة',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() => _list(g['priceGroups'])
                        .removeWhere((value) =>
                            '${_map(value)['id']}' == '${group['id']}')),
                  ),
                ),
              )),
          OutlinedButton.icon(
            onPressed: _addPriceGroup,
            icon: const Icon(Icons.add),
            label: const Text('إنشاء مجموعة تسعير'),
          ),
          const Divider(),
          const Text('طرق الدفع المسموحة',
              style: TextStyle(fontWeight: FontWeight.bold)),
          ...['cash', 'credit'].map((method) => CheckboxListTile(
                value: _list(g['paymentMethods']).contains(method),
                onChanged: (v) => setState(() {
                  final methods =
                      _list(g['paymentMethods']).map((x) => '$x').toSet();
                  if (v == true) {
                    methods.add(method);
                  } else {
                    methods.remove(method);
                  }
                  g['paymentMethods'] = methods.toList();
                }),
                title: Text(method == 'cash' ? 'نقداً' : 'آجل / على الحساب'),
              )),
          const Divider(),
          _numberField('أقصى رصيد دين (ر.ي)', 'maxDebt', g, 50000),
          _numberField('عدد العمليات اليومي', 'maxDailyTransactions', g, 10),
          _numberField(
            'الحد اليومي للمشتريات (ر.ي)',
            'maxDailyAmount',
            g,
            100000,
          ),
          SwitchListTile(
            value: tr['enabled'] == true,
            onChanged: (v) => setState(() => tr['enabled'] = v),
            title: const Text('تقييد أوقات الشراء'),
          ),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: tr['from'] ?? '08:00',
                  decoration: const InputDecoration(labelText: 'من'),
                  onChanged: (v) => tr['from'] = v,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: tr['to'] ?? '22:00',
                  decoration: const InputDecoration(labelText: 'إلى'),
                  onChanged: (v) => tr['to'] = v,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'قائمة الحظر',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          TextField(
            controller: blocked,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'رقم محظور',
              suffixIcon: IconButton(
                icon: const Icon(Icons.contacts),
                onPressed: () async {
                  try {
                    final contact = await NativeApi.instance.pickContact();
                    if (contact != null) blocked.text = contact.phone;
                  } catch (_) {}
                },
              ),
            ),
          ),
          Wrap(
            spacing: 6,
            children: _list(g['blockedClients'])
                .map(
                  (v) => InputChip(
                    label: Text('$v'),
                    onDeleted: () =>
                        setState(() => _list(g['blockedClients']).remove(v)),
                  ),
                )
                .toList(),
          ),
          TextButton.icon(
            onPressed: () {
              if (blocked.text.trim().isNotEmpty)
                setState(
                  () => _list(g['blockedClients']).add(blocked.text.trim()),
                );
            },
            icon: const Icon(Icons.block),
            label: const Text('إضافة إلى الحظر'),
          ),
          FilledButton.icon(
            onPressed: save,
            icon: const Icon(Icons.save),
            label: const Text('حفظ الصلاحيات'),
          ),
        ],
      ),
    );
  }

  Widget _numberField(
    String label,
    String key,
    Map<String, dynamic> g,
    int fallback,
  ) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: TextFormField(
          initialValue: '${g[key] ?? fallback}',
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: label),
          onChanged: (v) => g[key] = int.tryParse(v) ?? fallback,
        ),
      );

  Future<void> _addPriceGroup() async {
    final name = TextEditingController();
    final discount = TextEditingController(text: '0');
    final value = await showDialog<(String, int)?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('مجموعة تسعير جديدة'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'اسم المجموعة')),
          TextField(
              controller: discount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'نسبة الخصم %')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () {
                final percent = num.tryParse(discount.text.trim());
                if (name.text.trim().isEmpty ||
                    percent == null ||
                    percent < 0 ||
                    percent > 100) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                          content: Text('أدخل اسماً وخصماً بين 0 و100.')));
                  return;
                }
                Navigator.pop(
                    dialogContext, (name.text.trim(), percent.round()));
              },
              child: const Text('إضافة')),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    name.dispose();
    discount.dispose();
    if (value == null || !mounted) return;
    final global = _map(config['global']);
    final groups = _list(global['priceGroups']);
    groups.add({
      'id': 'pg-${DateTime.now().microsecondsSinceEpoch}',
      'name': value.$1,
      'discountPercent': value.$2
    });
    global['priceGroups'] = groups;
    config['global'] = global;
    setState(() {});
  }

  Future<void> save() async {
    try {
      final g = config['global'] as Map<String, dynamic>;
      final maxDebt = int.tryParse('${g['maxDebt'] ?? 50000}') ?? -1;
      final maxTransactions =
          int.tryParse('${g['maxDailyTransactions'] ?? 10}') ?? -1;
      final maxAmount = int.tryParse('${g['maxDailyAmount'] ?? 100000}') ?? -1;
      if (maxDebt < 0 || maxTransactions < 0 || maxAmount < 0) {
        throw Exception('حدود الصلاحيات يجب أن تكون أرقاماً غير سالبة.');
      }
      if (_list(g['paymentMethods']).isEmpty) {
        throw Exception('اختر طريقة دفع واحدة على الأقل.');
      }
      final tr = g['timeRestriction'] as Map<String, dynamic>;
      final timePattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
      if (tr['enabled'] == true &&
          (!timePattern.hasMatch('${tr['from']}') ||
              !timePattern.hasMatch('${tr['to']}'))) {
        throw Exception('أدخل وقتاً صحيحاً بصيغة 08:30.');
      }
      config['global'] = g;
      await NativeApi.instance.saveConfig('permissions.json', config);
      await widget.onRefresh();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الصلاحيات العامة.')),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_err(e))));
    }
  }
}

Future<void> _editClient(
  BuildContext c,
  String? initial,
  Map<String, dynamic> data,
  Future<void> Function() refresh, {
  String? initialName,
  Future<void> Function(Map<String, dynamic>, Map<String, dynamic>)? onSave,
}) async {
  final all = jsonDecode(jsonEncode(_map(data['permissions'])));
  final perms = _map(all);
  final clients = _list(perms['clients']);
  final globalPermissions = _map(_map(data['permissions'])['global']);
  final priceGroups =
      _list(globalPermissions['priceGroups']).map(_map).toList();
  final configuredGlobalMethods = _list(globalPermissions['paymentMethods']);
  final defaultMethods = configuredGlobalMethods.isEmpty
      ? <dynamic>['cash', 'credit']
      : configuredGlobalMethods;
  Map<String, dynamic>? client;
  for (final v in clients) {
    final m = _map(v);
    if (_phoneKey('${m['phone'] ?? ''}') == _phoneKey(initial ?? ''))
      client = m;
  }
  client ??= {
    'phone': initial ?? '',
    'name': initialName ?? '',
    'enabled': true,
    'blocked': false,
    'allowedPackages': _packages(data).map((p) => '${p['id']}').toList(),
    'maxDebt': 50000,
    'maxDailyTransactions': 10,
    'maxDailyAmount': 100000,
    'paymentMethods': defaultMethods.toList(),
    'timeRestriction': {'enabled': false, 'from': '08:00', 'to': '22:00'},
    'notes': '',
  };
  final name =
      TextEditingController(text: '${client['name'] ?? initialName ?? ''}');
  final phone = TextEditingController(text: '${client['phone'] ?? ''}');
  final notes = TextEditingController(text: '${client['notes'] ?? ''}');
  final maxDebt = TextEditingController(text: '${client['maxDebt'] ?? 50000}');
  final maxTx =
      TextEditingController(text: '${client['maxDailyTransactions'] ?? 10}');
  final maxAmount =
      TextEditingController(text: '${client['maxDailyAmount'] ?? 100000}');
  final discount =
      TextEditingController(text: '${client['discountPercent'] ?? ''}');
  final packagePrices = <String, TextEditingController>{
    for (final p in _packages(data))
      '${p['id']}': TextEditingController(
          text: '${_map(client['packagePrices'])['${p['id']}'] ?? ''}'),
  };
  final reason =
      TextEditingController(text: '${client['temporaryBlockReason'] ?? ''}');
  DateTime? temporaryUntil =
      DateTime.tryParse('${client['blockedUntil'] ?? ''}');
  bool temporaryBlock = temporaryUntil?.isAfter(DateTime.now()) == true;
  String? priceGroup = '${client['priceGroup'] ?? ''}'.isEmpty
      ? null
      : '${client['priceGroup']}';
  final configuredClientMethods = _list(client['paymentMethods']);
  final methods = (configuredClientMethods.isEmpty
          ? defaultMethods
          : configuredClientMethods)
      .map((v) => '$v')
      .toSet();
  final clientTime = _map(client['timeRestriction']);
  final timeFrom =
      TextEditingController(text: "${clientTime['from'] ?? '08:00'}");
  final timeTo = TextEditingController(text: "${clientTime['to'] ?? '22:00'}");
  bool restrictTime = clientTime['enabled'] == true;
  final chosen = _list(client['allowedPackages']).map((v) => '$v').toSet();
  bool enabled = client['enabled'] != false,
      blockedState = client['blocked'] == true;
  await showDialog<void>(
    context: c,
    builder: (_) => StatefulBuilder(
      builder: (cx, set) => AlertDialog(
        title: Text(initial == null
            ? 'صلاحيات عميل جديد'
            : 'صلاحيات ${client!['name'] ?? initial}'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'اسم العميل'),
                ),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'رقم الهاتف',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.contacts),
                      onPressed: () async {
                        try {
                          final contact =
                              await NativeApi.instance.pickContact();
                          if (contact != null)
                            set(() {
                              phone.text = contact.phone;
                              if (contact.name.isNotEmpty)
                                name.text = contact.name;
                            });
                        } catch (_) {}
                      },
                    ),
                  ),
                ),
                SwitchListTile(
                  value: enabled,
                  onChanged: (v) => set(() => enabled = v),
                  title: const Text('الحساب مفعّل'),
                ),
                SwitchListTile(
                  value: blockedState,
                  onChanged: (v) => set(() => blockedState = v),
                  title: const Text('حظر العميل'),
                ),
                SwitchListTile(
                  value: temporaryBlock,
                  onChanged: (v) => set(() => temporaryBlock = v),
                  title: const Text('تعليق مؤقت حتى تاريخ ووقت'),
                  subtitle: const Text('ينتهي الحظر تلقائياً عند حلول الموعد.'),
                ),
                if (temporaryBlock) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(temporaryUntil == null
                        ? 'اختر موعد انتهاء الإيقاف'
                        : 'ينتهي: ${intl.DateFormat('yyyy/MM/dd HH:mm').format(temporaryUntil!)}'),
                    trailing: const Icon(Icons.schedule),
                    onTap: () async {
                      final now = DateTime.now();
                      final date = await showDatePicker(
                        context: cx,
                        firstDate: DateTime(now.year, now.month, now.day),
                        lastDate: DateTime(now.year + 5),
                        initialDate: temporaryUntil ?? now,
                      );
                      if (date == null || !cx.mounted) return;
                      final time = await showTimePicker(
                        context: cx,
                        initialTime:
                            TimeOfDay.fromDateTime(temporaryUntil ?? now),
                      );
                      if (time != null) {
                        set(() => temporaryUntil = DateTime(date.year,
                            date.month, date.day, time.hour, time.minute));
                      }
                    },
                  ),
                  TextField(
                    controller: reason,
                    decoration:
                        const InputDecoration(labelText: 'سبب التعليق المؤقت'),
                  ),
                ],
                const Divider(),
                const Align(
                    alignment: Alignment.centerRight,
                    child: Text('التسعير الخاص',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                if (priceGroups.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: priceGroup,
                    decoration:
                        const InputDecoration(labelText: 'مجموعة التسعير'),
                    items: [
                      const DropdownMenuItem<String>(
                          value: null, child: Text('بدون مجموعة')),
                      ...priceGroups.map((group) => DropdownMenuItem<String>(
                            value: '${group['id']}',
                            child: Text(
                                '${group['name']} (${group['discountPercent']}% خصم)'),
                          )),
                    ],
                    onChanged: (value) => set(() => priceGroup = value),
                  ),
                TextField(
                  controller: discount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'خصم خاص للعميل % (اختياري)',
                      helperText: 'يتقدم على خصم المجموعة.'),
                ),
                ...packagePrices.entries.map((entry) => TextField(
                      controller: entry.value,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: 'سعر خاص لباقة ${entry.key} (اختياري)'),
                    )),
                const Divider(),
                TextField(
                  controller: maxDebt,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'الحد الأقصى للدين',
                  ),
                ),
                TextField(
                    controller: maxTx,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'الحد اليومي لعدد العمليات')),
                TextField(
                    controller: maxAmount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'الحد اليومي للمشتريات')),
                const Align(
                    alignment: Alignment.centerRight,
                    child: Text('طرق الدفع المسموحة')),
                ...['cash', 'credit'].map((method) => CheckboxListTile(
                    value: methods.contains(method),
                    onChanged: (v) => set(() {
                          if (v == true) {
                            methods.add(method);
                          } else {
                            methods.remove(method);
                          }
                        }),
                    title: Text(method == 'cash' ? 'نقداً' : 'آجل'))),
                SwitchListTile(
                    value: restrictTime,
                    onChanged: (v) => set(() => restrictTime = v),
                    title: const Text('تحديد وقت الشراء لهذا العميل')),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: timeFrom,
                          decoration: const InputDecoration(labelText: 'من'))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: TextField(
                          controller: timeTo,
                          decoration: const InputDecoration(labelText: 'إلى')))
                ]),
                TextField(
                  controller: notes,
                  decoration: const InputDecoration(labelText: 'ملاحظات'),
                ),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text('الباقات المسموحة'),
                ),
                ..._packages(data).map((p) {
                  final id = '${p['id']}';
                  return CheckboxListTile(
                    value: chosen.contains(id),
                    onChanged: (v) => set(() {
                      if (v == true) {
                        chosen.add(id);
                      } else {
                        chosen.remove(id);
                      }
                    }),
                    title: Text(id),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(cx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              final updated = Map<String, dynamic>.from(client!);
              if (phone.text.trim().isEmpty) {
                ScaffoldMessenger.of(cx).showSnackBar(
                    const SnackBar(content: Text('رقم الهاتف مطلوب.')));
                return;
              }
              updated['name'] = name.text.trim();
              updated['phone'] = phone.text.trim();
              updated['enabled'] = enabled;
              updated['blocked'] = blockedState;
              updated['allowedPackages'] = chosen.toList();
              updated['maxDebt'] = int.tryParse(maxDebt.text) ?? 50000;
              updated['maxDailyTransactions'] = int.tryParse(maxTx.text) ?? 10;
              updated['maxDailyAmount'] =
                  int.tryParse(maxAmount.text) ?? 100000;
              updated['paymentMethods'] = methods.toList();
              updated['timeRestriction'] = {
                'enabled': restrictTime,
                'from': timeFrom.text,
                'to': timeTo.text
              };
              updated['notes'] = notes.text;
              final discountValue = num.tryParse(discount.text.trim());
              if (discount.text.trim().isNotEmpty &&
                  (discountValue == null ||
                      discountValue < 0 ||
                      discountValue > 100)) {
                ScaffoldMessenger.of(cx).showSnackBar(const SnackBar(
                    content: Text('نسبة الخصم يجب أن تكون بين 0 و100.')));
                return;
              }
              if (discount.text.trim().isEmpty) {
                updated.remove('discountPercent');
              } else {
                updated['discountPercent'] = discountValue;
              }
              if (priceGroup == null) {
                updated.remove('priceGroup');
              } else {
                updated['priceGroup'] = priceGroup;
              }
              final customPrices = <String, int>{};
              for (final entry in packagePrices.entries) {
                final raw = entry.value.text.trim();
                if (raw.isEmpty) continue;
                final value = int.tryParse(raw);
                if (value == null || value <= 0) {
                  ScaffoldMessenger.of(cx).showSnackBar(SnackBar(
                      content: Text('أدخل سعراً صحيحاً لباقة ${entry.key}.')));
                  return;
                }
                customPrices[entry.key] = value;
              }
              updated['packagePrices'] = customPrices;
              if (temporaryBlock) {
                if (temporaryUntil == null ||
                    !temporaryUntil!.isAfter(DateTime.now())) {
                  ScaffoldMessenger.of(cx).showSnackBar(const SnackBar(
                      content: Text('اختر موعداً مستقبلياً لانتهاء الإيقاف.')));
                  return;
                }
                updated['blockedUntil'] = temporaryUntil!.toIso8601String();
                updated['temporaryBlockReason'] = reason.text.trim();
              } else {
                updated['blockedUntil'] = '';
                updated['temporaryBlockReason'] = '';
              }
              final oldIndex = clients.indexWhere((v) =>
                  _phoneKey('${_map(v)['phone'] ?? ''}') ==
                  _phoneKey(initial ?? ''));
              final newIndex = clients.indexWhere((v) =>
                  _phoneKey('${_map(v)['phone'] ?? ''}') ==
                  _phoneKey('${updated['phone']}'));
              if (newIndex >= 0 && newIndex != oldIndex) {
                ScaffoldMessenger.of(cx).showSnackBar(const SnackBar(
                    content: Text('يوجد عميل مسجل بهذا الرقم بالفعل.')));
                return;
              }
              if (oldIndex >= 0) {
                clients[oldIndex] = updated;
              } else {
                clients.add(updated);
              }
              perms['clients'] = clients;
              try {
                if (onSave != null) {
                  await onSave(updated, perms);
                } else {
                  await NativeApi.instance
                      .saveConfig('permissions.json', perms);
                }
                await refresh();
                if (cx.mounted) Navigator.pop(cx);
              } catch (e) {
                if (cx.mounted)
                  ScaffoldMessenger.of(cx)
                      .showSnackBar(SnackBar(content: Text(_err(e))));
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 300));
  name.dispose();
  phone.dispose();
  notes.dispose();
  maxDebt.dispose();
  maxTx.dispose();
  maxAmount.dispose();
  discount.dispose();
  reason.dispose();
  for (final controller in packagePrices.values) {
    controller.dispose();
  }
  timeFrom.dispose();
  timeTo.dispose();
}

class PackagesPage extends StatefulWidget {
  final Map<String, dynamic> data;
  final Future<void> Function() onRefresh;
  const PackagesPage({super.key, required this.data, required this.onRefresh});

  @override
  State<PackagesPage> createState() => _PackagesPageState();
}

class _PackagesPageState extends State<PackagesPage> {
  late Map<String, dynamic> currentData;

  @override
  void initState() {
    super.initState();
    currentData = widget.data;
  }

  Future<void> _reload() async {
    await widget.onRefresh();
    if (mounted) setState(() => currentData = NativeApi.instance.snapshot);
  }

  @override
  Widget build(BuildContext c) {
    final packages = _packages(currentData);
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الباقات'),
        actions: [
          IconButton(
            tooltip: 'إضافة باقة',
            onPressed: () => _editPackage(c, null, currentData, _reload),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editPackage(c, null, currentData, _reload),
        icon: const Icon(Icons.add),
        label: const Text('إضافة باقة'),
      ),
      body: packages.isEmpty
          ? const EmptyCard(text: 'لا توجد باقات. أضف باقة جديدة للبدء.')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              children: [
                const Text(
                  'تحكم بالمعرّف والسعر وكلمات الطلب. تظهر الكلمات هنا وفي صفحة المشغّل، وتُحفظ تلقائياً في ملف الباقات.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 12),
                ...packages.map((p) {
                  final id = '${p['id']}';
                  final keywords = _list(p['keywords'])
                      .map((v) => '$v'.trim())
                      .where((v) => v.isNotEmpty)
                      .toList();
                  final stock = _list(_inventory(currentData)[id]).length;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.card_membership, color: emerald),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${p['label'] ?? id}  •  ${_money(p['price'])}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800),
                                    ),
                                    Text('المعرّف: $id  •  المخزون: $stock',
                                        style: const TextStyle(
                                            color: Colors.grey)),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _editPackage(c, p, currentData, _reload);
                                  } else if (value == 'delete') {
                                    _deletePackage(
                                        c, p, stock, currentData, _reload);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: 'edit',
                                      child: Text('تعديل الباقة والكلمات')),
                                  PopupMenuItem(
                                      value: 'delete',
                                      child: Text('حذف الباقة')),
                                ],
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          const Text('كلمات الطلب',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          if (keywords.isEmpty)
                            const Text(
                                'لا توجد كلمات؛ أضف كلمات الطلب من تعديل الباقة.',
                                style: TextStyle(color: Colors.deepOrange))
                          else
                            Wrap(
                              spacing: 6,
                              runSpacing: 2,
                              children: keywords
                                  .map((word) => Chip(label: Text(word)))
                                  .toList(),
                            ),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: TextButton.icon(
                              onPressed: () =>
                                  _editPackage(c, p, currentData, _reload),
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text('تعديل'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

Future<void> _showPackageSaveError(BuildContext context, String message) async {
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (errorContext) => AlertDialog(
      icon: const Icon(Icons.error_outline, color: Colors.redAccent),
      title: const Text('تعذرت إضافة الباقة'),
      content: SelectableText(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(errorContext),
          child: const Text('حسناً'),
        ),
      ],
    ),
  );
}

Future<void> _editPackage(
  BuildContext c,
  Map<String, dynamic>? package,
  Map<String, dynamic> data,
  Future<void> Function() refresh,
) async {
  final all =
      jsonDecode(jsonEncode(_map(data['packages']))) as Map<String, dynamic>;
  final items = _list(all['packages']).map((item) => _map(item)).toList();
  final oldId = package == null ? null : '${package['id']}';
  final itemIndex =
      oldId == null ? -1 : items.indexWhere((item) => '${item['id']}' == oldId);
  final existing = itemIndex < 0 ? <String, dynamic>{} : items[itemIndex];
  final label = TextEditingController(text: '${existing['label'] ?? ''}'),
      price = TextEditingController(text: '${existing['price'] ?? ''}'),
      words =
          TextEditingController(text: _list(existing['keywords']).join(', ')),
      minStock = TextEditingController(text: '${existing['minStock'] ?? 0}'),
      excludedWords = TextEditingController(
          text: _list(existing['excludedKeywords']).join(', ')),
      excludedNumbers = TextEditingController(
          text: _list(existing['excludedPhones']).join('\n'));
  final saved = await showDialog<bool>(
    context: c,
    builder: (dialogContext) => AlertDialog(
      title: Text(oldId == null ? 'إضافة باقة جديدة' : 'تعديل باقة $oldId'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'سعر/رقم الباقة بالريال',
                helperText: 'اكتب سعراً جديداً؛ لا يمكن تكرار سعر باقة موجودة.',
              ),
            ),
            const Padding(
              padding: EdgeInsetsDirectional.only(start: 12, top: 4),
              child: Text(
                'سيُحفظ الرقم نفسه كمعرّف تلقائي؛ مثلاً السعر 1000 ينتج المعرّف 1000.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            TextField(
              controller: label,
              decoration:
                  const InputDecoration(labelText: 'اسم العرض (اختياري)'),
            ),
            TextField(
              controller: words,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'كلمات الطلب',
                hintText: 'مثال: 500، باقة 500، خمسمائة',
                helperText:
                    'افصل الكلمات بفاصلة عربية/إنجليزية أو سطر جديد. ستظهر كلها في صفحة الباقات والمشغّل.',
              ),
            ),
            TextField(
              controller: minStock,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'حد تنبيه انخفاض المخزون',
                helperText: 'اكتب 0 لتعطيل التنبيه لهذه الباقة.',
              ),
            ),
            TextField(
              controller: excludedWords,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'كلمات مستثناة لهذه الباقة (اختياري)',
                helperText: 'إذا وردت إحداها في الرسالة فلن تطابق هذه الباقة.',
              ),
            ),
            TextField(
              controller: excludedNumbers,
              minLines: 1,
              maxLines: 3,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'أرقام مستثناة لهذه الباقة (اختياري)',
                helperText:
                    'رقم في كل سطر؛ لا يصرف له كرت عبر طلب SMS لهذه الباقة.',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () async {
            final value = PackageRules.parsePrice(price.text);
            if (value == null || value <= 0 || value > 2147483647) {
              await _showPackageSaveError(
                dialogContext,
                'أدخل سعراً صحيحاً من 1 إلى 2,147,483,647. سيُحفظ الرقم نفسه كمعرّف للباقة.',
              );
              return;
            }
            final packageId = '$value';
            if (!RegExp(r'^[0-9]{1,10}$').hasMatch(packageId)) {
              await _showPackageSaveError(
                dialogContext,
                'تعذر إنشاء معرّف رقمي من هذا السعر. اختر سعراً صحيحاً أصغر.',
              );
              return;
            }
            if (itemIndex < 0 && items.length >= 200) {
              await _showPackageSaveError(
                dialogContext,
                'وصلت إلى الحد الأقصى وهو 200 باقة.',
              );
              return;
            }
            final duplicate =
                items.indexWhere((item) => '${item['id']}' == packageId);
            if (duplicate >= 0 && duplicate != itemIndex) {
              await _showPackageSaveError(
                dialogContext,
                'توجد باقة بالفعل بالسعر والمعرّف $packageId. لا يمكن إضافة باقتين بالسعر نفسه؛ افتح الباقة الموجودة للتعديل أو اختر سعراً مختلفاً.',
              );
              return;
            }
            final keywords = _parsePackageKeywords(words.text);
            if (oldId != null && oldId != '$value') {
              keywords.removeWhere(
                (word) => PackageRules.normalizeKeyword(word) == oldId,
              );
            }
            if (keywords.isEmpty) {
              await _showPackageSaveError(
                dialogContext,
                'أدخل كلمة طلب واحدة على الأقل للباقة $packageId.',
              );
              return;
            }
            if (!keywords
                .any((word) => word.toLowerCase() == packageId.toLowerCase())) {
              keywords.add(packageId);
            }
            final updated = <String, dynamic>{
              ...existing,
              'id': packageId,
              'price': value,
              'label':
                  label.text.trim().isEmpty ? packageId : label.text.trim(),
              'keywords': keywords,
              'minStock': int.tryParse(minStock.text.trim()) ?? 0,
              'excludedKeywords': _parsePackageKeywords(excludedWords.text),
              'excludedPhones': excludedNumbers.text
                  .split(RegExp(r'[\s,;]+'))
                  .map((value) => value.trim())
                  .where((value) => value.length >= 7)
                  .toSet()
                  .toList(),
            };
            if (itemIndex < 0) {
              items.add(updated);
            } else {
              items[itemIndex] = updated;
            }
            final validationError = PackageRules.validatePackages(
              items,
              allowUnchangedLegacy: _packages(data),
            );
            if (validationError != null) {
              await _showPackageSaveError(dialogContext, validationError);
              return;
            }
            all['schemaVersion'] ??= 1;
            all['packages'] = items;
            try {
              if (oldId != null && oldId != packageId) {
                final stockCount = _list(_inventory(data)[oldId]).length;
                final priorSales = _list(data['transactions'])
                    .map(_map)
                    .where((entry) => '${entry['packageId'] ?? ''}' == oldId)
                    .length;
                final move = await showDialog<bool>(
                  context: dialogContext,
                  builder: (confirmContext) => AlertDialog(
                    title: const Text('تأكيد تغيير سعر ومعرّف الباقة'),
                    content: Text(
                      'سيتغير المعرّف من $oldId إلى $packageId. سينقل التطبيق $stockCount كرتاً غير مباع ويحدّث قوائم السماح. تبقى $priorSales حركة/مبيعات تاريخية بالمعرّف القديم حفاظاً على سجلها؛ لن تتغير قيمها المالية. إذا كان مخزون الوجهة موجوداً وغير فارغ سيرفض التخزين دون الكتابة فوقه.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(confirmContext, false),
                        child: const Text('إلغاء'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(confirmContext, true),
                        child: const Text('تأكيد النقل الآمن'),
                      ),
                    ],
                  ),
                );
                if (move != true) return;
                await NativeApi.instance.updatePackagePrice(
                  oldId,
                  all,
                );
              } else {
                await NativeApi.instance.saveConfig('packages.json', all);
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext, true);
            } catch (e) {
              await _showPackageSaveError(dialogContext, _err(e));
            }
          },
          child: const Text('حفظ'),
        ),
      ],
    ),
  );
  // DialogRoute completes its result before the reverse transition has fully
  // detached TextFields from their controllers.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  label.dispose();
  price.dispose();
  words.dispose();
  minStock.dispose();
  excludedWords.dispose();
  excludedNumbers.dispose();
  if (saved == true) {
    await refresh();
    if (c.mounted) {
      ScaffoldMessenger.of(c).showSnackBar(SnackBar(
          content: Text(oldId == null
              ? 'أُضيفت الباقة وظهرت في المخزون والمشغّل.'
              : 'تم حفظ السعر وكلمات الطلب.')));
    }
  }
}

Future<void> _deletePackage(
  BuildContext c,
  Map<String, dynamic> package,
  int stock,
  Map<String, dynamic> data,
  Future<void> Function() refresh,
) async {
  final id = '${package['id']}';
  final originalPackages = Map<String, dynamic>.from(
    jsonDecode(jsonEncode(_map(data['packages']))) as Map,
  );
  final originalPermissions = Map<String, dynamic>.from(
    jsonDecode(jsonEncode(_map(data['permissions']))) as Map,
  );
  final originalCards =
      _list(_inventory(data)[id]).map((card) => '$card').toList();
  final confirmed = await showDialog<bool>(
    context: c,
    builder: (dialogContext) => AlertDialog(
      title: const Text('حذف الباقة؟'),
      content: Text(
          'سيُحذف تعريف باقة ${package['label'] ?? id} والمعرّف $id، وسيُزال $stock كرتاً غير مباع من مخزونها. تبقى سجلات المبيعات والحركات والأرصدة السابقة كما هي، ويمكن التراجع خلال خمس ثوانٍ.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء')),
        FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف الباقة والمخزون')),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await NativeApi.instance.deletePackage(id);
    await refresh();
    if (c.mounted) {
      ScaffoldMessenger.of(c).showSnackBar(
        SnackBar(
          content: const Text('حُذفت الباقة؛ بقي سجلها المالي محفوظاً.'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'تراجع',
            onPressed: () async {
              try {
                await NativeApi.instance.restoreDeletedPackage(
                  id: id,
                  originalPackages: originalPackages,
                  originalPermissions: originalPermissions,
                  cards: originalCards,
                );
                await refresh();
                if (c.mounted) {
                  ScaffoldMessenger.of(c).showSnackBar(const SnackBar(
                    content: Text('تمت استعادة الباقة ومخزونها وصلاحياتها.'),
                    duration: Duration(seconds: 3),
                  ));
                }
              } catch (error) {
                if (c.mounted) {
                  ScaffoldMessenger.of(c).showSnackBar(SnackBar(
                    content: Text(
                        'تعذر التراجع دون استبدال بيانات أحدث: ${_err(error)}'),
                  ));
                }
              }
            },
          ),
        ),
      );
    }
  } catch (e) {
    if (c.mounted)
      ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(_err(e))));
  }
}

class SaleTile extends StatelessWidget {
  final Map<String, dynamic> sale;
  final VoidCallback? onTap;
  const SaleTile({super.key, required this.sale, this.onTap});
  @override
  Widget build(BuildContext c) => Card(
        child: ListTile(
          onTap: onTap,
          leading: CircleAvatar(
            backgroundColor: emerald.withValues(alpha: .1),
            child: const Icon(Icons.credit_card, color: emerald),
          ),
          title: Text('${sale['phone']} • باقة ${sale['packageId']}'),
          subtitle: Text([
            '${sale['time']} • كرت ${sale['card']}',
            if ('${sale['whatsappStatus'] ?? ''}' == 'failed')
              _whatsappStatusLabel('failed'),
            if ('${sale['whatsappStatus'] ?? ''}' == 'pending')
              _whatsappStatusLabel('pending'),
          ].join(' • ')),
          trailing: Text(
            _money(sale['debt']),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      );
}

class EmptyCard extends StatelessWidget {
  final String text;
  const EmptyCard({super.key, required this.text});
  @override
  Widget build(BuildContext c) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                const Icon(Icons.inbox_outlined, size: 42, color: Colors.grey),
                const SizedBox(height: 8),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
}
