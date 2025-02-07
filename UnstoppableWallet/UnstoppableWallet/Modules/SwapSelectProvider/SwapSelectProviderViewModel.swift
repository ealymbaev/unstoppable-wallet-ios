import RxSwift
import RxRelay
import RxCocoa
import CoinKit

class SwapSelectProviderViewModel {
    private let service: SwapSelectProviderService
    private let disposeBag = DisposeBag()

    private let sectionViewItemsRelay = BehaviorRelay<[ViewItem]>(value: [])
    private let selectedRelay = PublishRelay<Void>()

    private var currentIndices: (sectionIndex: Int, index: Int)?

    init(service: SwapSelectProviderService) {
        self.service = service

        service.itemsObservable
                .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .userInitiated))
                .subscribe(onNext: { [weak self] items in
                    self?.sync(items: items)
                })
                .disposed(by: disposeBag)

        sync(items: service.items)
    }

    private func sync(items: [SwapSelectProviderService.Item]) {
        let viewItems = items.map { item in
            ViewItem(
                    title: item.provider.rawValue,
                    icon: item.provider.icon,
                    selected: item.selected
            )
        }

        sectionViewItemsRelay.accept(viewItems)
    }

}

extension SwapSelectProviderViewModel {

    var selectedSignal: Signal<Void> {
        selectedRelay.asSignal()
    }

    var sectionViewItemsDriver: Driver<[ViewItem]> {
        sectionViewItemsRelay.asDriver()
    }

    func onSelect(index: Int) {
        service.set(provider: service.items[index].provider)
        selectedRelay.accept(())
    }

}

extension SwapSelectProviderViewModel {

    struct ViewItem {
        let title: String
        let icon: String
        let selected: Bool
    }

}

extension SwapModule.Dex.Provider {

    var icon: String {
        switch self {
        case .oneInch: return "1inch_24"
        case .uniswap: return "uniswap_24"
        case .pancake: return "pancake_24"
        }
    }

}