// LocumTracker
// Copyright (C) 2025 Dr Horst Herb
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

/// Service for resolving session templates from assignment and location sources
public struct SessionTemplateService {

    /// Resolves the effective session templates for an assignment.
    ///
    /// Priority order:
    /// 1. If `preferLocationTemplates` is true and location has templates, use location templates
    /// 2. Otherwise, if assignment has templates, use assignment templates
    /// 3. Finally, fall back to location templates
    ///
    /// - Parameters:
    ///   - assignmentTemplates: Templates defined on the assignment
    ///   - locationTemplates: Templates defined on the primary location
    ///   - preferLocationTemplates: If true, prefer location templates over assignment templates
    /// - Returns: The effective templates to use for session creation
    public static func resolveTemplates(
        assignmentTemplates: [DefaultSessionTemplate],
        locationTemplates: [DefaultSessionTemplate],
        preferLocationTemplates: Bool = false
    ) -> [DefaultSessionTemplate] {
        if preferLocationTemplates && !locationTemplates.isEmpty {
            return locationTemplates
        }
        if !assignmentTemplates.isEmpty {
            return assignmentTemplates
        }
        return locationTemplates
    }

    /// Determines which source the templates are coming from.
    ///
    /// - Parameters:
    ///   - assignmentTemplates: Templates defined on the assignment
    ///   - locationTemplates: Templates defined on the primary location
    ///   - preferLocationTemplates: If true, prefer location templates over assignment templates
    /// - Returns: The source of the resolved templates
    public static func resolveTemplateSource(
        assignmentTemplates: [DefaultSessionTemplate],
        locationTemplates: [DefaultSessionTemplate],
        preferLocationTemplates: Bool = false
    ) -> TemplateSource {
        if preferLocationTemplates && !locationTemplates.isEmpty {
            return .location
        }
        if !assignmentTemplates.isEmpty {
            return .assignment
        }
        if !locationTemplates.isEmpty {
            return .location
        }
        return .none
    }
}

/// Indicates where session templates originate from
public enum TemplateSource {
    case assignment
    case location
    case none

    public var description: String {
        switch self {
        case .assignment: return "Assignment"
        case .location: return "Location"
        case .none: return "None"
        }
    }
}
