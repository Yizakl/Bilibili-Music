import 'package:flutter/material.dart';

class AppLicensePage extends StatelessWidget {
  final String applicationName;
  final String applicationVersion;
  final String applicationLegalese;

  const AppLicensePage({
    super.key,
    required this.applicationName,
    required this.applicationVersion,
    required this.applicationLegalese,
  });

  @override
  Widget build(BuildContext context) {
    return LicensePage(
      applicationName: applicationName,
      applicationVersion: applicationVersion,
      applicationLegalese: applicationLegalese,
    );
  }
}
