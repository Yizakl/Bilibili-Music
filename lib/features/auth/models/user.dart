class User {
  final String id;
  final String username;
  final String? nickname;
  final String? avatar;
  final int? level;
  final String? token;
  final bool isVip;

  User({
    required this.id,
    required this.username,
    this.nickname,
    this.avatar,
    this.level,
    this.token,
    this.isVip = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      nickname: json['nickname'] as String?,
      avatar: json['avatar'] as String?,
      level: json['level'] as int?,
      token: json['token'] as String?,
      isVip: json['isVip'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'nickname': nickname,
      'avatar': avatar,
      'level': level,
      'token': token,
      'isVip': isVip,
    };
  }

  User copyWith({
    String? id,
    String? username,
    String? nickname,
    String? avatar,
    int? level,
    String? token,
    bool? isVip,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      nickname: nickname ?? this.nickname,
      avatar: avatar ?? this.avatar,
      level: level ?? this.level,
      token: token ?? this.token,
      isVip: isVip ?? this.isVip,
    );
  }
}
