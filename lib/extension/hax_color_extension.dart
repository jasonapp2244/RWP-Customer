import 'dart:ui';


//Modified By Nouman

extension HexColor on Color {
  /// String is in the format "aabbcc" or "ffaabbcc" with an optional leading "#".
  static Color fromHex(String hexString) {
    // Validate input
    if (hexString.isEmpty || hexString == 'null') {
      return Color(0xFF000000); // Return default black color
    }
    
    final buffer = StringBuffer();
    String cleanedHex = hexString.replaceFirst('#', '');
    
    // Validate hex string format
    if (!RegExp(r'^[0-9A-Fa-f]{6,8}$').hasMatch(cleanedHex)) {
      print('Invalid hex color format: $hexString');
      return Color(0xFF000000); // Return default color
    }
    
    if (cleanedHex.length == 6) {
      buffer.write('ff'); // Add alpha if missing
    }
    buffer.write(cleanedHex);
    
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      print('Error parsing hex color $hexString: $e');
      return Color(0xFF000000); // Return default color
    }
  }

  /// Prefixes a hash sign if [leadingHashSign] is set to `true` (default is `true`).
  String toHex({bool leadingHashSign = true}) => '${leadingHashSign ? '#' : ''}'
      '${alpha.toRadixString(16).padLeft(2, '0')}'
      '${red.toRadixString(16).padLeft(2, '0')}'
      '${green.toRadixString(16).padLeft(2, '0')}'
      '${blue.toRadixString(16).padLeft(2, '0')}';
}













// // ignore_for_file: deprecated_member_use

// import 'dart:ui';

// extension HexColor on Color {
//   /// String is in the format "aabbcc" or "ffaabbcc" with an optional leading "#".
//   static Color fromHex(String hexString) {
//     final buffer = StringBuffer();
//     if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
//     buffer.write(hexString.replaceFirst('#', ''));
//     return Color(int.parse(buffer.toString(), radix: 16));
//   }

//   /// Prefixes a hash sign if [leadingHashSign] is set to `true` (default is `true`).
//   String toHex({bool leadingHashSign = true}) => '${leadingHashSign ? '#' : ''}'
//       '${alpha.toRadixString(16).padLeft(2, '0')}'
//       '${red.toRadixString(16).padLeft(2, '0')}'
//       '${green.toRadixString(16).padLeft(2, '0')}'
//       '${blue.toRadixString(16).padLeft(2, '0')}';
// }
