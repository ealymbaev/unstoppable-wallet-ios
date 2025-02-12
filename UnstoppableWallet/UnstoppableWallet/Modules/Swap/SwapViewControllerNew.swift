import UIKit
import ThemeKit
import UniswapKit
import HUD
import RxSwift
import RxCocoa
import SectionsTableView
import ComponentKit

class SwapViewControllerNew: ThemeViewController {
    private let animationDuration: TimeInterval = 0.2
    private let disposeBag = DisposeBag()

    private let viewModel: SwapViewModel
    private let dataSourceManager: ISwapDataSourceManager
    private let tableView = SectionsTableView(style: .grouped)
    private var isLoaded = false

    private var dataSource: ISwapDataSource?

    init(viewModel: SwapViewModel, dataSourceManager: ISwapDataSourceManager) {
        self.viewModel = viewModel
        self.dataSourceManager = dataSourceManager

        super.init()

        hidesBottomBarWhenPushed = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "swap.title".localized

        navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(named: "settings_2_24")?.withRenderingMode(.alwaysTemplate), style: .plain, target: self, action: #selector(onOpenSettings))
        navigationItem.leftBarButtonItem?.tintColor = .themeJacob
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "button.close".localized, style: .plain, target: self, action: #selector(onClose))
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)

        view.addSubview(tableView)
        tableView.snp.makeConstraints { maker in
            maker.edges.equalToSuperview()
        }

        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.sectionDataSource = self
        tableView.keyboardDismissMode = .onDrag

        subscribeToViewModel()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isLoaded = true
    }

    private func subscribeToViewModel() {
        subscribe(disposeBag, dataSourceManager.dataSourceUpdated) { [weak self] _ in
            self?.updateDataSource()
        }
        updateDataSource()
    }

    private func updateDataSource() {
        dataSource = dataSourceManager.dataSource

        dataSource?.onReload = { [weak self] in self?.reloadTable() }
        dataSource?.onClose = { [weak self] in self?.onClose() }
        dataSource?.onOpen = { [weak self] viewController, viaPush in
            if viaPush {
                self?.navigationController?.pushViewController(viewController, animated: true)
            } else {
                self?.present(viewController, animated: true)
            }
        }

        if isLoaded {
            tableView.reload()
        } else {
            tableView.buildSections()
        }
    }

    @objc func onClose() {
        dismiss(animated: true)
    }

    @objc func onOpenSettings() {
        guard  let viewController = SwapSettingsModule.viewController(
                dataSourceManager: dataSourceManager,
                dexManager: viewModel.dexManager) else {

            return
        }

        present(viewController, animated: true)
    }

    private func reloadTable() {
        tableView.buildSections()

        guard isLoaded else {
            return
        }

        UIView.animate(withDuration: animationDuration) {
            self.tableView.beginUpdates()
            self.tableView.endUpdates()
        }
    }

}

extension SwapViewControllerNew: SectionsDataSource {

    func buildSections() -> [SectionProtocol] {
        var sections = [SectionProtocol]()

        if let dataSource = dataSource {
            sections.append(contentsOf: dataSource.buildSections())
        }

        return sections
    }

}

