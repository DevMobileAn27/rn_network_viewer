import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Public pairing default shared with the SDK; not a private secret.
const defaultViewerToken = 'rnv_default_pairing_token_for_local_dev_001';

String createAccessToken() {
  final random = Random.secure();
  return base64Url
      .encode(List.generate(32, (_) => random.nextInt(256)))
      .replaceAll('=', '');
}

bool validAccessToken(String value) =>
    RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(value);

bool matchesBearer(String? header, String token) {
  final expected = 'Bearer $token';
  if (header == null || header.length != expected.length) return false;
  var difference = 0;
  for (var i = 0; i < expected.length; i++) {
    difference |= header.codeUnitAt(i) ^ expected.codeUnitAt(i);
  }
  return difference == 0;
}

bool privateIPv4(InternetAddress address) {
  if (address.type != InternetAddressType.IPv4) return false;
  final b = address.rawAddress;
  return b[0] == 10 ||
      (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
      (b[0] == 192 && b[1] == 168);
}

/// Explicit IPv4 CIDR, never inferred from a /24 assumption.
class LanSubnet {
  LanSubnet(String cidr) {
    final parts = cidr.trim().split('/');
    final address = InternetAddress.tryParse(parts.first);
    final prefix = parts.length == 2 ? int.tryParse(parts[1]) : null;
    if (address == null ||
        !privateIPv4(address) ||
        prefix == null ||
        prefix < 8 ||
        prefix > 32) {
      throw const FormatException(
        'Enter a private IPv4 subnet, e.g. 192.168.1.0/24.',
      );
    }
    mask = (0xffffffff << (32 - prefix)) & 0xffffffff;
    network = _number(address) & mask;
    // The entire range must stay within one RFC1918 block.
    if (!privateIPv4(_address(network)) ||
        !privateIPv4(_address(network | (~mask & 0xffffffff)))) {
      throw const FormatException(
        'Subnet must be entirely inside a private IPv4 range.',
      );
    }
  }
  late final int mask;
  late final int network;
  bool contains(InternetAddress address) =>
      privateIPv4(address) && (_number(address) & mask) == network;
  static int _number(InternetAddress a) =>
      a.rawAddress.fold(0, (v, b) => (v << 8) | b);
  static InternetAddress _address(int n) => InternetAddress(
    '${n >> 24 & 255}.${n >> 16 & 255}.${n >> 8 & 255}.${n & 255}',
  );
}
