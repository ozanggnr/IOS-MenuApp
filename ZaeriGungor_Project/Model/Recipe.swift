@preconcurrency import Alamofire
import CoreData
import Foundation

@objc(Recipe)
class Recipe: NSManagedObject {
  @NSManaged var id: String
  @NSManaged var titleText: String
  @NSManaged var summaryText: String?
  @NSManaged var category: String?
  @NSManaged var ingredients: String?
  @NSManaged var steps: String?
  @NSManaged var imageName: String?
  @NSManaged var difficulty: String?
  @NSManaged var duration: Int16
  @NSManaged var isFavorite: Bool
  @NSManaged var createdAt: Date?
  @NSManaged var lastCookedAt: Date?
}

extension Recipe {
  @nonobjc public class func fetchRequest() -> NSFetchRequest<Recipe> {
    NSFetchRequest<Recipe>(entityName: "Recipe")
  }

  var ingredientsList: [String] {
    (ingredients ?? "")
      .split(separator: "\n")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { $0.isEmpty == false }
  }

  var stepsList: [String] {
    (steps ?? "")
      .split(separator: "\n")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { $0.isEmpty == false }
  }
}
