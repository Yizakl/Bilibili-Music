class User {
  final String id;
  final String username;
  final String nickname;
  final String avatar;
  final int level;
  final bool isVip;

  // B站特有字段
  final String? mid; // B站用户ID
  final String? uname; // B站用户名
  final String? face; // B站头像
  final int? coins; // B站硬币数
  final int? vipType; // 会员类型
  final int? vipStatus; // 会员状态
  final int? follower; // 粉丝数
  final int? following; // 关注数

  User({
    required this.id,
    required this.username,
    required this.nickname,
    required this.avatar,
    required this.level,
    required this.isVip,
    this.mid,
    this.uname,
    this.face,
    this.coins,
    this.vipType,
    this.vipStatus,
    this.follower,
    this.following,
  });

  bool get hasAvatar => avatar.isNotEmpty;

  // 从JSON创建User对象
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['mid']?.toString() ?? json['id']?.toString() ?? '',
      username: json['uname'] ?? json['username'] ?? '',
      nickname: json['nickname'] ?? '',
      avatar: json['face'] ?? json['avatar'] ?? '',
      level: json['level_info']?['current_level'] ?? json['level'] ?? 0,
      isVip: json['vipStatus'] == 1 || json['isVip'] == true,
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'nickname': nickname,
      'avatar': avatar,
      'level': level,
      'isVip': isVip,
    };
  }

  // 创建用户副本
  User copyWith({
    String? id,
    String? username,
    String? nickname,
    String? avatar,
    int? level,
    bool? isVip,
    String? mid,
    String? uname,
    String? face,
    int? coins,
    int? vipType,
    int? vipStatus,
    int? follower,
    int? following,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      nickname: nickname ?? this.nickname,
      avatar: avatar ?? this.avatar,
      level: level ?? this.level,
      isVip: isVip ?? this.isVip,
      mid: mid ?? this.mid,
      uname: uname ?? this.uname,
      face: face ?? this.face,
      coins: coins ?? this.coins,
      vipType: vipType ?? this.vipType,
      vipStatus: vipStatus ?? this.vipStatus,
      follower: follower ?? this.follower,
      following: following ?? this.following,
    );
  }

  // 添加toMap方法，用于与其他API交互
  Map<String, dynamic> toMap() {
    return toJson();
  }
}
