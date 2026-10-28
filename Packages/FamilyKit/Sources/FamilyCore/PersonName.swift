import Foundation

public enum PersonName {
    /// Up to two initials from a display name ("Emma Parker" → "EP", "Liam" → "L").
    public static func initials(of name: String) -> String {
        let words = name.split(whereSeparator: { $0.isWhitespace || $0 == "-" })
        let letters = words.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }

    /// Possessive form for labels like "Emma's soccer".
    public static func possessive(_ name: String) -> String {
        "\(name)’s"
    }
}

public enum MoneyFormat {
    /// Formats an amount stored in minor units (cents) for display.
    public static func string(minorUnits: Int, currencyCode: String = Locale.current.currency?.identifier ?? "USD") -> String {
        let value = Decimal(minorUnits) / 100
        return value.formatted(.currency(code: currencyCode))
    }
}
