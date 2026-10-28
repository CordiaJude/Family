import Foundation
import SwiftData

/// Common shape of every model that syncs through CloudKit.
///
/// - `id` doubles as the CKRecord name.
/// - `ckSystemFields` holds the archived CKRecord system fields (change tag),
///   so a record sent back to the server carries the version it was based on.
/// - `dirtyFields` lists fields edited locally since the last successful send.
///   On a server conflict only these overwrite the server's values, which makes
///   last-writer-wins apply per field rather than per record.
public protocol SyncableModel: PersistentModel {
    var id: UUID { get }
    var householdID: UUID { get }
    var modifiedAt: Date { get set }
    var ckSystemFields: Data? { get set }
    var dirtyFields: [String] { get set }
}

extension SyncableModel {
    /// Records a local edit to `fields` for the sync engine.
    public func markDirty(_ fields: String..., at date: Date = .now) {
        for field in fields where !dirtyFields.contains(field) {
            dirtyFields.append(field)
        }
        modifiedAt = date
    }
}
