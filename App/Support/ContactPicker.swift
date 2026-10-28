import SwiftUI
import Contacts
import ContactsUI
import FamilyCore

/// Presents the system contact picker. The picker runs out of process, so the
/// app needs no Contacts permission: it only receives the people you choose.
struct ContactPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var allowsMultipleSelection: Bool
    var onSelect: ([CNContact]) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ host: UIViewController, context: Context) {
        let coordinator = context.coordinator
        coordinator.finish = { contacts in
            isPresented = false
            if !contacts.isEmpty { onSelect(contacts) }
        }
        guard isPresented, host.presentedViewController == nil, !coordinator.isPresenting else { return }
        coordinator.isPresenting = true
        let picker = CNContactPickerViewController()
        // The picker switches to multi-select when its delegate implements the
        // multiple-contacts callback, so each mode has its own delegate.
        picker.delegate = allowsMultipleSelection ? coordinator.multiple : coordinator.single
        // Present after the current SwiftUI update pass.
        Task { @MainActor in
            host.present(picker, animated: true)
            coordinator.isPresenting = false
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var finish: ([CNContact]) -> Void = { _ in }
        var isPresenting = false
        lazy var single = SingleDelegate { [unowned self] in self.finish($0) }
        lazy var multiple = MultipleDelegate { [unowned self] in self.finish($0) }
    }

    final class SingleDelegate: NSObject, CNContactPickerDelegate {
        let finish: ([CNContact]) -> Void
        init(finish: @escaping ([CNContact]) -> Void) { self.finish = finish }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) { finish([]) }
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) { finish([contact]) }
    }

    final class MultipleDelegate: NSObject, CNContactPickerDelegate {
        let finish: ([CNContact]) -> Void
        init(finish: @escaping ([CNContact]) -> Void) { self.finish = finish }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) { finish([]) }
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) { finish(contacts) }
    }
}

extension View {
    /// Presents the system contact picker when `isPresented` is true.
    func contactPicker(isPresented: Binding<Bool>, multiple: Bool = false, onSelect: @escaping ([CNContact]) -> Void) -> some View {
        background {
            ContactPicker(isPresented: isPresented, allowsMultipleSelection: multiple, onSelect: onSelect)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
    }
}

extension MemberDraft {
    /// Fills a draft from a contact: name, phone, birthday and photo when available.
    init(contact: CNContact, color: MemberColor) {
        self.init()
        self.color = color
        self.name = CNContactFormatter.string(from: contact, style: .fullName)
            ?? [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")

        if contact.isKeyAvailable(CNContactPhoneNumbersKey), let phone = contact.phoneNumbers.first?.value.stringValue {
            self.phone = phone
        }
        // Birthdays saved without a year can't tell us an age, so they're skipped.
        if contact.isKeyAvailable(CNContactBirthdayKey), let components = contact.birthday, components.year != nil {
            self.birthday = Calendar(identifier: .gregorian).date(from: components)
            self.role = MemberDraft.role(forBirthday: birthday)
        }
        let thumbnail = contact.isKeyAvailable(CNContactThumbnailImageDataKey) ? contact.thumbnailImageData : nil
        let image = contact.isKeyAvailable(CNContactImageDataKey) ? contact.imageData : nil
        if let photo = thumbnail ?? image {
            self.photo = photo
            self.avatarKind = .photo
        }
    }
}
