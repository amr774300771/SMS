import 'package:intl/intl.dart' as intl;

Map<String, dynamic> asReportMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> reportList(dynamic value) => value is List
    ? value.map(asReportMap).toList()
    : <Map<String, dynamic>>[];

DateTime? reportDate(dynamic value) {
  final raw = '$value'.trim();
  if (raw.isEmpty || raw == 'null') return null;
  return DateTime.tryParse(raw);
}

bool isInReportPeriod(dynamic value, int days, {DateTime? now}) {
  if (days == 0) return true;
  final date = reportDate(value);
  if (date == null) return false;
  final end = now ?? DateTime.now();
  final start = DateTime(end.year, end.month, end.day)
      .subtract(Duration(days: days - 1));
  return !date.isBefore(start);
}

int reportAmount(Map<String, dynamic> sale) {
  final value = sale['price'];
  return value is num ? value.toInt() : int.tryParse('${sale['packageId']}') ?? 0;
}

Map<String, int> salesByPackage(List<Map<String, dynamic>> sales) {
  final result = <String, int>{};
  for (final sale in sales) {
    final key = '${sale['packageId'] ?? 'غير محدد'}';
    result[key] = (result[key] ?? 0) + 1;
  }
  return result;
}

String buildSalesCsv(List<Map<String, dynamic>> sales) {
  final rows = <List<String>>[
    ['التاريخ', 'الباقة', 'العميل', 'الهاتف', 'المبلغ', 'نوع الدفع'],
    ...sales.map((sale) => [
          '${sale['time'] ?? ''}',
          '${sale['packageId'] ?? ''}',
          '${sale['clientName'] ?? ''}',
          '${sale['phone'] ?? ''}',
          '${reportAmount(sale)}',
          '${sale['paymentMethod'] ?? (sale['cash'] == true ? 'نقدي' : 'آجل')}',
        ]),
  ];
  String escape(String value) => '"${value.replaceAll('"', '""')}"';
  return rows.map((row) => row.map(escape).join(',')).join('\n');
}

String reportPeriodLabel(int days) => switch (days) {
      1 => 'اليوم',
      7 => 'آخر 7 أيام',
      30 => 'آخر 30 يوماً',
      _ => 'كل الفترة',
    };

String formatReportDate(dynamic value) {
  final date = reportDate(value);
  return date == null ? 'غير مؤرخ' : intl.DateFormat('yyyy/MM/dd').format(date);
}
