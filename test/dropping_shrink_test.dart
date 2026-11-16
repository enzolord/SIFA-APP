import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sifa/services/dropping_check.dart';

void main() {
  test('une grande photo est réduite à 640 px de large', () {
    final big = Uint8List.fromList(img.encodeJpg(img.Image(width: 1280, height: 960), quality: 90));
    final small = DroppingCheck.shrink(big);
    expect(img.decodeJpg(small)!.width, DroppingCheck.sendWidth);
    expect(small.length, lessThan(big.length));
  });

  test('une petite photo ou un fichier illisible reste tel quel', () {
    final tiny = Uint8List.fromList(img.encodeJpg(img.Image(width: 300, height: 200)));
    expect(DroppingCheck.shrink(tiny), tiny);
    final junk = Uint8List.fromList([1, 2, 3]);
    expect(DroppingCheck.shrink(junk), junk);
  });
}
