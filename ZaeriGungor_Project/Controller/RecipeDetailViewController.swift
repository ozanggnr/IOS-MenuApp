import Kingfisher
import UIKit

final class RecipeDetailViewController: UIViewController {
  private let recipe: Recipe
  private let scrollView = UIScrollView()
  private let contentStack = UIStackView()
  private let collectionView: UICollectionView
  private let stepsLabel = UILabel()
  private let favoriteButton = UIButton(type: .system)
  private var headerGradient: CAGradientLayer?

  init(recipe: Recipe) {
    self.recipe = recipe
    let layout = UICollectionViewFlowLayout()
    layout.minimumInteritemSpacing = 8
    layout.minimumLineSpacing = 8
    layout.estimatedItemSize = CGSize(width: 120, height: 32)
    self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    title = recipe.titleText
    setupScrollView()
    setupHeader()
    setupIngredients()
    setupSteps()
    setupAddToOrderButton()
    configureFavoriteButton()
  }

  private func setupScrollView() {
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    contentStack.axis = .vertical
    contentStack.spacing = 16
    contentStack.translatesAutoresizingMaskIntoConstraints = false
    scrollView.addSubview(contentStack)
    view.addSubview(scrollView)

    let contentGuide = scrollView.contentLayoutGuide
    let frameGuide = scrollView.frameLayoutGuide
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

      contentStack.topAnchor.constraint(equalTo: contentGuide.topAnchor, constant: 16),
      contentStack.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor, constant: 20),
      contentStack.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor, constant: -20),
      contentStack.bottomAnchor.constraint(equalTo: contentGuide.bottomAnchor, constant: -24),
      contentStack.widthAnchor.constraint(equalTo: frameGuide.widthAnchor, constant: -40),
    ])
  }

  private func setupHeader() {
    let card = UIView()
    card.backgroundColor = PaletteHelper.accent(for: recipe.category ?? "General")
      .withAlphaComponent(0.15)
    card.layer.cornerRadius = 16
    card.translatesAutoresizingMaskIntoConstraints = false

    let imageView = UIImageView()
    if let imageName = recipe.imageName, imageName.hasPrefix("http"),
      let url = URL(string: imageName)
    {
      imageView.kf.setImage(with: url, placeholder: UIImage(named: "RecipePlaceholder"))
    } else {
      imageView.image =
        UIImage(named: recipe.imageName ?? "") ?? UIImage(named: "RecipePlaceholder")
    }
    imageView.contentMode = .scaleAspectFill
    imageView.layer.cornerRadius = 14
    imageView.clipsToBounds = true
    imageView.translatesAutoresizingMaskIntoConstraints = false

    // Add Gradient Overlay
    let gradient = CAGradientLayer()
    gradient.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.6).cgColor]
    gradient.locations = [0.6, 1.0]
    imageView.layer.addSublayer(gradient)
    self.headerGradient = gradient

    let categoryLabel = UILabel()
    categoryLabel.text = recipe.category?.uppercased() ?? "RECIPE"
    categoryLabel.font = UIFont.systemFont(ofSize: 12, weight: .bold)
    categoryLabel.textColor = PaletteHelper.accent(for: recipe.category ?? "General")

    let titleLabel = UILabel()
    titleLabel.text = recipe.titleText
    titleLabel.font = UIFont.boldSystemFont(ofSize: 24)
    titleLabel.textColor = .label

    let subtitle = UILabel()
    subtitle.text = recipe.summaryText
    subtitle.font = UIFont.preferredFont(forTextStyle: .body)
    subtitle.textColor = .secondaryLabel
    subtitle.numberOfLines = 0

    let meta = UILabel()
    let durationText = "\(recipe.duration) min • \(recipe.difficulty ?? "Easy")"
    meta.text = durationText
    meta.font = UIFont.preferredFont(forTextStyle: .footnote)
    meta.textColor = .tertiaryLabel

    let stack = UIStackView(arrangedSubviews: [categoryLabel, titleLabel, subtitle, meta])
    stack.axis = .vertical
    stack.spacing = 6
    stack.translatesAutoresizingMaskIntoConstraints = false

    card.addSubview(imageView)
    card.addSubview(stack)

    NSLayoutConstraint.activate([
      imageView.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
      imageView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
      imageView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
      imageView.heightAnchor.constraint(equalToConstant: 200),

      stack.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 12),
      stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
      stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
      stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
    ])

    let doubleTap = UITapGestureRecognizer(
      target: self, action: #selector(toggleFavoriteFromDetail))
    doubleTap.numberOfTapsRequired = 2
    imageView.isUserInteractionEnabled = true
    imageView.addGestureRecognizer(doubleTap)

    contentStack.addArrangedSubview(card)
  }

  private func setupIngredients() {
    let title = UILabel()
    title.text = "Ingredients"
    title.font = UIFont.boldSystemFont(ofSize: 20)
    title.textColor = .label

    collectionView.backgroundColor = .clear
    collectionView.translatesAutoresizingMaskIntoConstraints = false
    collectionView.dataSource = self
    collectionView.delegate = self
    collectionView.register(
      IngredientBadgeCell.self, forCellWithReuseIdentifier: IngredientBadgeCell.reuseID)

    let container = UIStackView(arrangedSubviews: [title, collectionView])
    container.axis = .vertical
    container.spacing = 8

    collectionView.heightAnchor.constraint(equalToConstant: 140).isActive = true
    contentStack.addArrangedSubview(container)
  }

  private func setupSteps() {
    let title = UILabel()
    title.text = "Steps"
    title.font = UIFont.boldSystemFont(ofSize: 20)
    title.textColor = .label

    let stepText = recipe.stepsList.enumerated().map { "• \($0.element)" }.joined(separator: "\n")
    stepsLabel.text = stepText
    stepsLabel.numberOfLines = 0
    stepsLabel.font = UIFont.preferredFont(forTextStyle: .body)
    stepsLabel.textColor = .secondaryLabel

    let container = UIStackView(arrangedSubviews: [title, stepsLabel])
    container.axis = .vertical
    container.spacing = 8
    contentStack.addArrangedSubview(container)
  }

  private func configureFavoriteButton() {
    favoriteButton.setImage(
      UIImage(systemName: recipe.isFavorite ? "heart.fill" : "heart"), for: .normal)
    favoriteButton.addTarget(self, action: #selector(toggleFavoriteFromDetail), for: .touchUpInside)
    favoriteButton.tintColor = PaletteHelper.accent(for: recipe.category ?? "General")
    navigationItem.rightBarButtonItem = UIBarButtonItem(customView: favoriteButton)
  }

  @objc private func addToOrder() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    if OrderManager.shared.add(recipe) {
      let alert = UIAlertController(
        title: "Added!", message: "\(recipe.titleText) is in your order.", preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "OK", style: .default))
      present(alert, animated: true)
    } else {
      let alert = UIAlertController(
        title: "Limit Reached", message: "You can only order up to 3 items.", preferredStyle: .alert
      )
      alert.addAction(UIAlertAction(title: "OK", style: .default))
      present(alert, animated: true)
    }
  }

  private func setupAddToOrderButton() {
    let btn = UIButton(type: .system)
    btn.setTitle("Add to Order", for: .normal)
    btn.backgroundColor = .systemBlue
    btn.setTitleColor(.white, for: .normal)
    btn.layer.cornerRadius = 8
    btn.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
    btn.translatesAutoresizingMaskIntoConstraints = false
    btn.addTarget(self, action: #selector(addToOrder), for: .touchUpInside)

    contentStack.addArrangedSubview(btn)
    btn.heightAnchor.constraint(equalToConstant: 50).isActive = true
  }

  @objc private func toggleFavoriteFromDetail() {
    RecipeStore.shared.toggleFavorite(recipe)
    favoriteButton.setImage(
      UIImage(systemName: recipe.isFavorite ? "heart.fill" : "heart"), for: .normal)
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    headerGradient?.frame = CGRect(x: 0, y: 0, width: view.bounds.width - 64, height: 200)
    // 64 is padding (20*2 from safe area + 12*2 from card)
  }
}

extension RecipeDetailViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout
{
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int)
    -> Int
  {
    recipe.ingredientsList.count
  }

  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath)
    -> UICollectionViewCell
  {
    guard
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: IngredientBadgeCell.reuseID, for: indexPath) as? IngredientBadgeCell
    else {
      return UICollectionViewCell()
    }
    cell.configure(
      text: recipe.ingredientsList[indexPath.item],
      tint: PaletteHelper.accent(for: recipe.category ?? "General"))
    return cell
  }
}
