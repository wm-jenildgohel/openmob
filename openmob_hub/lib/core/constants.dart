class ApiConstants {
  static const int port = 8686;
  static const String apiPrefix = '/api/v1';
}

class AdbKeyCodes {
  static const int home = 3;
  static const int back = 4;
  static const int call = 5;
  static const int endCall = 6;
  static const int volumeUp = 24;
  static const int volumeDown = 25;
  static const int power = 26;
  static const int camera = 27;
  static const int enter = 66;
  static const int backspace = 67;
  static const int delete = 112;
  static const int menu = 82;
  static const int search = 84;
  static const int tab = 61;
  static const int escape = 111;
  static const int recentApps = 187;
  static const int mute = 164;
}

class AdbDefaults {
  static const Duration commandTimeout = Duration(seconds: 10);
  static const Duration screenshotTimeout = Duration(seconds: 15);
  static const int wifiAdbPort = 5555;
  static const Duration pollInterval = Duration(seconds: 5);
}
