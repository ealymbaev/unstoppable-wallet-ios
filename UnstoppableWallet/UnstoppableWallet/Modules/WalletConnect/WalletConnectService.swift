import EthereumKit
import WalletConnect
import RxSwift
import RxRelay
import CurrencyKit
import BigInt
import HsToolKit

class WalletConnectService {
    private let manager: WalletConnectManager
    private let sessionManager: WalletConnectSessionManager
    private let reachabilityManager: IReachabilityManager
    private let disposeBag = DisposeBag()

    private var interactor: WalletConnectInteractor?
    private var sessionData: SessionData?

    private var stateRelay = PublishRelay<State>()
    private var connectionStateRelay = PublishRelay<WalletConnectInteractor.State>()
    private var requestRelay = PublishRelay<WalletConnectRequest>()

    private var pendingRequests = [Int: WalletConnectRequest]()
    private var requestIsProcessing = false

    private let queue = DispatchQueue(label: "io.horizontalsystems.unstoppable.wallet-connect-service", qos: .userInitiated)

    private(set) var state: State = .idle {
        didSet {
            stateRelay.accept(state)
        }
    }

    var connectionState: WalletConnectInteractor.State {
        interactor?.state ?? .disconnected
    }

    init(session: WalletConnectSession?, uri: String?, manager: WalletConnectManager, sessionManager: WalletConnectSessionManager, reachabilityManager: IReachabilityManager) {
        self.manager = manager
        self.sessionManager = sessionManager
        self.reachabilityManager = reachabilityManager

        if let session = session {
            restore(session: session)
        }
        if let uri = uri {
            do {
                try connect(uri: uri)

                state = .ready
            } catch {
                state = .invalid(error: error)
            }
        }

        reachabilityManager.reachabilityObservable
                .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .background))
                .subscribe(onNext: { [weak self] reachable in
                    if reachable {
                        self?.interactor?.connect()
                    }
                })
                .disposed(by: disposeBag)
    }

    private func restore(session: WalletConnectSession) {
        do {
            try initSession(peerId: session.peerId, peerMeta: session.peerMeta, chainId: session.chainId)

            interactor = WalletConnectInteractor(session: session.session, remotePeerId: session.peerId)
            interactor?.delegate = self
            interactor?.connect()

            state = .ready
        } catch {
            state = .invalid(error: error)
        }
    }

    private func initSession(peerId: String, peerMeta: WCPeerMeta, chainId: Int) throws {
        guard let account = manager.activeAccount else {
            throw SessionError.noSuitableAccount
        }

        guard let evmKit = manager.evmKit(chainId: chainId, account: account) else {
            throw SessionError.unsupportedChainId
        }

        sessionData = SessionData(peerId: peerId, peerMeta: peerMeta, account: account, evmKit: evmKit)
    }

    private func handleRequest(id: Int, requestResolver: () throws -> WalletConnectRequest) {
        do {
            let request = try requestResolver()
            pendingRequests[id] = request
            processNextRequest()
        } catch {
            interactor?.rejectRequest(id: id, message: error.smartDescription)
        }
    }

    private func processNextRequest() {
        guard !requestIsProcessing else {
            return
        }

        guard let nextRequest = pendingRequests.values.first else {
            return
        }

        requestRelay.accept(nextRequest)
        requestIsProcessing = true
    }

}

extension WalletConnectService {

    var stateObservable: Observable<State> {
        stateRelay.asObservable()
    }

    var connectionStateObservable: Observable<WalletConnectInteractor.State> {
        connectionStateRelay.asObservable()
    }

    var requestObservable: Observable<WalletConnectRequest> {
        requestRelay.asObservable()
    }

    var remotePeerMeta: WCPeerMeta? {
        sessionData?.peerMeta
    }

    var evmKit: EthereumKit.Kit? {
        sessionData?.evmKit
    }

    func pendingRequest(requestId: Int) -> WalletConnectRequest? {
        pendingRequests[requestId]
    }

