// Patrón móvil de México de libphonenumber v9.0.44 (Apache-2.0).
final _mobile = RegExp(
  r'^(?:2(?:2\d|3[1-35-8]|4[13-9]|7[1-689]|8[1-578]|9[467])|'
  r'3(?:1[1-79]|[2458][1-9]|3\d|7[1-8]|9[1-5])|'
  r'4(?:1[1-57-9]|[267][1-9]|3[1-8]|[45]\d|8[1-35-9]|9[2-689])|'
  r'5(?:[56]\d|88|9[1-79])|'
  r'6(?:1[2-68]|[2-4][1-9]|5[1-36-9]|6[0-57-9]|7[1-7]|8[67]|9[4-8])|'
  r'7(?:[1346][1-9]|[27]\d|5[13-9]|8[1-69]|9[17])|'
  r'8(?:1\d|2[13-689]|3[1-6]|4[124-6]|6[1246-9]|7[0-378]|9[12479])|'
  r'9(?:1[346-9]|2[1-4]|3[2-46-8]|5[1348]|[69]\d|7[12]|8[1-8]))\d{7}$',
);
final _displaySeparators = RegExp(r'[\s().\-]');

String? phoneKey(String raw) {
  final digits = raw.trim().replaceAll(_displaySeparators, '');
  final national = switch (digits) {
    String s when s.startsWith('+52') => s.substring(3),
    String s when s.length == 12 && s.startsWith('52') => s.substring(2),
    _ => digits,
  };
  return _mobile.hasMatch(national) ? '52$national' : null;
}
