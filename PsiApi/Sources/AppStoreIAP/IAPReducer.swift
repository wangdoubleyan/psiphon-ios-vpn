/*
 * Copyright (c) 2020, Psiphon Inc.
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

import Foundation
import ReactiveSwift
import Promises
import StoreKit
import Utilities
import PsiApi
import PsiCashClient

public enum IAPAction: Equatable {
    case checkUnverifiedTransaction
    case purchase(product: AppStoreProduct, resultPromise: Promise<ObjCIAPResult>? = nil)
    case appReceiptDataUpdated(ReceiptData?)
    case _psiCashConsumableVerificationRequestResult(
            result: RetriableTunneledHttpRequest<PsiCashValidationResponse>.RequestResult,
            forTransaction: PaymentTransaction)
    case transactionUpdate(TransactionUpdate)
}

/// StoreKit transaction observer
public enum TransactionUpdate: Equatable {
    case updatedTransactions([PaymentTransaction])
    case restoredCompletedTransactions(error: SystemError<Int>?)
}

extension TransactionUpdate {
    var updatedTransactions: [PaymentTransaction]? {
        guard case let .updatedTransactions(value) = self else {
            return nil
        }
        return value
    }
    
    var restoredCompletedTransactions: SystemError<Int>?? {
        guard case let .restoredCompletedTransactions(error: error) = self else {
            return nil
        }
        return .some(error)
    }
}

public struct IAPReducerState: Equatable {
    public var iap: IAPState
    public var psiCashBalance: PsiCashBalance
    public let psiCashAccountType: PsiCashAccountType?
    
    public init(
        iap: IAPState,
        psiCashBalance: PsiCashBalance,
        psiCashAccountType: PsiCashAccountType?
    ) {
        self.iap = iap
        self.psiCashBalance = psiCashBalance
        self.psiCashAccountType = psiCashAccountType
    }
    
}

public struct IAPEnvironment {
    var feedbackLogger: FeedbackLogger
    var tunnelStatusSignal: SignalProducer<TunnelProviderVPNStatus, Never>
    var tunnelConnectionRefSignal: SignalProducer<TunnelConnection?, Never>
    var psiCashEffects: PsiCashEffectsProtocol
    var clientMetaData: () -> ClientMetaData
    var paymentQueue: PaymentQueue
    var psiCashPersistedValues: PsiCashPersistedValues
    var isSupportedProduct: (ProductID) -> AppStoreProductType?
    var psiCashStore: (PsiCashAction) -> Effect<Never>
    var appReceiptStore: (ReceiptStateAction) -> Effect<Never>
    var httpClient: HTTPClient
    var getCurrentTime: () -> Date
    
    public init(
        feedbackLogger: FeedbackLogger,
        tunnelStatusSignal: SignalProducer<TunnelProviderVPNStatus, Never>,
        tunnelConnectionRefSignal: SignalProducer<TunnelConnection?, Never>,
        psiCashEffects: PsiCashEffectsProtocol,
        clientMetaData: @escaping () -> ClientMetaData,
        paymentQueue: PaymentQueue,
        psiCashPersistedValues: PsiCashPersistedValues,
        isSupportedProduct: @escaping (ProductID) -> AppStoreProductType?,
        psiCashStore: @escaping (PsiCashAction) -> Effect<Never>,
        appReceiptStore: @escaping (ReceiptStateAction) -> Effect<Never>,
        httpClient: HTTPClient,
        getCurrentTime: @escaping () -> Date
    ) {
        self.feedbackLogger = feedbackLogger
        self.tunnelStatusSignal = tunnelStatusSignal
        self.tunnelConnectionRefSignal = tunnelConnectionRefSignal
        self.psiCashEffects = psiCashEffects
        self.clientMetaData = clientMetaData
        self.paymentQueue = paymentQueue
        self.psiCashPersistedValues = psiCashPersistedValues
        self.isSupportedProduct = isSupportedProduct
        self.psiCashStore = psiCashStore
        self.appReceiptStore = appReceiptStore
        self.httpClient = httpClient
        self.getCurrentTime = getCurrentTime
    }
}

public let iapReducer = Reducer<IAPReducerState, IAPAction, IAPEnvironment> {
    state, action, environment in
    
    switch action {
    case .checkUnverifiedTransaction:
        // Checks if there is an unverified transaction.
        guard state.iap.unfinishedPsiCashTx != nil else {
            return []
        }
        
        return [
            environment.appReceiptStore(.readLocalReceiptFile).mapNever()
        ]
        
    case let .purchase(product: product, resultPromise: maybeObjcSubscriptionPromise):
        
        // For each product type, only one product is allowed to be purchased at a time.
        guard state.iap.purchasing[product.type]?.completed ?? true else {
            return [
                environment.feedbackLogger.log(.warn, """
                    nop purchase: purchase in progress product type: '\(product.type)' \
                    : state: '\(makeFeedbackEntry(state.iap.purchasing[product.type]))'
                    """).mapNever()
            ]
        }
        
        switch product.type {
        case .psiCash:
            // No action is taken if there is already an unverified PsiCash transaction.
            guard state.iap.unfinishedPsiCashTx == nil else {
                return [
                    environment.feedbackLogger.log(.warn, """
                        nop PsiCash IAP purchase: unverified PsiCash transaction: \
                        '\(makeFeedbackEntry(state.iap.unfinishedPsiCashTx))'
                        """).mapNever()
                ]
            }
            
            // PsiCash IAP requires presence of PsiCash spender token.
            guard state.psiCashAccountType != .noTokens else {
                
                state.iap.purchasing[product.type] = IAPPurchasing(
                    productType: product.type,
                    productID: product.productID,
                    purchasingState: .completed(
                        ErrorEvent(.failedToCreatePurchase(reason: "PsiCash data not present"),
                                   date: environment.getCurrentTime()))
                )
                
                return [
                    environment.feedbackLogger.log(
                        .error, "PsiCash IAP purchase without tokens"
                    ).mapNever()
                ]
            }
            
        case .subscription:
            if let promise = maybeObjcSubscriptionPromise {
                state.iap.objcSubscriptionPromises.append(promise)
            }
        }
        
        state.iap.purchasing[product.type] = IAPPurchasing(
            productType: product.type,
            productID: product.productID,
            purchasingState: .pending(nil)
        )
        
        return [
            environment.paymentQueue.addPayment(product).mapNever(),
            environment.feedbackLogger.log(
                .info, "request to purchase: '\(makeFeedbackEntry(product))'").mapNever()
        ]
        
    case .appReceiptDataUpdated(let maybeReceiptData):
        guard let unfinishedPsiCashTx = state.iap.unfinishedPsiCashTx else {
            return []
        }
        
        // Requests verification only if one has not been made, or it failed.
        if case .pendingResponse = unfinishedPsiCashTx.verification {
            // A verification request has already been made.
            return []
        }
        
        guard let receiptData = maybeReceiptData else {
            
            state.iap.unfinishedPsiCashTx?.verification = .requestError(
                ErrorEvent(ErrorRepr(repr: "nil receipt"), date: environment.getCurrentTime())
            )
            
            return [
                environment.feedbackLogger.log(.error, """
                    nil receipt data: \
                    failed to send verification request for transaction: \
                    '\(unfinishedPsiCashTx)'
                    """)
                .mapNever()
            ]
        }
        
        let purchaseIsInReceipt = receiptData.consumableInAppPurchases.contains { purchase in
            purchase.matches(paymentTransaction: unfinishedPsiCashTx.transaction)
        }
        
        guard purchaseIsInReceipt else {
            
            state.iap.unfinishedPsiCashTx = .none
            
            return [
                environment.paymentQueue.finishTransaction(unfinishedPsiCashTx.transaction)
                    .mapNever(),
                environment.feedbackLogger.log(.error, """
                Finishing transaction since not found in the app receipt: \(unfinishedPsiCashTx)
                """)
                .mapNever()
            ]
        }
        
        guard let customData = environment.psiCashEffects.rewardedVideoCustomData() else {
            
            state.iap.unfinishedPsiCashTx?.verification = .requestError(
                ErrorEvent(
                    ErrorRepr(repr: "nil custom data"),
                    date: environment.getCurrentTime()
                )
            )
            
            return [
                environment.feedbackLogger.log(.error, """
                    nil customData: \
                    failed to send verification request for transaction: \
                    '\(unfinishedPsiCashTx)'
                    """)
                .mapNever()
            ]
        }
        
        state.iap.unfinishedPsiCashTx?.verification = .pendingResponse
        
        // Creates request to verify PsiCash AppStore IAP purchase.
        
        let req = PurchaseVerifierServer.psiCash(
            requestBody: PsiCashValidationRequest(
                productID: unfinishedPsiCashTx.transaction.productID(),
                receipt: receiptData,
                customData: customData
            ),
            clientMetaData: environment.clientMetaData()
        )
        
        let psiCashVerifyRequest = RetriableTunneledHttpRequest(
            request: req.request
        )
        
        var effects = [Effect<IAPAction>]()
        
        if let error = req.error {
            effects += [environment.feedbackLogger.log(.error,
                                                       tag: "IAPReducer.receiptUpdated",
                                                       error).mapNever()]
        }
        
        return effects + [
            psiCashVerifyRequest(
                getCurrentTime: environment.getCurrentTime,
                tunnelStatusSignal: environment.tunnelStatusSignal,
                tunnelConnectionRefSignal: environment.tunnelConnectionRefSignal,
                httpClient: environment.httpClient
            ).map {
                ._psiCashConsumableVerificationRequestResult(
                    result: $0,
                    forTransaction: unfinishedPsiCashTx.transaction
                )
            },
            
            environment.feedbackLogger.log(.info, """
                Consumables in app receipt '\(receiptData.consumableInAppPurchases)'
                """).mapNever(),
            
            environment.feedbackLogger.log(.info, """
                verifying PsiCash consumable IAP with transaction: '\(unfinishedPsiCashTx)'
                """).mapNever()
        ]
        
    case let ._psiCashConsumableVerificationRequestResult(requestResult, requestTransaction):
        guard let unfinishedPsiCashTx = state.iap.unfinishedPsiCashTx else {
            environment.feedbackLogger.fatalError("expected non-nil 'unverifiedPsiCashTx'")
            return []
        }
        
        guard case .pendingResponse = unfinishedPsiCashTx.verification else {
            environment.feedbackLogger.fatalError("""
                unexpected state for unverified PsiCash IAP transaction \
                '\(String(describing: state.iap.unfinishedPsiCashTx))'
                """)
            return []
        }
        
        guard unfinishedPsiCashTx.transaction == requestTransaction else {
            environment.feedbackLogger.fatalError("""
                expected transactions to be equal: \
                '\(makeFeedbackEntry(requestTransaction))' != \
                '\(makeFeedbackEntry(unfinishedPsiCashTx.transaction))'
                """)
            return []
        }
        
        switch requestResult {
        
        case .willRetry(when: let retryCondition):
            // Authorization request will be retried whenever retryCondition becomes true.
            switch retryCondition {
            case .whenResolved(tunnelError: .nilTunnelProviderManager):
                return [ environment.feedbackLogger.log(.error, retryCondition).mapNever() ]
                
            case .whenResolved(tunnelError: .tunnelNotConnected):
                // This event is too frequent to log.
                return []
                
            case .afterTimeInterval:
                return [ environment.feedbackLogger.log(.error, retryCondition).mapNever() ]
            }
            
        case .completed(let psiCashValidationResponse):
            switch psiCashValidationResponse {
            case .success(.unit):
                // 200-OK response from the server
                state.iap.unfinishedPsiCashTx = .none
                
                // Finishes the transaction, and refreshes PsiCash state for the latest balance.
                return [
                    environment.paymentQueue.finishTransaction(requestTransaction).mapNever(),
                    environment.psiCashStore(.refreshPsiCashState()).mapNever(),
                    environment.feedbackLogger.log(.info, "verified consumable transaction: '\(requestTransaction)'")
                    .mapNever()
                ]
                
            case .failure(let errorEvent):
                // Request failed or received a non-200 OK response.
                
                state.iap.unfinishedPsiCashTx?.verification = .requestError(
                    errorEvent.eraseToRepr())
                
                var effects = [Effect<IAPAction>]()
                
                // PsiCash RefreshState is most likely needed if a 4xx status code
                // is returned from the purchase-verifier server. E.g. user's token's
                // might have been expired.
                if
                    case .errorStatusCode(let responseMetadata) = errorEvent.error,
                    case .clientError = responseMetadata.statusCode.responseType
                {
                    
                    effects += environment.psiCashStore(.refreshPsiCashState())
                        .mapNever()
                    
                }
                
                effects += environment.feedbackLogger.log(.error, """
                        verification failed: '\(errorEvent)'\
                        transaction: '\(requestTransaction)'
                        """).mapNever()
                
                return effects
            }
        }
        
    case .transactionUpdate(.restoredCompletedTransactions(error: let maybeError)):
        if let error = maybeError {
            return [
                environment.feedbackLogger.log(
                    .error, "restore completed transactions failed: '\(error)'").mapNever()
            ]
        } else {
            return [
                environment.appReceiptStore(._remoteReceiptRefreshResult(.success(.unit)))
                .mapNever()
            ]
        }
        
    case .transactionUpdate(.updatedTransactions(let updatedTransactions)):
        var effects = [Effect<IAPAction>]()
        
        for tx in updatedTransactions {
            
            guard let productType = environment.isSupportedProduct(tx.productID()) else {
                // Transactions with unknown product ID should not happen in production,
                // and hence `finishTransaction(_:)` is not called on them.
                effects += environment.feedbackLogger
                    .log(.error, "unknown product id '\(tx.productID())'") .mapNever()
                
                continue
            }
            
            effects +=
                environment.feedbackLogger.log(
                    .info, "transactionUpdate: '\(makeFeedbackEntry(tx))'").mapNever()
            
            let iapPurchasingResult = IAPPurchasing.makeGiven(
                productType: productType,
                transaction: tx,
                existingConsumableTransaction: { paymentTx -> Bool? in
                    guard let existingTransaction = state.iap.unfinishedPsiCashTx else {
                        return nil
                    }
                    
                    guard
                        case .completed(.success(let completedTx)) = paymentTx.transactionState()
                    else {
                        return false
                    }
                    
                    return existingTransaction.completedTransaction.paymentTransactionID ==
                        completedTx.paymentTransactionID
                },
                getCurrentTime: environment.getCurrentTime
            )
            
            // Updates purchasing state based on result of IAPPurchasing.makeGiven.
            switch iapPurchasingResult {
            case let .success(.unique(iapPurchasing, maybeUnfinishedConsumableTx)):
                
                state.iap.purchasing[productType] = iapPurchasing
                
                if let unfinishedTx = maybeUnfinishedConsumableTx {
                    state.iap.unfinishedPsiCashTx = unfinishedTx
                    state.psiCashBalance.waitingForExpectedIncrease(
                        withAddedReward: .zero,
                        reason: .purchasedPsiCash,
                        persisted: environment.psiCashPersistedValues
                    )
                    
                    effects += environment.feedbackLogger.log(.info, """
                            new IAP transaction: '\(makeFeedbackEntry(tx))'
                            """)
                        .mapNever()
                }
                
            case .success(.duplicate):
                // There is already an existing unfinished consumable transaction.
                effects += environment.feedbackLogger.log(.warn, """
                        Transaction is a duplicate: '\(makeFeedbackEntry(tx))'
                        """)
                    .mapNever()
                
            case let .failure(fatalError):
                environment.feedbackLogger.fatalError(fatalError.message)
                return []
            }
            
            // Fulfills all pending purchase promise (if any)
            // for a complete subscription transaction.
            // precondition: `state.iap.purchasing[productType]` should be updated
            //               before the objcPromise is resolved.
            if case .completed(_) = tx.transactionState(), case .subscription = productType {
                let maybeError = state.iap.purchasing[productType]?.purchasingState.completed
                
                if state.iap.objcSubscriptionPromises.count > 0 {
                    fulfillAll(promises: state.iap.objcSubscriptionPromises,
                               with: ObjCIAPResult(transaction: tx.skPaymentTransaction()!,
                                                   error: maybeError))
                    
                    state.iap.objcSubscriptionPromises = []
                }
                
            }
            
            // Adds effect to finish current transaction `tx`.
            switch
                tx.transactionState().shouldFinishTransactionImmediately(productType: productType) {
            case .nop, .afterDeliverablesDelivered:
                break
            case .immediately:
                effects += environment.paymentQueue.finishTransaction(tx).mapNever()
            }
        }
        
        // Calls `environment.appReceiptStore` if the receipt has been updated
        // (i.e. a purchase was successful).
        if updatedTransactions.map({$0.transactionState().appReceiptUpdated}).contains(true) {
            
            effects += environment
                .appReceiptStore(._remoteReceiptRefreshResult(.success(.unit)))
                .mapNever()
        }
        
        return effects
    }
}
