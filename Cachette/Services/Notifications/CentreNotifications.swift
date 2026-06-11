import Foundation
import UserNotifications

/// Abstraction du centre de notifications — injectable dans les tests.
protocol CentreNotifications: Sendable {
    func demanderAutorisation() async -> Bool
    /// `date` nil = notification immédiate.
    func ajouter(id: String, titre: String, corps: String, date: Date?) async
    func retirerEnAttente(ids: [String]) async
    func idsEnAttente() async -> [String]
}

/// Implémentation système (UNUserNotificationCenter) — notifications 100 %
/// locales, aucun serveur de push (P0-6).
struct CentreNotificationsSysteme: CentreNotifications {
    func demanderAutorisation() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func ajouter(id: String, titre: String, corps: String, date: Date?) async {
        let contenu = UNMutableNotificationContent()
        contenu.title = titre
        contenu.body = corps
        contenu.sound = .default

        let declencheur: UNNotificationTrigger? = date.map { date in
            let composants = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: date
            )
            return UNCalendarNotificationTrigger(dateMatching: composants, repeats: false)
        }

        let requete = UNNotificationRequest(identifier: id, content: contenu, trigger: declencheur)
        try? await UNUserNotificationCenter.current().add(requete)
    }

    func retirerEnAttente(ids: [String]) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    func idsEnAttente() async -> [String] {
        await UNUserNotificationCenter.current().pendingNotificationRequests().map(\.identifier)
    }
}
