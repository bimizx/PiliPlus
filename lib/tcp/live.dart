import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:PiliPlus/services/loggeer.dart';
import 'package:brotli/brotli.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

class PackageHeader {
  int totalSize;
  int headerSize;
  int protocolVer;
  int operationCode;
  int seq;

  @override
  String toString() {
    return 'PackageHeader{totalSize: $totalSize, headerSize: $headerSize, protocolVer: $protocolVer, operationCode: $operationCode, seq: $seq}';
  }

  PackageHeader({
    required this.totalSize,
    required this.headerSize,
    required this.protocolVer,
    required this.operationCode,
    required this.seq,
  });

  Uint8List toBytes() {
    final buffer = BytesBuilder()
      ..add(_int32ToBytes(totalSize))
      ..add(_int16ToBytes(headerSize))
      ..add(_int16ToBytes(protocolVer))
      ..add(_int32ToBytes(operationCode))
      ..add(_int32ToBytes(seq));
    return buffer.toBytes();
  }

  List<int> _int32ToBytes(int value) {
    final bytes = ByteData(4)..setInt32(0, value, Endian.big);
    return bytes.buffer.asUint8List();
  }

  List<int> _int16ToBytes(int value) {
    final bytes = ByteData(2)..setInt16(0, value, Endian.big);
    return bytes.buffer.asUint8List();
  }

  static PackageHeader? fromBytesData(Uint8List data) {
    if (data.length < 10) {
      getLogger().i('数据不足以解析PackageHeader');
      return null;
    }
    final byteData = ByteData.sublistView(data);

    int totalSize = byteData.getUint32(0, Endian.big);
    int headerSize = byteData.getUint16(4, Endian.big);
    int protocolVer = byteData.getUint16(6, Endian.big);
    int operationCode = byteData.getUint32(8, Endian.big);
    int seq = byteData.getUint32(12, Endian.big);

    return PackageHeader(
      totalSize: totalSize,
      headerSize: headerSize,
      protocolVer: protocolVer,
      operationCode: operationCode,
      seq: seq,
    );
  }
}

abstract class Message {
  String toJsonStr();
  int getMessageSize();
}

class AuthMessage implements Message {
  int roomid;
  int uid;
  int protover;
  String platform;
  int type;
  String key;

  AuthMessage({
    required this.roomid,
    required this.uid,
    required this.protover,
    required this.platform,
    required this.type,
    required this.key,
  });

  @override
  String toJsonStr() {
    final message = {
      'roomid': roomid,
      'uid': uid,
      'protover': protover,
      'platform': platform,
      'type': type,
      'key': key,
    };
    return jsonEncode(message);
  }

  @override
  int getMessageSize() {
    return utf8.encode(toJsonStr()).length;
  }
}

abstract class AbstractPackage<T> {
  PackageHeader header;
  T body;
  Uint8List marshal();
  AbstractPackage({required this.header, required this.body});
}

//认证包
class AuthPackage extends AbstractPackage<Message> {
  AuthPackage({required super.header, required super.body});

  @override
  Uint8List marshal() {
    int size = body.getMessageSize();
    header.headerSize = 0x10; // 固定大小
    size += header.headerSize;
    header.totalSize = size;
    final buffer = BytesBuilder()
      ..add(header.toBytes())
      ..add(utf8.encode(body.toJsonStr()));
    return buffer.toBytes();
  }
}

//心跳包
class HeartbeatPackage extends AbstractPackage<dynamic> {
  HeartbeatPackage({required super.header, super.body});

  @override
  Uint8List marshal() {
    final buffer = BytesBuilder();
    header
      ..headerSize = 0x10
      ..totalSize = 0x10;
    buffer.add(header.toBytes());
    return buffer.toBytes();
  }
}

class LiveMessageStream {
  String streamToken;
  int roomId, uid;
  List<String> servers;
  List<void Function(dynamic obj)> eventListeners = [];
  LiveMessageStream({
    required this.streamToken,
    required this.roomId,
    required this.uid,
    required this.servers,
  });

  WebSocket? socket;
  StreamSubscription? _socketSubscription;
  bool heartBeat = true;
  PiliLogger logger = getLogger();
  final String logTag = "LiveStreamService";

  Future<void> init() async {
    final authPackage = AuthPackage(
      header: PackageHeader(
        totalSize: 0,
        headerSize: 0,
        protocolVer: 1,
        operationCode: 7,
        seq: 1,
      ),
      body: AuthMessage(
        roomid: roomId,
        uid: uid,
        protover: 3,
        platform: 'web',
        type: 2,
        key: streamToken,
      ),
    );

    // final marshaledData = authPackage.marshal();
    // logger.d(marshaledData);
    try {
      Future<WebSocket> getSocket() async {
        for (final server in servers) {
          try {
            return WebSocket.connect(server);
          } catch (_) {}
        }
        throw Exception("all servers connect failed");
      }

      socket = await getSocket();
      // logger
      //   ..d('$logTag ===> TCP连接建立')
      //   ..d('$logTag ===> 发送认证包');
      _socketSubscription = socket?.listen(
        (data) {
          PackageHeader? header = PackageHeader.fromBytesData(data);
          if (header != null) {
            List<int> decompressedData = [];
            //心跳包回复不用处理
            if (header.operationCode == 3) return;
            if (header.operationCode == 8) {
              _heartBeat();
            }
            try {
              switch (header.protocolVer) {
                case 0:
                case 1:
                  _processingData(data);
                  return;
                case 2:
                  decompressedData = ZLibDecoder().convert(data.sublist(0x10));
                  break;
                case 3:
                  decompressedData = const BrotliDecoder().convert(
                    data.sublist(0x10),
                  );
                //debugPrint('Body: ${utf8.decode()}');
              }
              _processingData(decompressedData);
            } catch (e) {
              logger.i(e);
            }
          }
        },
      );
      socket?.add(authPackage.marshal());
    } catch (e) {
      SmartDialog.showToast("弹幕地址链接失败");
      // logger.i('$logTag ===> TCP连接失败: $e');
    }
  }

  void _processingData(List<int> data) {
    try {
      PackageHeader? subHeader = PackageHeader.fromBytesData(
        Uint8List.fromList(data),
      );
      if (subHeader != null) {
        var msgBody = utf8.decode(
          data.sublist(subHeader.headerSize, subHeader.totalSize),
        );
        for (var f in eventListeners) {
          f(jsonDecode(msgBody));
        }
        if (subHeader.totalSize < data.length) {
          _processingData(data.sublist(subHeader.totalSize));
        }
      }
    } catch (e) {
      logger.i('ParseHeader错误: $e');
    }
  }

  Future<void> _heartBeat() async {
    logger.i("$logTag 直播间信息流认证成功");
    int heartBeatCount = 1;
    while (heartBeat) {
      await Future.delayed(const Duration(seconds: 30));
      //发送心跳包
      var package = HeartbeatPackage(
        header: PackageHeader(
          totalSize: 0,
          headerSize: 0,
          protocolVer: 1,
          operationCode: 2,
          seq: heartBeatCount,
        ),
      );
      try {
        socket?.add(package.marshal());
      } catch (_) {}
      heartBeatCount++;
    }
  }

  void addEventListener(void Function(dynamic) func) {
    eventListeners.add(func);
  }

  void close() {
    heartBeat = false;
    eventListeners.clear();
    _socketSubscription?.cancel();
    socket?.close();
  }
}
