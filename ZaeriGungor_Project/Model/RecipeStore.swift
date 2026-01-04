import Alamofire
import CoreData
import UIKit

struct RecipeSeed: Codable {
  let id: String
  let title: String
  let summary: String
  let ingredients: [String]
  let steps: [String]
  let category: String
  let imageName: String
  let difficulty: String
  let duration: Int
}

final class RecipeStore {
  static let shared: RecipeStore = {
    let context =
      (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
      ?? NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    return RecipeStore(context: context)
  }()

  private let context: NSManagedObjectContext

  init(context: NSManagedObjectContext) {
    self.context = context
  }

  func seedIfNeeded() {
    let request: NSFetchRequest<Recipe> = Recipe.fetchRequest()
    let count = (try? context.count(for: request)) ?? 0

    context.performAndWait {
      let seeds = decodeSeeds()
      if count == 0 {
        seeds.forEach { upsert(seed: $0) }
      } else {
        // Update existing seeds if they have the placeholder
        for seed in seeds {
          let req: NSFetchRequest<Recipe> = Recipe.fetchRequest()
          req.predicate = NSPredicate(format: "id == %@", seed.id)
          if let existing = (try? context.fetch(req))?.first,
            existing.imageName == "RecipePlaceholder"
          {
            existing.imageName = seed.imageName
          }
        }
      }
      save()
    }
  }

  func syncBundledNinjaRecipes() {
    context.performAndWait {
      let seeds: [NinjaRecipe] = decodeNinjaSeeds()
      seeds.forEach { self.upsert(ninja: $0, category: "Imported") }
      save()
    }
  }

  func fetchOnlineRecipes(completion: @escaping () -> Void) {
    let group = DispatchGroup()

    group.enter()
    RecipeAPIService.shared.fetchBreakfast { [weak self] recipes in
      self?.context.perform {
        recipes.forEach { self?.upsert(ninja: $0, category: "Breakfast") }
        self?.save()
        group.leave()
      }
    }

    group.enter()
    RecipeAPIService.shared.fetchLunch { [weak self] recipes in
      self?.context.perform {
        // Mapping "Chicken" to Lunch
        recipes.forEach { self?.upsert(ninja: $0, category: "Lunch") }
        self?.save()
        group.leave()
      }
    }

    group.enter()
    RecipeAPIService.shared.fetchDrinks { [weak self] recipes in
      self?.context.perform {
        recipes.forEach { self?.upsert(ninja: $0, category: "Drinks") }
        self?.save()
        group.leave()
      }
    }

    group.notify(queue: .main) {
      completion()
    }
  }

  // Updated filtering logic to support string categories
  func fetchRecipes(query: String?, categoryFilter: String?) -> [Recipe] {
    let request: NSFetchRequest<Recipe> = Recipe.fetchRequest()
    var predicates: [NSPredicate] = []

    if let category = categoryFilter {
      if category == "Favorites" {
        predicates.append(NSPredicate(format: "isFavorite == %@", NSNumber(value: true)))
      } else if category != "All" {
        predicates.append(NSPredicate(format: "category == %@", category))
      }
    }

    if let searchText = query?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
      searchText.isEmpty == false
    {
      let predicate = NSPredicate(
        format:
          "titleText CONTAINS[cd] %@ OR summaryText CONTAINS[cd] %@ OR ingredients CONTAINS[cd] %@",
        searchText, searchText, searchText)
      predicates.append(predicate)
    }

    if predicates.isEmpty == false {
      request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    request.sortDescriptors = [
      NSSortDescriptor(key: "isFavorite", ascending: false),
      NSSortDescriptor(key: "createdAt", ascending: false),
    ]
    return (try? context.fetch(request)) ?? []
  }

  func toggleFavorite(_ recipe: Recipe) {
    context.performAndWait {
      recipe.isFavorite.toggle()
      save()
    }
  }

  func markCooked(_ recipe: Recipe) {
    context.performAndWait {
      recipe.lastCookedAt = Date()
      save()
    }
  }

  func save() {
    guard context.hasChanges else { return }
    context.performAndWait {
      try? context.save()
    }
  }

  @discardableResult
  private func upsert(seed: RecipeSeed) -> Recipe {
    let recipe = Recipe(context: context)
    recipe.id = seed.id
    recipe.titleText = seed.title
    recipe.summaryText = seed.summary
    recipe.category = seed.category
    recipe.ingredients = seed.ingredients.joined(separator: "\n")
    recipe.steps = seed.steps.joined(separator: "\n")
    recipe.imageName = seed.imageName
    recipe.difficulty = seed.difficulty
    recipe.duration = Int16(seed.duration)
    recipe.createdAt = Date()
    recipe.isFavorite = false
    return recipe
  }

  private func decodeSeeds() -> [RecipeSeed] {
    guard let data = seedJSON.data(using: .utf8) else { return [] }
    return (try? JSONDecoder().decode([RecipeSeed].self, from: data)) ?? []
  }

  private func decodeNinjaSeeds() -> [NinjaRecipe] {
    guard let url = Bundle.main.url(forResource: "NinjaRecipesSample", withExtension: "json"),
      let data = try? Data(contentsOf: url)
    else { return [] }
    return (try? JSONDecoder().decode([NinjaRecipe].self, from: data)) ?? []
  }

  @discardableResult
  private func upsert(ninja: NinjaRecipe, category: String = "Imported") -> Recipe {
    let stableID = "ninja:\(ninja.title.lowercased())::\(ninja.ingredients.lowercased())"
    let request: NSFetchRequest<Recipe> = Recipe.fetchRequest()
    request.fetchLimit = 1
    request.predicate = NSPredicate(format: "id == %@", stableID)
    let existing = (try? context.fetch(request))?.first

    let recipe = existing ?? Recipe(context: context)
    recipe.id = stableID
    recipe.titleText = ninja.title
    recipe.summaryText = "Servings: \(ninja.servings ?? "2")"
    recipe.category = category
    recipe.ingredients = ninja.ingredients
      .split(separator: "|")
      .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
      .filter { $0.isEmpty == false }
      .joined(separator: "\n")
    recipe.steps = ninja.instructions
      .replacingOccurrences(of: ". ", with: ".\n")
      .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    recipe.imageName = ninja.image
    recipe.difficulty = "—"
    recipe.duration = 0
    recipe.createdAt = recipe.createdAt ?? Date()
    recipe.isFavorite = recipe.isFavorite
    return recipe
  }
}

final class OrderManager {
  static let shared = OrderManager()
  private init() {}

  private(set) var items: [Recipe] = []

  var canAdd: Bool {
    return items.count < 3
  }

  func add(_ recipe: Recipe) -> Bool {
    guard canAdd else { return false }
    guard !items.contains(where: { $0.id == recipe.id }) else { return false }
    items.append(recipe)
    return true
  }

  func remove(_ recipe: Recipe) {
    items.removeAll { $0.id == recipe.id }
  }

  func clear() {
    items.removeAll()
  }

  func submitOrder(completion: @escaping (Bool) -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      self.clear()
      completion(true)
    }
  }
}

private let seedJSON = """
  [
      {
          "id": "c13ce897-0d15-4a5f-8a65-1b3c6b7ff001",
          "title": "Herb Roasted Chicken",
          "summary": "Garlicky roast chicken with rosemary potatoes for cozy dinners.",
          "ingredients": ["4 chicken thighs", "2 tbsp olive oil", "3 cloves garlic", "Rosemary sprigs", "Sea salt", "Black pepper"],
          "steps": ["Preheat oven to 200°C", "Rub chicken with oil, garlic, salt and pepper", "Scatter potatoes and rosemary in pan", "Roast for 35 minutes until golden", "Rest for 5 minutes before serving"],
          "category": "Dinner",
          "imageName": "https://images.unsplash.com/photo-1598103442097-8b74394b95c6?q=80&w=1000&auto=format&fit=crop",
          "difficulty": "Medium",
          "duration": 35
      },
      {
          "id": "5d5f8a1b-2d42-4c76-9214-0f4227f24d09",
          "title": "Citrus Kale Salad",
          "summary": "Crunchy kale, orange segments and toasted seeds with honey dressing.",
          "ingredients": ["1 bunch kale", "1 orange", "1/4 cup toasted seeds", "2 tbsp olive oil", "1 tbsp honey", "Lemon juice"],
          "steps": ["Massage kale with olive oil", "Whisk honey and lemon for dressing", "Segment orange and toss with kale", "Top with toasted seeds and dressing"],
          "category": "Salad",
          "imageName": "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?q=80&w=1000&auto=format&fit=crop",
          "difficulty": "Easy",
          "duration": 12
      },
      {
          "id": "a1d59f3b-1871-46a3-9c5c-b27fa54fb955",
          "title": "Spicy Shrimp Tacos",
          "summary": "Chili-lime shrimp wrapped with crunchy slaw and avocado crema.",
          "ingredients": ["12 shrimp", "Corn tortillas", "1 tsp chili powder", "1 lime", "Shredded cabbage", "Avocado", "Greek yogurt"],
          "steps": ["Season shrimp with chili powder and lime", "Sear shrimp for 2 minutes per side", "Blend avocado with yogurt for crema", "Warm tortillas", "Assemble with slaw and crema"],
          "category": "Street Food",
          "imageName": "https://images.unsplash.com/photo-1565299585323-38d6b0865b47?q=80&w=1000&auto=format&fit=crop",
          "difficulty": "Medium",
          "duration": 25
      },
      {
          "id": "8bf054e7-6ee2-46df-9ae2-14a87d0d46fc",
          "title": "Overnight Oats",
          "summary": "Grab-and-go breakfast with chia, berries and almond butter.",
          "ingredients": ["1/2 cup rolled oats", "1 tbsp chia seeds", "1 cup milk", "Handful berries", "1 tbsp almond butter", "Dash of cinnamon"],
          "steps": ["Combine oats, chia, milk and cinnamon", "Chill overnight", "Top with berries and almond butter in morning"],
          "category": "Breakfast",
          "imageName": "https://images.unsplash.com/photo-1504113114402-4fc99abc0288?q=80&w=1000&auto=format&fit=crop",
          "difficulty": "Easy",
          "duration": 5
      },
      {
          "id": "3c9a0f77-45f7-4d7b-81cb-d3fd35a3cbe0",
          "title": "Matcha Latte",
          "summary": "Creamy, lightly sweet latte with ceremonial matcha.",
          "ingredients": ["1 tsp matcha powder", "60 ml hot water", "200 ml milk", "1 tsp maple syrup"],
          "steps": ["Whisk matcha with hot water until frothy", "Steam milk with maple syrup", "Combine and serve warm"],
          "category": "Drinks",
          "imageName": "https://images.unsplash.com/photo-1515823064-d6e0c04616a7?q=80&w=1000&auto=format&fit=crop",
          "difficulty": "Easy",
          "duration": 6
      },
      {
          "id": "app-01-bruschetta",
          "title": "Tomato Bruschetta",
          "summary": "Crispy baguette topped with fresh tomatoes, basil, and garlic.",
          "ingredients": ["1 baguette, sliced", "4 ripe tomatoes, diced", "Fresh basil leaves", "2 cloves garlic, minced", "Olive oil", "Balsamic glaze"],
          "steps": ["Toast baguette slices until golden", "Mix tomatoes, garlic, basil, and olive oil", "Spoon mixture onto bread", "Drizzle with balsamic glaze"],
          "category": "Appetizers",
          "imageName": "https://images.unsplash.com/photo-1572656631137-7935297eff55?q=80&w=1000&auto=format&fit=crop",
          "difficulty": "Easy",
          "duration": 15
      },
      {
          "id": "app-02-mozzarella-sticks",
          "title": "Baked Mozzarella Sticks",
          "summary": "Gooey cheese sticks breaded and baked to perfection.",
          "ingredients": ["12 mozzarella string cheese sticks", "1 cup flour", "2 eggs, beaten", "1 cup breadcrumbs", "1 tsp Italian seasoning", "Marinara sauce for dipping"],
          "steps": ["Freeze cheese sticks for 30 mins", "Dredge in flour, egg, then breadcrumbs", "Freeze again for 15 mins", "Bake at 200°C for 10-12 mins until golden"],
          "category": "Appetizers",
          "imageName": "https://images.unsplash.com/photo-1548340748-6d2b7d7da280?q=80&w=1000&auto=format&fit=crop",
          "difficulty": "Medium",
          "duration": 25
      },
      {
          "id": "drink-02-mojito",
          "title": "Classic Mojito",
          "summary": "Refreshing mint and lime cocktail (non-alcoholic version included).",
          "ingredients": ["Fresh mint leaves", "1/2 lime, cut into wedges", "2 tsp sugar", "Soda water", "Crushed ice", "Rum (optional)"],
          "steps": ["Muddle mint and lime with sugar in a glass", "Fill glass with ice", "Pour over soda water (and rum if using)", "Stir well and garnish with mint"],
          "category": "Drinks",
          "imageName": "https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?q=80&w=1000&auto=format&fit=crop",
          "difficulty": "Easy",
          "duration": 5
      }
  ]
  """
