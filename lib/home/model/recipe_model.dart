// lib/home/model/recipe_model.dart
class Recipe {
  final String recipeName;
  final String imageUrl;
  final Map<String, dynamic> rawData;
  // rawData: 나머지 필드를 보관 (예: 'ATT_FILE_NO_MAIN', 'RCP_NM' 등)

  Recipe({
    required this.recipeName,
    required this.imageUrl,
    required this.rawData,
  });

  // JSON에서 직접 parse (원본 코드에선 dynamic 사용)
  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      recipeName: json["RCP_NM"] ?? "No Name",
      imageUrl: json["ATT_FILE_NO_MAIN"] ?? "",
      rawData: json,
    );
  }
}
