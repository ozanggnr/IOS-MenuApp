@preconcurrency import Alamofire
import Foundation

final class RecipeAPIService {
  static let shared = RecipeAPIService()
  private init() {}

  func fetchBreakfast(completion: @escaping ([NinjaRecipe]) -> Void) {
    fetchCategory(
      url: "https://www.themealdb.com/api/json/v1/1/filter.php?c=Breakfast", type: .meal, limit: 5,
      completion: completion)
  }

  func fetchLunch(completion: @escaping ([NinjaRecipe]) -> Void) {
    fetchCategory(
      url: "https://www.themealdb.com/api/json/v1/1/filter.php?c=Chicken", type: .meal, limit: 5,
      completion: completion)
  }

  func fetchDrinks(completion: @escaping ([NinjaRecipe]) -> Void) {
    fetchCategory(
      url: "https://www.thecocktaildb.com/api/json/v1/1/filter.php?c=Cocktail", type: .drink,
      limit: 5, completion: completion)
  }

  private enum ApiType { case meal, drink }

  private func fetchCategory(
    url: String, type: ApiType, limit: Int, completion: @escaping ([NinjaRecipe]) -> Void
  ) {
    AF.request(url).responseDecodable(of: ExternalResponse.self) { [weak self] response in
      guard let self = self else {
        completion([])
        return
      }

      switch response.result {
      case .success(let json):
        let items = (type == .meal ? json.meals : json.drinks) ?? []
        let prefix = items.prefix(limit)
        let group = DispatchGroup()
        var fullRecipes: [NinjaRecipe] = []
        var lock = NSLock()

        for item in prefix {
          guard let id = (type == .meal ? item["idMeal"] : item["idDrink"]) as? String else {
            continue
          }
          group.enter()
          self.fetchDetails(id: id, type: type) { recipe in
            if let recipe = recipe {
              lock.lock()
              fullRecipes.append(recipe)
              lock.unlock()
            }
            group.leave()
          }
        }

        group.notify(queue: .main) {
          completion(fullRecipes)
        }
      case .failure(let error):
        print("Error fetching category: \(error)")
        completion([])
      }
    }
  }

  private func fetchDetails(id: String, type: ApiType, completion: @escaping (NinjaRecipe?) -> Void)
  {
    let baseUrl =
      type == .meal
      ? "https://www.themealdb.com/api/json/v1/1/lookup.php?i="
      : "https://www.thecocktaildb.com/api/json/v1/1/lookup.php?i="

    AF.request(baseUrl + id).responseDecodable(of: ExternalResponse.self) { [weak self] response in
      guard let self = self else {
        completion(nil)
        return
      }

      switch response.result {
      case .success(let json):
        guard let dict = (type == .meal ? json.meals : json.drinks)?.first else {
          completion(nil)
          return
        }
        completion(self.mapToNinja(dict, type: type))
      case .failure:
        completion(nil)
      }
    }
  }

  private func mapToNinja(_ dict: [String: String?], type: ApiType) -> NinjaRecipe {
    let title = (type == .meal ? dict["strMeal"] : dict["strDrink"]) as? String ?? "Unknown"
    let instructions = dict["strInstructions"] as? String ?? "No instructions."

    var ingredients: [String] = []
    for i in 1...20 {
      if let ing = dict["strIngredient\(i)"] as? String,
        !ing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      {
        let measure = dict["strMeasure\(i)"] as? String ?? ""
        ingredients.append("\(measure) \(ing)".trimmingCharacters(in: .whitespacesAndNewlines))
      }
    }

    let image = (type == .meal ? dict["strMealThumb"] : dict["strDrinkThumb"]) as? String

    return NinjaRecipe(
      title: title,
      ingredients: ingredients.joined(separator: "\n"),
      instructions: instructions,
      servings: "2",
      image: image
    )
  }
}
