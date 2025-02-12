import ThemeKit
import SnapKit
import SectionsTableView
import RxSwift
import RxCocoa
import ComponentKit

class AddTokenViewController: ThemeViewController {
    private let viewModel: AddTokenViewModel
    private let pageTitle: String
    private let referenceTitle: String

    private let disposeBag = DisposeBag()

    private let tableView = SectionsTableView(style: .grouped)

    private let inputCell = AddressInputCell()
    private let inputCautionCell = FormCautionCell()
    private let coinTypeCell = D7Cell()
    private let coinNameCell = D7Cell()
    private let coinCodeCell = D7Cell()
    private let decimalCell = D7Cell()

    private let addButtonHolder = BottomGradientHolder()
    private let addButton = ThemeButton()

    private var isLoaded = false

    init(viewModel: AddTokenViewModel, pageTitle: String, referenceTitle: String) {
        self.viewModel = viewModel
        self.pageTitle = pageTitle
        self.referenceTitle = referenceTitle

        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = pageTitle
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "button.cancel".localized, style: .plain, target: self, action: #selector(onTapCancelButton))

        view.addSubview(tableView)
        tableView.snp.makeConstraints { maker in
            maker.leading.top.trailing.equalToSuperview()
        }

        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.sectionDataSource = self

        inputCell.isEditable = false
        inputCell.inputPlaceholder = referenceTitle
        inputCell.onChangeHeight = { [weak self] in self?.reloadTable() }
        inputCell.onChangeText = { [weak self] in self?.viewModel.onEnter(reference: $0) }
        inputCell.onFetchText = { [weak self] in
            self?.viewModel.onEnter(reference: $0)
            self?.inputCell.inputText = $0
        }
        inputCell.onOpenViewController = { [weak self] in self?.present($0, animated: true) }

        inputCautionCell.onChangeHeight = { [weak self] in self?.reloadTable() }

        coinTypeCell.set(backgroundStyle: .lawrence, isFirst: true)
        coinTypeCell.title = "add_token.coin_type".localized

        coinNameCell.set(backgroundStyle: .lawrence)
        coinNameCell.title = "add_token.coin_name".localized

        coinCodeCell.set(backgroundStyle: .lawrence)
        coinCodeCell.title = "add_token.coin_code".localized

        decimalCell.set(backgroundStyle: .lawrence, isLast: true)
        decimalCell.title = "add_token.decimal".localized

        view.addSubview(addButtonHolder)
        addButtonHolder.snp.makeConstraints { maker in
            maker.top.equalTo(tableView.snp.bottom).offset(-CGFloat.margin16)
            maker.leading.trailing.bottom.equalToSuperview()
        }

        addButtonHolder.addSubview(addButton)
        addButton.snp.makeConstraints { maker in
            maker.edges.equalToSuperview().inset(CGFloat.margin24)
            maker.height.equalTo(CGFloat.heightButton)
        }

        addButton.apply(style: .primaryYellow)
        addButton.setTitle("button.add".localized, for: .normal)
        addButton.addTarget(self, action: #selector(onTapAddButton), for: .touchUpInside)

        subscribe(disposeBag, viewModel.loadingDriver) { [weak self] loading in
            self?.inputCell.set(isLoading: loading)
        }
        subscribe(disposeBag, viewModel.viewItemDriver) { [weak self] viewItem in
            self?.coinTypeCell.value = viewItem?.coinType ?? "..."
            self?.coinNameCell.value = viewItem?.coinName ?? "..."
            self?.coinCodeCell.value = viewItem?.coinCode ?? "..."
            self?.decimalCell.value = viewItem.map { "\($0.decimal)" } ?? "..."
        }
        subscribe(disposeBag, viewModel.buttonEnabledDriver) { [weak self] enabled in
            self?.addButton.isEnabled = enabled
        }
        subscribe(disposeBag, viewModel.cautionDriver) { [weak self] caution in
            self?.inputCell.set(cautionType: caution?.type)
            self?.inputCautionCell.set(caution: caution)
            self?.reloadTable()
        }
        subscribe(disposeBag, viewModel.finishSignal) { [weak self] in
            HudHelper.instance.showSuccess(title: "add_token.success_add".localized)
            self?.dismiss(animated: true)
        }

        tableView.buildSections()

        isLoaded = true
    }

    @objc private func onTapAddButton() {
        viewModel.onTapButton()
    }

    @objc private func onTapCancelButton() {
        dismiss(animated: true)
    }

    private func reloadTable() {
        guard isLoaded else {
            return
        }

        UIView.animate(withDuration: 0.2) {
            self.tableView.beginUpdates()
            self.tableView.endUpdates()
        }
    }

}

extension AddTokenViewController: SectionsDataSource {

    func buildSections() -> [SectionProtocol] {
        [
            Section(
                    id: "input",
                    headerState: .margin(height: .margin12),
                    footerState: .margin(height: .margin12),
                    rows: [
                        StaticRow(
                                cell: inputCell,
                                id: "input",
                                dynamicHeight: { [weak self] width in
                                    self?.inputCell.height(containerWidth: width) ?? 0
                                }
                        ),
                        StaticRow(
                                cell: inputCautionCell,
                                id: "input-caution",
                                dynamicHeight: { [weak self] width in
                                    self?.inputCautionCell.height(containerWidth: width) ?? 0
                                }
                        )
                    ]
            ),

            Section(
                    id: "main",
                    footerState: .margin(height: .margin32),
                    rows: [
                        StaticRow(
                                cell: coinTypeCell,
                                id: "coin-type",
                                dynamicHeight: { [weak self] width in
                                    self?.coinTypeCell.cellHeight ?? 0
                                }
                        ),
                        StaticRow(
                                cell: coinNameCell,
                                id: "coin-name",
                                dynamicHeight: { [weak self] width in
                                    self?.coinNameCell.cellHeight ?? 0
                                }
                        ),
                        StaticRow(
                                cell: coinCodeCell,
                                id: "coin-code",
                                dynamicHeight: { [weak self] width in
                                    self?.coinCodeCell.cellHeight ?? 0
                                }
                        ),
                        StaticRow(
                                cell: decimalCell,
                                id: "decimal",
                                dynamicHeight: { [weak self] width in
                                    self?.decimalCell.cellHeight ?? 0
                                }
                        )
                    ]
            )
        ]
    }

}
