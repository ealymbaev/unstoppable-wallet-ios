import UIKit
import CurrencyKit

struct TransactionInfoModule {

    static func instance(transaction: TransactionRecord, wallet: TransactionWallet) -> UIViewController? {
        guard let adapter = App.shared.adapterManager.transactionsAdapter(for: wallet) else {
            return nil
        }

        let service = TransactionInfoService(adapter: adapter, rateManager: App.shared.rateManager, currencyKit: App.shared.currencyKit, feeCoinProvider: App.shared.feeCoinProvider, appConfigProvider: App.shared.appConfigProvider, accountSettingManager: App.shared.accountSettingManager)
        let factory = TransactionInfoViewItemFactory()
        let viewModel = TransactionInfoViewModel(service: service, factory: factory, transaction: transaction, wallet: wallet)
        let viewController = TransactionInfoViewController(viewModel: viewModel, pageTitle: "tx_info.title".localized, urlManager: UrlManager(inApp: true))

        return viewController
    }

}

extension TransactionInfoModule {

    enum ViewItem {
        case actionTitle(title: String, subTitle: String?)
        case amount(coinAmount: String, currencyAmount: String?, incoming: Bool?)
        case status(status: TransactionStatus)
        case date(date: Date)
        case from(value: String)
        case to(value: String)
        case recipient(value: String)
        case id(value: String)
        case rate(value: String)
        case fee(title: String, value: String)
        case price(price: String)
        case doubleSpend(txHash: String, conflictingTxHash: String)
        case lockInfo(lockState: TransactionLockState)
        case sentToSelf
        case rawTransaction
        case memo(text: String)
        case service(value: String)
        case explorer(title: String, url: String?)
    }

}