    func connect(uri: String) throws {
        interactor = try WalletConnectInteractor(uri: uri)
        interactor?.delegate = self
        interactor?.connect()
    }

    func approveSession() {
        guard let interactor = interactor, let sessionData = sessionData else {
            return
        }

        interactor.approveSession(address: sessionData.evmKit.address.eip55, chainId: sessionData.evmKit.networkType.chainId)

        let session = WalletConnectSession(
                chainId: sessionData.evmKit.networkType.chainId,
                accountId: sessionData.account.id,
                session: interactor.session,
                peerId: sessionData.peerId,
                peerMeta: sessionData.peerMeta
        )

        sessionManager.save(session: session)

        state = .ready
    }

    func rejectSession() {
        guard let interactor = interactor else {
            return
        }

        interactor.rejectSession(message: "Session Rejected by User")

        state = .killed
    }

    func approveRequest(id: Int, result: Any) {
        queue.async {
            if let request = self.pendingRequests.removeValue(forKey: id), let convertedResult = request.convert(result: result) {
                self.interactor?.approveRequest(id: id, result: convertedResult)
            }

            self.requestIsProcessing = false
            self.processNextRequest()
        }
    }

    func rejectRequest(id: Int) {
        queue.async {
            self.pendingRequests.removeValue(forKey: id)

            self.interactor?.rejectRequest(id: id, message: "Rejected by user")

            self.requestIsProcessing = false
            self.processNextRequest()
        }
    }

    func killSession() {
        guard let interactor = interactor else {
            return
        }

        interactor.killSession()
    }

}

extension WalletConnectService: IWalletConnectInteractorDelegate {

    func didUpdate(state: WalletConnectInteractor.State) {
        connectionStateRelay.accept(state)
    }

    func didRequestSession(peerId: String, peerMeta: WCPeerMeta, chainId: Int?) {
        do {
//            guard let chainId = chainId else {
//                throw SessionError.unsupportedChainId
//            }

            let chainId = chainId ?? 1 // fallback to chainId = 1 (Ethereum MainNet)

            try initSession(peerId: peerId, peerMeta: peerMeta, chainId: chainId)

            state = .waitingForApproveSession
        } catch {
            interactor?.rejectSession(message: "Session Rejected: \(error)")
            state = .invalid(error: error)
        }
    }

    func didKillSession() {
        if let sessionData = sessionData {
            sessionManager.deleteSession(peerId: sessionData.peerId)
        }

        state = .killed
    }

    func didRequestSendEthereumTransaction(id: Int, transaction: WCEthereumTransaction) {
        queue.async {
            self.handleRequest(id: id) {
                try WalletConnectSendEthereumTransactionRequest(id: id, transaction: transaction)
            }
        }
    }

    func didRequestSignEthereumTransaction(id: Int, transaction: WCEthereumTransaction) {
        print("didRequestSignEthereumTransaction")
    }

    func didRequestSign(id: Int, payload: WCEthereumSignPayload) {
        queue.async {
            self.handleRequest(id: id) {
                WalletConnectSignMessageRequest(id: id, payload: payload)
            }
        }
    }

}

extension WalletConnectService {

    enum State: Equatable {
        case idle
        case invalid(error: Error)
        case waitingForApproveSession
        case ready
        case killed

        static func ==(lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle): return true
            case (.invalid(let lhsError), .invalid(let rhsError)): return "\(lhsError)" == "\(rhsError)"
            case (.waitingForApproveSession, .waitingForApproveSession): return true
            case (.ready, .ready): return true
            case (.killed, .killed): return true
            default: return false
            }
        }
    }

    enum SessionError: Error {
        case invalidUrl
        case unsupportedChainId
        case noSuitableAccount
    }

    struct SessionData {
        let peerId: String
        let peerMeta: WCPeerMeta
        let account: Account
        let evmKit: EthereumKit.Kit
    }

}
