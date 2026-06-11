import XCTest

/// Déroule le tuto interactif de bout en bout avec de vrais taps.
/// C'est LE test anti-régression du spotlight : si les bandes bloqueuses
/// recouvrent la zone éclairée, les taps n'atteignent plus l'interface
/// et le test échoue à l'étape correspondante.
final class TutorielUITests: XCTestCase {

    @MainActor
    func testLeTutoSeDerouleDeBoutEnBout() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-uitests",                  // store en mémoire + produit « Stylos test »
            "-onboardingTermine", "YES", // on saute l'onboarding
            "-tutorielTermine", "NO",    // on force le tuto
        ]
        app.launch()

        // Étape 1 — bienvenue.
        let cestParti = app.buttons["C'est parti !"]
        XCTAssertTrue(cestParti.waitForExistence(timeout: 10), "La carte de bienvenue doit apparaître")
        cestParti.tap()

        // Étape 2 — choisir un lieu : la puce DOIT être touchable dans le trou.
        let chezMoi = app.buttons["Chez moi"].firstMatch
        XCTAssertTrue(chezMoi.waitForExistence(timeout: 5))
        chezMoi.tap()

        // Étape 3 — ranger : le tap sur la puce a dû faire avancer le tuto.
        XCTAssertTrue(
            app.staticTexts["Range une boîte"].waitForExistence(timeout: 5),
            "Le tap sur « Chez moi » doit traverser le spotlight et faire avancer le tuto"
        )
        let plus = app.buttons["Ranger une unité"].firstMatch
        XCTAssertTrue(plus.waitForExistence(timeout: 5))
        plus.tap()

        // Étape 4 — consommer.
        XCTAssertTrue(app.staticTexts["Et quand tu en utilises…"].waitForExistence(timeout: 5))
        let moins = app.buttons["Utiliser une unité"].firstMatch
        XCTAssertTrue(moins.waitForExistence(timeout: 5))
        moins.tap()

        // Étape 5 — ouvrir la fiche produit.
        XCTAssertTrue(app.staticTexts["La fiche complète"].waitForExistence(timeout: 5))
        app.staticTexts["Stylos test"].firstMatch.tap()
        XCTAssertTrue(
            app.staticTexts["Lots & péremptions"].waitForExistence(timeout: 5),
            "La fiche produit doit s'ouvrir à travers le spotlight"
        )
        app.navigationBars.buttons.firstMatch.tap() // retour

        // Étape 6 — fin.
        XCTAssertTrue(app.staticTexts["À toi de jouer !"].waitForExistence(timeout: 5))
        app.buttons["Terminer la visite"].tap()
        XCTAssertFalse(app.staticTexts["À toi de jouer !"].exists, "L'overlay doit disparaître")
    }

    @MainActor
    func testChaqueEtapePeutEtreSautee() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uitests", "-onboardingTermine", "YES", "-tutorielTermine", "NO"]
        app.launch()

        app.buttons["C'est parti !"].firstMatch.tap()

        // On saute toutes les étapes à geste : impossible de rester coincé.
        for _ in 0..<4 {
            let passer = app.buttons["Passer cette étape"].firstMatch
            XCTAssertTrue(passer.waitForExistence(timeout: 5), "Chaque étape à geste doit offrir une sortie")
            passer.tap()
        }

        XCTAssertTrue(app.staticTexts["À toi de jouer !"].waitForExistence(timeout: 5))
        app.buttons["Terminer la visite"].tap()
    }
}
