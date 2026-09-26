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

import SwiftUI

extension View {
    /// Adds a right-click "Delete" menu on macOS, where list rows have no
    /// swipe-to-delete or Edit mode. No-op on iOS.
    /// - Parameter action: Performs the deletion
    /// - Returns: The modified view
    @ViewBuilder
    func deleteContextMenu(_ action: @escaping () -> Void) -> some View {
        #if os(macOS)
        contextMenu {
            Button("Delete", role: .destructive, action: action)
        }
        #else
        self
        #endif
    }
}
