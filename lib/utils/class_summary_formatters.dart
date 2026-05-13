/// Same date label as PHP `date('d M Y', strtotime(...))` on the web class summary list.
String formatClassSummaryListDate(String ymd) {
  final parts = ymd.split('-');
  if (parts.length != 3) return ymd;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return ymd;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  if (m < 1 || m > 12) return ymd;
  return '${d.toString().padLeft(2, '0')} ${months[m - 1]} $y';
}
