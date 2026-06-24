/// Pet Collar Service UUIDs. Base: A1B2C3D4-xxxx-1000-8000-00805F9B34FB
class PcsUuids {
  static String _u(String x) => 'a1b2c3d4-$x-1000-8000-00805f9b34fb';

  static final String service = _u('0000');
  static final String location = _u('0101');
  static final String health = _u('0102');
  static final String behavior = _u('0103');
  static final String command = _u('0104');
  static final String status = _u('0105');
  static final String config = _u('0106');
}
