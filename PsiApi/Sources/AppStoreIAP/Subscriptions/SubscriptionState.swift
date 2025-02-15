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
import PsiApi

public enum SubscriptionStatus: Equatable {
    case subscribed(SubscriptionIAPPurchase)
    case notSubscribed
    case unknown
}

public struct SubscriptionState: Equatable {
    
    public var status: SubscriptionStatus
    
    public init(status: SubscriptionStatus = .unknown) {
        self.status = status
    }
    
}

public enum SubscriptionAction {
    case appReceiptDataUpdated(ReceiptData?)
    case _timerFinished(withExpiry:Date)
}

extension SubscriptionAction: Equatable {}

public typealias SubscriptionReducerEnvironment = (
    feedbackLogger: FeedbackLogger,
    appReceiptStore: (ReceiptStateAction) -> Effect<Never>,
    dateCompare: DateCompare,
    singleFireTimer:
    (_ interval: TimeInterval, _ leeway: DispatchTimeInterval) -> Effect<()>
)

/// Note that `subscriptionTimerReducer` bases it's timer on the latest subscription
/// transaction available in the receipt, and it's state is currently
/// independent of `subscriptionAuthStateReducer`.
public let subscriptionTimerReducer = Reducer<SubscriptionState
                                         , SubscriptionAction
                                         , SubscriptionReducerEnvironment> {
    state, action, environment in
    
    switch action {
    case .appReceiptDataUpdated(let receipt):
        guard let subscriptionPurchases = receipt?.subscriptionInAppPurchases else {
            state.status = .notSubscribed
            return []
        }
        
        guard let purchaseWithLatestExpiry = subscriptionPurchases.sortedByExpiry().last else {
            state.status = .notSubscribed
            return []
        }
        
        let isExpired = purchaseWithLatestExpiry.isApproximatelyExpired(environment.dateCompare)
        guard !isExpired else {
            state.status = .notSubscribed
            return []
        }
            
        let timeLeft = purchaseWithLatestExpiry.expires.timeIntervalSinceNow
        guard timeLeft > SubscriptionHardCodedValues.subscriptionUIMinTime else {
            state.status = .notSubscribed
            return []
        }
                
        state.status = .subscribed(purchaseWithLatestExpiry)

        return [
            environment.singleFireTimer(timeLeft,
                                        SubscriptionHardCodedValues.leeway)
                .map(value: ._timerFinished(withExpiry: purchaseWithLatestExpiry.expires)),
            environment.feedbackLogger.log(.info,
                "subscribed: timer expiring on: '\(purchaseWithLatestExpiry.expires)'"
            ).mapNever()
        ]
        
        
    case ._timerFinished(withExpiry: let expiry):
        /// To control for the race condition where an `.updatedReceiptData` action is received
        /// immediately before a `._timerFinished` event, the expiration dates are compared.
        /// If the current subscription data has a later expiry date than the expiry date in
        /// `._timerFinished` associated value, then we ignore the message.
        guard case let .subscribed(subscriptionPurchase) = state.status else {
            return []
        }
        
        let timerExpiry: TimeInterval = expiry.timeIntervalSinceNow
        let subscriptionExpiry: TimeInterval = subscriptionPurchase.expires.timeIntervalSinceNow
        let tolerance = SubscriptionHardCodedValues.subscriptionTimerDiffTolerance
        
        // Changes state to `.notSubscribed` only if timers expiry matches
        // current subscription expiry value.
        if abs(timerExpiry - subscriptionExpiry) < tolerance {
            state.status = .notSubscribed
        }
        
        return [
            environment.appReceiptStore(.remoteReceiptRefresh(optionalPromise: nil)).mapNever(),
            environment.feedbackLogger.log(.info, "subscription expired").mapNever()
        ]
    }
}
