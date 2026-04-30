// models/channel.dart
class Channel {
  final int id;
  final String channelName;
  final String groupName;
  final String logoUrl;
  final String streamUrl;
  final String source;

  Channel({
    required this.id,
    required this.channelName,
    required this.groupName,
    required this.logoUrl,
    required this.streamUrl,
    required this.source,
  });

  factory Channel.fromJson(Map<String, dynamic> j) => Channel(
        id          : j['id'] ?? 0,
        channelName : j['channel_name'] ?? '',
        groupName   : j['group_name'] ?? 'OTHERS',
        logoUrl     : j['logo_url'] ?? '',
        streamUrl   : j['stream_url'] ?? '',
        source      : j['source'] ?? '',
      );
}
