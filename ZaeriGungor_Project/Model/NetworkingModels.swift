@preconcurrency import Alamofire
import Foundation

struct ExternalRecipeDTO: Codable, @unchecked Sendable {
  let idMeal: String?
  let strMeal: String?
  let strMealThumb: String?
  let strInstructions: String?
  let idDrink: String?
  let strDrink: String?
  let strDrinkThumb: String?
}

struct ExternalResponse: Codable, @unchecked Sendable {
  let meals: [[String: String?]]?
  let drinks: [[String: String?]]?
}

struct NinjaRecipe: Codable, @unchecked Sendable {
  let title: String
  let ingredients: String
  let instructions: String
  let servings: String?
  let image: String?
}
