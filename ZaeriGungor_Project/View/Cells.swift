import UIKit
import Kingfisher

final class RecipeCell: UITableViewCell {
  static let reuseID = "RecipeCell"

  private let cardView = UIView()
  private let stack = UIStackView()
  private let titleLabel = UILabel()
  private let summaryLabel = UILabel()
  private let badge = UILabel()
  private let favoriteDot = UIView()
  private let thumbImageView = UIImageView()

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    selectionStyle = .none
    configureUI()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func configure(with recipe: Recipe) {
    titleLabel.text = recipe.titleText
    summaryLabel.text = recipe.summaryText
    badge.text = "\(recipe.duration) min • \(recipe.difficulty ?? "Easy")"
    favoriteDot.isHidden = !recipe.isFavorite
    if let imageName = recipe.imageName, imageName.hasPrefix("http"), let url = URL(string: imageName) {
      thumbImageView.kf.setImage(with: url, placeholder: UIImage(named: "RecipePlaceholder"))
    } else {
      thumbImageView.image =
        UIImage(named: recipe.imageName ?? "") ?? UIImage(named: "RecipePlaceholder")
    }
    cardView.layer.borderColor =
      PaletteHelper.accent(for: recipe.category ?? "General").withAlphaComponent(0.3).cgColor
  }

  private func configureUI() {
    backgroundColor = .clear
    contentView.backgroundColor = .clear

    cardView.translatesAutoresizingMaskIntoConstraints = false
    cardView.backgroundColor = UIColor.secondarySystemBackground
    cardView.layer.cornerRadius = 14
    cardView.layer.borderWidth = 1
    contentView.addSubview(cardView)

    thumbImageView.translatesAutoresizingMaskIntoConstraints = false
    thumbImageView.layer.cornerRadius = 12
    thumbImageView.clipsToBounds = true
    thumbImageView.contentMode = .scaleAspectFill
    thumbImageView.backgroundColor = UIColor.systemGray6

    titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
    titleLabel.numberOfLines = 2

    summaryLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
    summaryLabel.textColor = .secondaryLabel
    summaryLabel.numberOfLines = 2

    badge.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .medium)
    badge.textColor = .tertiaryLabel

    favoriteDot.translatesAutoresizingMaskIntoConstraints = false
    favoriteDot.backgroundColor = .systemOrange
    favoriteDot.layer.cornerRadius = 5

    stack.axis = .vertical
    stack.spacing = 6
    stack.translatesAutoresizingMaskIntoConstraints = false
    [titleLabel, summaryLabel, badge].forEach { stack.addArrangedSubview($0) }

    let hStack = UIStackView(arrangedSubviews: [thumbImageView, stack])
    hStack.axis = .horizontal
    hStack.spacing = 12
    hStack.alignment = .top
    hStack.translatesAutoresizingMaskIntoConstraints = false

    cardView.addSubview(hStack)
    cardView.addSubview(favoriteDot)

    NSLayoutConstraint.activate([
      cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
      cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
      cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
      cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

      thumbImageView.widthAnchor.constraint(equalToConstant: 88),
      thumbImageView.heightAnchor.constraint(equalToConstant: 88),

      hStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
      hStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
      hStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
      hStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12),

      favoriteDot.widthAnchor.constraint(equalToConstant: 10),
      favoriteDot.heightAnchor.constraint(equalToConstant: 10),
      favoriteDot.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 10),
      favoriteDot.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -10),
    ])
  }
}

final class IngredientBadgeCell: UICollectionViewCell {
  static let reuseID = "IngredientBadgeCell"
  private let label = UILabel()

  override init(frame: CGRect) {
    super.init(frame: frame)
    contentView.layer.cornerRadius = 12
    contentView.layer.borderWidth = 1
    contentView.layer.borderColor = UIColor.systemGray4.cgColor
    contentView.backgroundColor = UIColor.secondarySystemBackground
    label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
    label.textColor = .label
    label.numberOfLines = 1
    label.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(label)
    NSLayoutConstraint.activate([
      label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
      label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
      label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
      label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
    ])
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func configure(text: String, tint: UIColor) {
    label.text = text
    contentView.layer.borderColor = tint.withAlphaComponent(0.4).cgColor
    contentView.backgroundColor = tint.withAlphaComponent(0.12)
  }
}
