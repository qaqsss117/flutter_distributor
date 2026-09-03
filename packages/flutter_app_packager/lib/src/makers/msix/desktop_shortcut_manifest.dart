import 'dart:io';

import 'package:xml/xml.dart';

const _desktop7Namespace =
    'http://schemas.microsoft.com/appx/manifest/desktop/windows10/7';

Future<void> addDesktopShortcutToManifest(
  File manifestFile, {
  required String shortcutName,
}) async {
  final document = XmlDocument.parse(await manifestFile.readAsString());
  final package = document.rootElement;
  final applications = package.findElements('Applications').single;
  final application = applications.findElements('Application').single;
  final executable = application.getAttribute('Executable');
  if (executable == null || executable.isEmpty) {
    throw const FormatException('MSIX application executable is missing');
  }

  final normalizedName = shortcutName.toLowerCase().endsWith('.lnk')
      ? shortcutName
      : '$shortcutName.lnk';
  final shortcutPath = r'$(Desktop)\' + normalizedName;
  if (shortcutPath.length > 256 ||
      RegExp(r'[<>:"/\\|?*]').hasMatch(shortcutName)) {
    throw FormatException('Invalid MSIX desktop shortcut name: $shortcutName');
  }

  if (package.getAttribute('xmlns:desktop7') == null) {
    package.setAttribute(
      'xmlns:desktop7',
      _desktop7Namespace,
    );
  }

  final ignorableNamespaces =
      package.getAttribute('IgnorableNamespaces')?.split(' ') ?? <String>[];
  if (!ignorableNamespaces.contains('desktop7')) {
    ignorableNamespaces.add('desktop7');
    package.setAttribute(
      'IgnorableNamespaces',
      ignorableNamespaces.where((item) => item.isNotEmpty).join(' '),
    );
  }

  final existingExtensions = application.findElements('Extensions');
  final extensions = existingExtensions.isEmpty
      ? XmlElement(XmlName('Extensions'))
      : existingExtensions.single;
  if (existingExtensions.isEmpty) {
    application.children.add(extensions);
  }

  extensions.children.add(
    XmlElement(
      XmlName('Extension', 'desktop7'),
      [
        XmlAttribute(XmlName('Category'), 'windows.shortcut'),
        XmlAttribute(XmlName('Executable'), executable),
        XmlAttribute(
          XmlName('EntryPoint'),
          'Windows.FullTrustApplication',
        ),
      ],
      [
        XmlElement(
          XmlName('Shortcut', 'desktop7'),
          [
            XmlAttribute(XmlName('File'), shortcutPath),
            XmlAttribute(XmlName('Icon'), executable),
            XmlAttribute(XmlName('Description'), shortcutName),
          ],
        ),
      ],
    ),
  );

  await manifestFile.writeAsString(document.toXmlString(pretty: true));
}
