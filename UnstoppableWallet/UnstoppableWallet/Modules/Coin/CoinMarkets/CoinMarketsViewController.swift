import ThemeKit
import SnapKit
import SectionsTableView
import ComponentKit
import RxSwift
import RxCocoa

class CoinMarketsViewController: ThemeViewController {
    private let viewModel: CoinMarketsViewModel
    private let disposeBag = DisposeBag()

    private let tableView = SectionsTableView(style: .plain)
    private let headerView = CoinMarketsHeaderView()

    private var viewItems = [CoinMarketsViewModel.ViewItem]()
    private var isLoaded = false

    init(viewModel: CoinMarketsViewModel) {
        self.viewModel = viewModel

        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(tableView)
        tableView.snp.makeConstraints { maker in
            maker.edges.equalToSuperview()
        }

        title = viewModel.title

        tableView.sectionDataSource = self

        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.allowsSelection = false

        tableView.registerCell(forClass: G14Cell.self)

        headerView.set(volumeTypes: viewModel.volumeTypes)
        headerView.onTapSortType = { [weak self] in
            self?.openSortTypeSelector()
        }
        headerView.onSelectVolumeType = { [weak self] index in
            self?.viewModel.onSelectVolumeType(index: index)
        }

        subscribe(disposeBag, viewModel.sortTypeDriver) { [weak self] in self?.sync(sortType: $0) }
        subscribe(disposeBag, viewModel.viewItemsDriver) { [weak self] in self?.sync(viewItems: $0) }

        tableView.buildSections()

        isLoaded = true
    }

    private func sync(sortType: String) {
        headerView.set(sortType: sortType)
    }

    private func sync(viewItems: [CoinMarketsViewModel.ViewItem]) {
        self.viewItems = viewItems

        if isLoaded {
            tableView.reload()
        }
    }

    private func openSortTypeSelector() {
        let alertController = AlertRouter.module(
                title: "coin_page.coin_markets.sort_by".localized,
                viewItems: viewModel.sortTypeViewItems
        ) { [weak self] index in
            self?.viewModel.onSelectSortType(index: index)
        }

        present(alertController, animated: true)
    }

}

extension CoinMarketsViewController: SectionsDataSource {

    private func row(viewItem: CoinMarketsViewModel.ViewItem, index: Int, isLast: Bool) -> RowProtocol {
        Row<G14Cell>(
                id: "item-\(index)",
                height: .heightDoubleLineCell,
                bind: { cell, _ in
                    cell.set(backgroundStyle: .transparent, isLast: isLast)
                    cell.setTitleImage(urlString: viewItem.marketImageUrl)
                    cell.titleImageCornerRadius = .cornerRadius4
                    cell.titleImageBackgroundColor = .themeSteel10
                    cell.topText = viewItem.market
                    cell.bottomText = viewItem.pair
                    cell.primaryValueText = viewItem.rate
                    cell.secondaryTitleText = "market.market_field.vol".localized
                    cell.secondaryValueText = viewItem.volume
                }
        )
    }

    func buildSections() -> [SectionProtocol] {
        [
            Section(
                    id: "main",
                    headerState: .static(view: headerView, height: CoinMarketsHeaderView.height),
                    footerState: .marginColor(height: .margin32, color: .clear),
                    rows: viewItems.enumerated().map { index, viewItem in
                        row(viewItem: viewItem, index: index, isLast: index == viewItems.count - 1)
                    }
            )
        ]
    }

}
