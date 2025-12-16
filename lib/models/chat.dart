class Chat {
  final String id;
  final String userId;
  final String userName;
  final String userRole;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final bool isOnline;

  Chat({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userRole,
    this.lastMessage,
    this.lastMessageTime,
    this.isOnline = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userRole': userRole,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.millisecondsSinceEpoch,
      'isOnline': isOnline,
    };
  }

  factory Chat.fromMap(Map<String, dynamic> map) {
    return Chat(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userRole: map['userRole'] ?? '',
      lastMessage: map['lastMessage'],
      lastMessageTime: map['lastMessageTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastMessageTime'])
          : null,
      isOnline: map['isOnline'] ?? false,
    );
  }
}
