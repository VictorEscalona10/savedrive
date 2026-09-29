/// Utilidades de sanitización y validación de entradas de usuario
abstract final class InputSanitizer {
  static String sanitizeName(String input) {
    var cleaned = input.trim();
    cleaned = cleaned.replaceAll(RegExp(r'[<>"/\\;%()={}\$\^\*\[\]]'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.length > 70) {
      cleaned = cleaned.substring(0, 70);
    }
    return cleaned;
  }

  static String sanitizePhone(String input) {
    var cleaned = input.trim();
    cleaned = cleaned.replaceAll(RegExp(r'[^0-9+\-\s()]'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.length > 25) {
      cleaned = cleaned.substring(0, 25);
    }
    return cleaned;
  }

  static String sanitizeNotes(String input) {
    var cleaned = input.trim();
    cleaned = cleaned.replaceAll(RegExp(r'[<>"/\\;{}\$\^]'), '');
    if (cleaned.length > 500) {
      cleaned = cleaned.substring(0, 500);
    }
    return cleaned;
  }

  static bool isValidEmail(String email) {
    return RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email.trim());
  }

  static bool isValidPhoneDigits(String phone) {
    final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return digitsOnly.length >= 7 && digitsOnly.length <= 16;
  }

  static bool isValidName(String name) {
    return name.trim().length >= 2;
  }
}
