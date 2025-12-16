import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'es': {
      'app_title': 'Nutri',
      'app_subtitle': 'Ecuador - Portal de Empleados',
      'login': 'Iniciar Sesión',
      'register': 'Registrarse',
      'username': 'Usuario',
      'password': 'Contraseña',
      'eventos': 'Eventos',
      'notificaciones': 'Notificaciones',
      'chat': 'Chat',
      'recursos': 'Recursos',
      'logout': 'Cerrar Sesión',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['es'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
