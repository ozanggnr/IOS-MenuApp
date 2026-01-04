import UIKit

enum PaletteHelper {
  static func accent(for category: String) -> UIColor {
    switch category {
    case "Dinner": return .systemRed
    case "Breakfast": return .systemOrange
    case "Lunch": return .systemGreen
    case "Salad": return .systemGreen
    case "Street Food": return .systemYellow
    case "Drinks": return .systemTeal
    case "Appetizers": return .systemPurple
    case "Sides": return .systemBrown
    default: return .systemBlue
    }
  }
}

final class ImageLoader {
  static let shared = ImageLoader()
  private init() {}

  private let cache = NSCache<NSString, UIImage>()

  func loadImage(url: String, into imageView: UIImageView) {
    let key = NSString(string: url)

    if let cached = cache.object(forKey: key) {
      imageView.image = cached
      return
    }

    imageView.image = UIImage(named: "RecipePlaceholder")

    // Add activity indicator
    let loader = UIActivityIndicatorView(style: .medium)
    loader.translatesAutoresizingMaskIntoConstraints = false
    loader.hidesWhenStopped = true
    imageView.addSubview(loader)
    NSLayoutConstraint.activate([
      loader.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
      loader.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
    ])
    loader.startAnimating()

    guard let imageURL = URL(string: url) else {
      loader.stopAnimating()
      loader.removeFromSuperview()
      return
    }

    URLSession.shared.dataTask(with: imageURL) { [weak self, weak imageView] data, _, error in
      DispatchQueue.main.async {
        loader.stopAnimating()
        loader.removeFromSuperview()

        guard error == nil, let data = data, let image = UIImage(data: data) else {
          print("Error loading image from \(url): \(String(describing: error))")
          return
        }

        self?.cache.setObject(image, forKey: key)
        imageView?.image = image
      }
    }.resume()
  }
}
