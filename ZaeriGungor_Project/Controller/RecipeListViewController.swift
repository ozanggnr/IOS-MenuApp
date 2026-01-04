import AVFoundation
import Lottie
import UIKit

#if canImport(AudioToolbox)
  import AudioToolbox
#endif

final class RecipeListViewController: UIViewController {
  private var recipes: [Recipe] = []
  private let tableView = UITableView(frame: .zero, style: .insetGrouped)
  private let searchController = UISearchController(searchResultsController: nil)

  // New Filter UI
  private let categoryScrollView = UIScrollView()
  private let categoryStack = UIStackView()
  private let categories = [
    "All", "Dinner", "Breakfast", "Lunch", "Salad", "Street Food", "Sides", "Drinks", "Appetizers",
    "Favorites",
  ]
  private var selectedCategory = "All"
  private var categoryButtons: [UIButton] = []

  private let statsLabel = UILabel()
  private let heroLabel = UILabel()
  private let refreshControl = UIRefreshControl()
  private var soundID: SystemSoundID = 1104

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    title = "Foodie"
    navigationController?.navigationBar.prefersLargeTitles = true
    navigationItem.rightBarButtonItem = UIBarButtonItem(
      title: "My Order", style: .plain, target: self, action: #selector(showOrder))

    configureHeader()
    configureTableView()
    configureSearch()
    configureGestures()
    RecipeStore.shared.seedIfNeeded()
    RecipeStore.shared.syncBundledNinjaRecipes()
    reloadData()
    RecipeStore.shared.fetchOnlineRecipes { [weak self] in
      self?.reloadData()
    }
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    refreshHeaderHeight()
  }

  private func configureHeader() {
    heroLabel.text = "Foodie"
    heroLabel.font = UIFont.boldSystemFont(ofSize: 34)
    heroLabel.textColor = .label

    statsLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
    statsLabel.textColor = .secondaryLabel
    statsLabel.numberOfLines = 2

    let headerStack = UIStackView(arrangedSubviews: [heroLabel, statsLabel])
    headerStack.axis = .vertical
    headerStack.spacing = 8

    // Configure Category ScrollView
    categoryScrollView.showsHorizontalScrollIndicator = false
    categoryScrollView.alwaysBounceHorizontal = true
    categoryStack.axis = .horizontal
    categoryStack.spacing = 10
    categoryStack.alignment = .center
    categoryStack.translatesAutoresizingMaskIntoConstraints = false
    categoryScrollView.addSubview(categoryStack)

    NSLayoutConstraint.activate([
      categoryStack.topAnchor.constraint(equalTo: categoryScrollView.contentLayoutGuide.topAnchor),
      categoryStack.bottomAnchor.constraint(
        equalTo: categoryScrollView.contentLayoutGuide.bottomAnchor),
      categoryStack.leadingAnchor.constraint(
        equalTo: categoryScrollView.contentLayoutGuide.leadingAnchor),
      categoryStack.trailingAnchor.constraint(
        equalTo: categoryScrollView.contentLayoutGuide.trailingAnchor),
      categoryStack.heightAnchor.constraint(equalTo: categoryScrollView.heightAnchor),
    ])

    categories.enumerated().forEach { index, category in
      let button = UIButton(type: .system)
      button.setTitle("  \(category)  ", for: .normal)
      button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
      button.layer.cornerRadius = 14
      button.layer.borderWidth = 1
      button.tag = index
      button.addTarget(self, action: #selector(filterTapped(_:)), for: .touchUpInside)
      categoryStack.addArrangedSubview(button)
      categoryButtons.append(button)
    }
    updateFilterButtons()

    let container = UIStackView(arrangedSubviews: [headerStack, categoryScrollView])
    container.axis = .vertical
    container.spacing = 16
    container.translatesAutoresizingMaskIntoConstraints = false

    let headerView = UIView()
    headerView.addSubview(container)

    // Define height for category scroll view
    categoryScrollView.heightAnchor.constraint(equalToConstant: 30).isActive = true

    NSLayoutConstraint.activate([
      container.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 12),
      container.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
      container.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
      container.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -8),
    ])

