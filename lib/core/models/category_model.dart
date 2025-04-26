class CategoryModel {
  final int id;
  final String name;
  final String icon;
  final List<SubCategory> subCategories;

  CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    this.subCategories = const [],
  });

  // 获取所有分区
  static List<CategoryModel> getAllCategories() {
    return [
      CategoryModel(
        id: 1,
        name: '音乐',
        icon: '🎵',
        subCategories: [
          SubCategory(id: 101, name: '原创音乐'),
          SubCategory(id: 102, name: '翻唱'),
          SubCategory(id: 103, name: '演奏'),
          SubCategory(id: 104, name: 'VOCALOID'),
        ],
      ),
      CategoryModel(
        id: 2,
        name: '舞蹈',
        icon: '💃',
        subCategories: [
          SubCategory(id: 201, name: '宅舞'),
          SubCategory(id: 202, name: '街舞'),
          SubCategory(id: 203, name: '明星舞蹈'),
        ],
      ),
      CategoryModel(
        id: 3,
        name: '游戏',
        icon: '🎮',
        subCategories: [
          SubCategory(id: 301, name: '单机游戏'),
          SubCategory(id: 302, name: '电子竞技'),
          SubCategory(id: 303, name: '手机游戏'),
        ],
      ),
      CategoryModel(
        id: 4,
        name: '动画',
        icon: '🎬',
        subCategories: [
          SubCategory(id: 401, name: 'MAD·AMV'),
          SubCategory(id: 402, name: 'MMD·3D'),
          SubCategory(id: 403, name: '短片·手书'),
        ],
      ),
      CategoryModel(
        id: 5,
        name: '娱乐',
        icon: '🎭',
        subCategories: [
          SubCategory(id: 501, name: '搞笑'),
          SubCategory(id: 502, name: '明星'),
          SubCategory(id: 503, name: '综艺'),
        ],
      ),
    ];
  }
}

class SubCategory {
  final int id;
  final String name;

  SubCategory({
    required this.id,
    required this.name,
  });
} 