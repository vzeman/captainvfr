import 'package:hive/hive.dart';

/// Adapter to store Dart [Duration] in Hive.
class DurationAdapter extends TypeAdapter<Duration> {
  @override
  final int typeId = 27;

  @override
  Duration read(BinaryReader reader) {
    final millis = reader.readInt();
    return Duration(milliseconds: millis);
  }

  @override
  void write(BinaryWriter writer, Duration obj) {
    writer.writeInt(obj.inMilliseconds);
  }
}
