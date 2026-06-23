/// Legado 兼容的源类型枚举
class BookSourceType {
  /// 文本（默认）
  static const int defaultType = 0;

  /// 音频
  static const int audio = 1;

  /// 图片
  static const int image = 2;

  /// 文件下载
  static const int file = 3;

  /// 视频
  static const int video = 4;

  /// RSS订阅
  static const int rss = 5;

  /// 获取类型名称
  static String getName(int type) {
    switch (type) {
      case defaultType:
        return '文本';
      case audio:
        return '音频';
      case image:
        return '图片';
      case file:
        return '文件';
      case video:
        return '视频';
      case rss:
        return 'RSS';
      default:
        return '未知';
    }
  }

  /// 获取类型图标名称（用于序列化）
  static String getIconName(int type) {
    switch (type) {
      case defaultType:
        return 'book';
      case audio:
        return 'music_note';
      case image:
        return 'image';
      case file:
        return 'file_download';
      case video:
        return 'videocam';
      case rss:
        return 'rss_feed';
      default:
        return 'help';
    }
  }

  /// 是否为媒体类型（音频/视频）
  static bool isMediaType(int type) {
    return type == audio || type == video;
  }

  /// 所有类型列表
  static List<int> get allTypes => [defaultType, audio, image, file, video, rss];
}
