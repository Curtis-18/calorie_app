/// A barcode as USDA knows it: digits only, 8 to 14 long (EAN-8, UPC-A,
/// EAN-13, GTIN-14). Null for anything else, so a misread or a typo is
/// caught before a request is made. The server checks the same rule.
String? normalizeBarcode(String raw) {
  final code = raw.trim();
  if (!RegExp(r'^[0-9]{8,14}$').hasMatch(code)) return null;
  return code;
}
