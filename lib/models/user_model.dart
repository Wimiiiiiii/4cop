class UserModel {
  final String uid;
  String name;
  String email;
  String? photoUrl;
  String? bio;
  String? phone;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    this.bio,
    this.phone,
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String id) {
    return UserModel(
      uid: id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      photoUrl: data['photoUrl'],
      bio: data['bio'],
      phone: data['phone'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'bio': bio,
      'phone': phone,
    };
  }
}