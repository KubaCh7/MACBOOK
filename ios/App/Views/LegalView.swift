import SwiftUI

/// Dokumenty prawne — ta sama treść co na stronie. Pełna wersja z danymi właściciela jest na stronie
/// (właściciel i kontakt pochodzą ze zmiennych środowiskowych Vercela, nie z kodu).
struct LegalView: View {
    enum Doc { case privacy, terms, info }
    let doc: Doc

    private var title: String {
        switch doc {
        case .privacy: return L.t("privacy")
        case .terms: return L.t("terms")
        case .info: return L.t("info")
        }
    }

    private var sections: [(String, String)] {
        let pl = L.lang == "pl"
        switch doc {
        case .privacy:
            return pl ? [
                ("Administrator danych", "Administratorem jest właściciel aplikacji. Dane kontaktowe są w zakładce Informacje na stronie aplikacji."),
                ("Jakie dane", "Przy koncie: e-mail, imię, cele (nazwa, cena, zdjęcie i kadr) oraz wpłaty i wypłaty (kwota, data, notatka). Bez konta dane zostają tylko na tym iPhonie."),
                ("Cel i podstawa", "Wyłącznie działanie aplikacji i synchronizacja między stroną, iPhone'em i widżetami (art. 6 ust. 1 lit. b RODO)."),
                ("Gdzie", "Supabase w Unii Europejskiej (Frankfurt). Zdjęcia w prywatnym zasobniku dostępnym tylko dla Ciebie."),
                ("Twoje prawa", "Dostęp, przeniesienie (Ustawienia → Eksportuj do JSON), sprostowanie, usunięcie (Ustawienia → Usuń konto), skarga do Prezesa UODO."),
                ("Jak długo", "Dopóki masz konto. Usunięcie konta usuwa wszystkie dane i zdjęcia."),
            ] : [
                ("Controller", "The app owner. Contact details are under Information on the app's website."),
                ("What we store", "With an account: email, name, goals (name, price, photo and crop), deposits and withdrawals. Without an account data stays on this iPhone."),
                ("Purpose and basis", "Only to run the app and sync it between the website, iPhone and widgets (Art. 6(1)(b) GDPR)."),
                ("Where", "Supabase in the EU (Frankfurt). Photos in a private bucket only you can read."),
                ("Your rights", "Access, portability (Settings → Export to JSON), correction, deletion (Settings → Delete account), complaint to the supervisory authority."),
                ("Retention", "As long as you keep the account. Deleting it removes all data and photos."),
            ]
        case .terms:
            return pl ? [
                ("Usługa", "Bezpłatne, osobiste narzędzie do planowania oszczędności. Nie przechowuje pieniędzy i nie jest doradztwem finansowym."),
                ("Ceny", "Ceny modeli są orientacyjne (polski Apple Store) i mogą być nieaktualne. Apple i MacBook to znaki towarowe Apple Inc.; aplikacja nie jest związana z Apple."),
                ("Konto", "Chroń hasło. Konto możesz usunąć w każdej chwili."),
                ("Odpowiedzialność", "Aplikacja w obecnej postaci. Prognozy to szacunki na podstawie Twoich wpisów."),
            ] : [
                ("The service", "A free personal savings planner. It holds no money and gives no financial advice."),
                ("Prices", "Approximate prices from the Polish Apple Store, possibly out of date. Apple and MacBook are trademarks of Apple Inc.; not affiliated with Apple."),
                ("Account", "Keep your password safe. You can delete the account at any time."),
                ("Liability", "Provided as is. Forecasts are estimates from your own entries."),
            ]
        case .info:
            return pl ? [
                ("O aplikacji", "macbook progress: strona, aplikacja na iPhone'a i widżety do odkładania na MacBooka."),
                ("Podmioty przetwarzające", "Supabase Inc. (baza danych, logowanie, zdjęcia; region UE), Vercel Inc. (hosting strony)."),
            ] : [
                ("About", "macbook progress: a website, an iPhone app and widgets for saving towards a MacBook."),
                ("Processors", "Supabase Inc. (database, sign-in, photos; EU region), Vercel Inc. (website hosting)."),
            ]
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(sections, id: \.0) { s in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(s.0).font(.system(size: 16, weight: .semibold))
                        Text(s.1).font(.system(size: 15)).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .screenBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
