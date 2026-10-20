/// Pemformat tanggal & waktu yang meniru `src/lib/utils.ts` di web.
///
/// Web memformat dengan
/// `Intl.DateTimeFormat("id-ID", { day: "numeric", month: "short",
/// year: "numeric", hour: "2-digit", minute: "2-digit" })`.
/// Paket `intl` sengaja tidak ditambahkan, jadi hasilnya direplikasi manual.
/// Locale `id-ID` memakai TITIK sebagai pemisah jam, contoh:
/// `06 Okt 2026, 10.30`.
library;

/// Nama bulan pendek Indonesia (urutan 1-12).
const List<String> _bulanPendekId = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

/// Tanggal + jam: `06 Okt 2026, 10.30`.
///
/// Mengembalikan `-` bila [date] null (tanggal dari server tidak bisa diparse)
/// — sama seperti `formatDate` di web.
String formatDateTimeId(DateTime? date) {
  if (date == null) return '-';
  final day = date.day.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day ${_bulanPendekId[date.month - 1]} ${date.year}, $hour.$minute';
}

/// Tanggal saja: `06 Okt 2026` (padanan `formatDateShort` di web).
String formatDateId(DateTime? date) {
  if (date == null) return '-';
  final day = date.day.toString().padLeft(2, '0');
  return '$day ${_bulanPendekId[date.month - 1]} ${date.year}';
}
