/*
 * Copyright (c) 2021, Psiphon Inc.
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

extension Locale {
    
    /// Returns valid BCP 47 language tag.
    /// Returned value does not include any private subtags, if Locale identifier
    /// contains any.
    /// https://tools.ietf.org/html/bcp47
    public var bcp47Identifier: String? {
        
        guard let languageDesignator = languageCode else {
            return nil
        }
        
        let scriptDesignator = (scriptCode != nil) ? "-\(scriptCode!)" : ""
        let regionDesignator = (regionCode != nil) ? "-\(regionCode!)" : ""
        
        return "\(languageDesignator)\(scriptDesignator)\(regionDesignator)"
        
    }
    
}
