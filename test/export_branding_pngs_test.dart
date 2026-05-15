import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('export branding PNGs from SVG (run: flutter test test/export_branding_pngs_test.dart)', () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    const asset = 'assets/svg/logo-visor.svg';
    const outDir = 'assets/png';
    Directory(outDir).createSync(recursive: true);

    Future<void> rasterize(String path, int size) async {
      final info = await vg.loadPicture(const SvgAssetLoader(asset), null);
      try {
        final image = info.picture.toImageSync(size, size);
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          expect(bytes, isNotNull);
          File(path).writeAsBytesSync(
            bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          );
        } finally {
          image.dispose();
        }
      } finally {
        info.picture.dispose();
      }
    }

    await rasterize('$outDir/app_icon.png', 1024);
    await rasterize('$outDir/splash_logo.png', 512);

    expect(File('$outDir/app_icon.png').existsSync(), isTrue);
    expect(File('$outDir/splash_logo.png').existsSync(), isTrue);
  });
}
