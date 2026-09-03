import 'dart:io';

import 'package:flutter_app_packager/src/makers/msix/desktop_shortcut_manifest.dart';
import 'package:flutter_app_packager/src/makers/msix/make_msix_config.dart';
import 'package:xml/xml.dart';
import 'package:test/test.dart';

void main() {
  test('private Store identity overrides the public MSIX configuration', () {
    final originalDirectory = Directory.current;
    final testDirectory = Directory.systemTemp.createTempSync(
      'sentinel_msix_identity_',
    );

    try {
      Directory.current = testDirectory;
      Directory('windows/packaging/msix').createSync(recursive: true);
      Directory('signing/windows').createSync(recursive: true);
      File('windows/packaging/msix/make_config.yaml').writeAsStringSync('''
publisher_display_name: Public Placeholder
identity_name: Public.Placeholder
architecture: x64
desktop_shortcut_name: Sentinel
''');
      File('signing/windows/store_identity.yaml').writeAsStringSync('''
publisher_display_name: Store Publisher
identity_name: Store.Identity.Name
publisher: CN=STORE-PUBLISHER-ID
store: "true"
sign_msix: "false"
install_certificate: "false"
''');

      final loader = MakeMsixConfigLoader()
        ..platform = 'windows'
        ..packageFormat = 'msix';
      final config = loader.load(
        {'build_mode': 'release'},
        Directory('dist'),
        buildOutputDirectory: Directory('build/windows/x64/runner/Release'),
        buildOutputFiles: const [],
      ) as MakeMsixConfig;

      expect(config.publisher_display_name, 'Store Publisher');
      expect(config.identity_name, 'Store.Identity.Name');
      expect(config.publisher, 'CN=STORE-PUBLISHER-ID');
      expect(config.store, 'true');
      expect(config.sign_msix, 'false');
      expect(config.install_certificate, 'false');
      expect(config.architecture, 'x64');
      expect(config.desktop_shortcut_name, 'Sentinel');
    } finally {
      Directory.current = originalDirectory;
      testDirectory.deleteSync(recursive: true);
    }
  });

  test('adds the official desktop7 shortcut extension to the application',
      () async {
    final testDirectory = Directory.systemTemp.createTempSync(
      'sentinel_msix_shortcut_',
    );
    final manifestFile = File('${testDirectory.path}/AppxManifest.xml');

    try {
      manifestFile.writeAsStringSync('''<?xml version="1.0" encoding="utf-8"?>
<Package xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10"
    xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10"
    IgnorableNamespaces="uap">
  <Applications>
    <Application Id="Sentinel" Executable="SentinelVPN.exe" EntryPoint="Windows.FullTrustApplication">
      <uap:VisualElements DisplayName="Sentinel" />
    </Application>
  </Applications>
</Package>''');

      await addDesktopShortcutToManifest(
        manifestFile,
        shortcutName: '哨兵加速器',
      );

      final document = XmlDocument.parse(manifestFile.readAsStringSync());
      final package = document.rootElement;
      final application = package
          .findElements('Applications')
          .single
          .findElements('Application')
          .single;
      final extensions = application.findElements('Extensions').single;
      final extension = extensions.children.whereType<XmlElement>().singleWhere(
          (element) => element.name.qualified == 'desktop7:Extension');
      final shortcut = extension.children.whereType<XmlElement>().single;

      expect(
        package.getAttribute('xmlns:desktop7'),
        'http://schemas.microsoft.com/appx/manifest/desktop/windows10/7',
      );
      expect(package.getAttribute('IgnorableNamespaces'), 'uap desktop7');
      expect(extension.getAttribute('Category'), 'windows.shortcut');
      expect(extension.getAttribute('Executable'), 'SentinelVPN.exe');
      expect(shortcut.name.qualified, 'desktop7:Shortcut');
      expect(shortcut.getAttribute('File'), r'$(Desktop)\哨兵加速器.lnk');
      expect(shortcut.getAttribute('Icon'), 'SentinelVPN.exe');
    } finally {
      testDirectory.deleteSync(recursive: true);
    }
  });
}
