import 'dart:io';

import 'package:flutter_app_packager/src/makers/msix/make_msix_config.dart';
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
    } finally {
      Directory.current = originalDirectory;
      testDirectory.deleteSync(recursive: true);
    }
  });
}