    tableView.tableHeaderView = headerView
    refreshHeaderHeight()
  }

  private func updateFilterButtons() {
    categories.enumerated().forEach { index, category in
      let button = categoryButtons[index]
      let isSelected = category == selectedCategory

      if isSelected {
        button.backgroundColor = .label
        button.setTitleColor(.systemBackground, for: .normal)
        button.layer.borderColor = UIColor.label.cgColor
      } else {
        button.backgroundColor = .clear
        button.setTitleColor(.label, for: .normal)
        button.layer.borderColor = UIColor.systemGray4.cgColor
      }
    }
  }

  @objc private func filterTapped(_ sender: UIButton) {
    selectedCategory = categories[sender.tag]
    updateFilterButtons()
    reloadData()
  }

  private func configureTableView() {
    tableView.translatesAutoresizingMaskIntoConstraints = false
    tableView.register(RecipeCell.self, forCellReuseIdentifier: RecipeCell.reuseID)
    tableView.dataSource = self
    tableView.delegate = self
    tableView.rowHeight = UITableView.automaticDimension
    tableView.estimatedRowHeight = 120
    tableView.backgroundColor = .clear
    tableView.refreshControl = refreshControl
    refreshControl.addTarget(self, action: #selector(refreshPulled), for: .valueChanged)

    view.addSubview(tableView)
    NSLayoutConstraint.activate([
      tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
  }

  private func configureSearch() {
    searchController.searchResultsUpdater = self
    searchController.obscuresBackgroundDuringPresentation = false
    searchController.searchBar.placeholder = "Search recipes or ingredients"
    navigationItem.searchController = searchController
    definesPresentationContext = true
  }

  private func configureGestures() {
    let longPress = UILongPressGestureRecognizer(
      target: self, action: #selector(handleLongPress(_:)))
    tableView.addGestureRecognizer(longPress)
  }

  private func reloadData() {
    recipes = RecipeStore.shared.fetchRecipes(
      query: searchController.searchBar.text, categoryFilter: selectedCategory)

    let favCount = recipes.filter { $0.isFavorite }.count
    statsLabel.text = "\(recipes.count) recipes • \(favCount) favorites"

    tableView.reloadData()
    refreshControl.endRefreshing()
    refreshHeaderHeight()
  }

  private func refreshHeaderHeight() {
    guard let header = tableView.tableHeaderView else { return }
    header.setNeedsLayout()
    header.layoutIfNeeded()
    let height = header.systemLayoutSizeFitting(
      CGSize(width: view.bounds.width, height: UIView.layoutFittingCompressedSize.height)
    ).height
    if header.frame.height != height {
      header.frame.size.height = height
      tableView.tableHeaderView = header
    }
  }

  @objc private func refreshPulled() {
    print("Pull to refresh triggered")
    RecipeStore.shared.fetchOnlineRecipes { [weak self] in
      self?.reloadData()  // Assuming 'refresh()' was a typo and should be 'reloadData()' based on original context
      self?.refreshControl.endRefreshing()
    }
  }

  @objc private func showOrder() {
    let orderVC = OrderSummaryViewController()
    navigationController?.pushViewController(orderVC, animated: true)
  }
  @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
    guard gesture.state == .began else { return }
    let point = gesture.location(in: tableView)
    guard let indexPath = tableView.indexPathForRow(at: point) else { return }
    let recipe = recipes[indexPath.row]
    RecipeStore.shared.toggleFavorite(recipe)
    playFavoriteSound()
    reloadData()
  }

  private func playFavoriteSound() {
    #if canImport(AudioToolbox)
      AudioServicesPlaySystemSound(soundID)
    #endif
    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
  }
}

extension RecipeListViewController: UITableViewDataSource, UITableViewDelegate {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    recipes.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard
      let cell = tableView.dequeueReusableCell(withIdentifier: RecipeCell.reuseID, for: indexPath)
        as? RecipeCell
    else {
      return UITableViewCell()
    }
    cell.configure(with: recipes[indexPath.row])
    return cell
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    let detail = RecipeDetailViewController(recipe: recipes[indexPath.row])
    navigationController?.pushViewController(detail, animated: true)
  }

  func tableView(
    _ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
  ) -> UISwipeActionsConfiguration? {
    let cooked = UIContextualAction(style: .normal, title: "Cooked") { _, _, completion in
      let recipe = self.recipes[indexPath.row]
      RecipeStore.shared.markCooked(recipe)
      self.reloadData()
      completion(true)
    }
    cooked.backgroundColor = UIColor.systemGreen
    let favorite = UIContextualAction(style: .normal, title: "Favorite") { _, _, completion in
      let recipe = self.recipes[indexPath.row]
      RecipeStore.shared.toggleFavorite(recipe)
      self.playFavoriteSound()
      self.reloadData()
      completion(true)
    }
    favorite.backgroundColor = UIColor.systemOrange
    return UISwipeActionsConfiguration(actions: [favorite, cooked])
  }
}

extension RecipeListViewController: UISearchResultsUpdating {
  func updateSearchResults(for searchController: UISearchController) {
    reloadData()
  }
}

final class OrderSummaryViewController: UIViewController, UITableViewDataSource, UITableViewDelegate
{
  private let tableView = UITableView()
  private let totalLabel = UILabel()
  private let submitButton = UIButton(type: .system)

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "Order Summary"
    view.backgroundColor = .systemBackground

    setupTableView()
    setupFooter()
    layout()
  }

  private func setupTableView() {
    tableView.dataSource = self
    tableView.delegate = self
    tableView.register(RecipeCell.self, forCellReuseIdentifier: RecipeCell.reuseID)
    tableView.rowHeight = 100
    tableView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(tableView)
  }

  private func setupFooter() {
    submitButton.setTitle("Submit Order", for: .normal)
    submitButton.backgroundColor = .systemGreen
    submitButton.setTitleColor(.white, for: .normal)
    submitButton.layer.cornerRadius = 10
    submitButton.titleLabel?.font = .boldSystemFont(ofSize: 18)
    submitButton.addTarget(self, action: #selector(submitOrder), for: .touchUpInside)
    submitButton.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(submitButton)
  }

  private func layout() {
    NSLayoutConstraint.activate([
      tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      tableView.bottomAnchor.constraint(equalTo: submitButton.topAnchor, constant: -20),

      submitButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      submitButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
      submitButton.bottomAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
      submitButton.heightAnchor.constraint(equalToConstant: 50),
    ])
  }

  @objc private func submitOrder() {
    let animationView = LottieAnimationView(name: "success")
    animationView.frame = view.bounds
    animationView.contentMode = .scaleAspectFit
    animationView.loopMode = .playOnce
    view.addSubview(animationView)

    animationView.play { finished in
      OrderManager.shared.clear()
      self.navigationController?.popViewController(animated: true)
    }
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    OrderManager.shared.items.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard
      let cell = tableView.dequeueReusableCell(withIdentifier: RecipeCell.reuseID, for: indexPath)
        as? RecipeCell
    else {
      return UITableViewCell()
    }
    cell.configure(with: OrderManager.shared.items[indexPath.row])
    return cell
  }
}
