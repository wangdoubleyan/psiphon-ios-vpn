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
import PsiApi
import AppStoreIAP
import class PsiphonClientCommonLibrary.Region

extension TunnelProviderVPNStatus: CustomStringFeedbackDescription {
    
    public var description: String {
        switch self {
        case .invalid: return "invalid"
        case .disconnected: return "disconnected"
        case .connecting: return "connecting"
        case .connected: return "connected"
        case .reasserting: return "reasserting"
        case .disconnecting: return "disconnecting"
        @unknown default: return "unknown(\(self.rawValue)"
        }
    }
    
}

extension TunnelProviderSyncReason: CustomStringFeedbackDescription {
    
    public var description: String {
        switch self {
        case .appLaunched:
            return "appLaunched"
        case .appEnteredForeground:
            return "appEnteredForeground"
        case .providerNotificationPsiphonTunnelConnected:
            return "providerNotificationPsiphonTunnelConnected"
        }
    }
    
}

extension UserDefaultsConfig: CustomFieldFeedbackDescription {
    
    var feedbackFields: [String: CustomStringConvertible] {
        [
            "expectedPsiCashReward": self.expectedPsiCashReward,
            "appLanguage": self.appLanguage,
            "onboarding_stages_completed": self.onboardingStagesCompleted,
            "LastCFBundleVersion": self.lastBundleVersion
        ]
    }
    
}

extension PsiphonDataSharedDB: CustomFieldFeedbackDescription {
    
    public var feedbackFields: [String: CustomStringConvertible] {
        
        var fields: [String: CustomStringConvertible] = [
            
            EgressRegionsStringArrayKey: String(describing: self.emittedEgressRegions()),
            
            ClientRegionStringKey:  String(describing: self.emittedClientRegion()),
            
            TunnelStartTimeStringKey: String(describing: self.getContainerTunnelStartTime()),
            
            TunnelSponsorIDStringKey:  String(describing: self.getCurrentSponsorId()),
            
            ServerTimestampStringKey: String(describing: self.getServerTimestamp()),
            
            ExtensionIsZombieBoolKey: self.getExtensionIsZombie(),
            
            ContainerForegroundStateBoolKey: self.getAppForegroundState(),
            
            ContainerTunnelIntentStatusIntKey: TunnelStartStopIntent.description(integerCode:
                self.getContainerTunnelIntentStatus()),
            
            ExtensionDisallowedTrafficAlertWriteSeqIntKey:
                self.getDisallowedTrafficAlertWriteSequenceNum(),
            
            ContainerDisallowedTrafficAlertReadAtLeastUpToSeqIntKey:
                self.getContainerDisallowedTrafficAlertReadAtLeastUpToSequenceNum()
        ]
        
        #if DEBUG
        fields[DebugMemoryProfileBoolKey] = String(describing: self.getDebugMemoryProfiler())
        fields[DebugPsiphonConnectionStateStringKey] = self.getDebugPsiphonConnectionState()
        #endif
        
        return fields
    }
    
    open override var description: String {
        self.objcClassDescription()
    }
    
}

extension UserFeedback: CustomFieldFeedbackDescription {

    public var feedbackFields: [String: CustomStringConvertible] {
        ["uploadDiagnostics": uploadDiagnostics,
         "submitTime": submitTime]
    }

}

extension Region {
    open override var description: String {
        "Region(code: \(String(describing: code)), serverExists: \(serverExists))"
    }
}
