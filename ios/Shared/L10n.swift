import Foundation

/// Teksty PL/EN. Język wybiera się w aplikacji (także na ekranie logowania).
enum L {
    static var defaults: UserDefaults { UserDefaults(suiteName: SharedStore.groupID) ?? .standard }
    static var lang: String { defaults.string(forKey: "lang") ?? "pl" }
    static var locale: Locale { Locale(identifier: lang == "pl" ? "pl_PL" : "en_GB") }

    static func t(_ key: String, _ vars: [String: String] = [:]) -> String {
        var s = (lang == "pl" ? pl[key] : en[key]) ?? pl[key] ?? key
        for (k, v) in vars { s = s.replacingOccurrences(of: "{\(k)}", with: v) }
        return s
    }

    static func monthYear(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.setLocalizedDateFormatFromTemplate("LLLLyyyy")
        return f.string(from: d)
    }

    static func monthShort(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.setLocalizedDateFormatFromTemplate("LLL")
        return f.string(from: d).replacingOccurrences(of: ".", with: "")
    }

    static func dayMonth(_ day: String) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.setLocalizedDateFormatFromTemplate("dMMM")
        return f.string(from: Day.date(day)).replacingOccurrences(of: ".", with: "")
    }

    static func plural(_ n: Int, pl forms: (String, String, String), en: (String, String)) -> String {
        if lang != "pl" { return "\(n) \(n == 1 ? en.0 : en.1)" }
        if n == 1 { return "\(n) \(forms.0)" }
        let m10 = n % 10, m100 = n % 100
        if (2 ... 4).contains(m10) && !(12 ... 14).contains(m100) { return "\(n) \(forms.1)" }
        return "\(n) \(forms.2)"
    }

    static let pl: [String: String] = [
        "appName": "macbook progress",
        "tagline": "Odkładaj na MacBooka i zobacz, w którym miesiącu go kupisz.",
        "tabStart": "Start", "tabDeposits": "Wpłaty", "tabGoals": "Cele", "tabSettings": "Ustawienia",
        "signIn": "Zaloguj się", "signUp": "Załóż konto", "email": "E-mail", "password": "Hasło", "name": "Imię",
        "passwordHint": "Co najmniej 6 znaków.", "continueWithout": "Kontynuuj bez konta",
        "withoutHint": "Dane zostaną tylko na tym iPhonie.", "checkEmail": "Sprawdź skrzynkę i kliknij link potwierdzający, potem zaloguj się.",
        "language": "Język",
        "onbTitle": "Na co odkładasz?", "onbSub": "Wybierz MacBooka z listy albo wpisz własny cel. Nazwę i cenę możesz zmienić.",
        "customGoal": "Własny cel", "search": "Szukaj modelu", "sortPopular": "Popularne", "sortModel": "Model", "sortPrice": "Cena",
        "priceNote": "Ceny orientacyjne z apple.com/pl", "goalName": "Nazwa", "goalPrice": "Cena (zł)", "startSaving": "Zacznij odkładać",
        "forecast": "Prognoza zakupu: {month}, przy tempie {pace} miesięcznie",
        "forecastNone": "Prognoza zakupu pojawi się po pierwszej wpłacie", "forecastDone": "Uzbierane. Możesz kupić",
        "progress": "Postęp", "saved": "Uzbierane", "price": "Cena", "left": "Brakuje",
        "thisMonth": "W tym miesiącu", "pace": "Tempo", "perMonth": "/mies.", "avgDeposit": "Średnia wpłata", "depositCount": "Liczba wpłat",
        "changePrice": "Zmień cenę", "cumulative": "Uzbierane narastająco", "forecastLegend": "prognoza", "priceLine": "cena",
        "recent": "Ostatnie wpłaty", "noDeposits": "Nie ma jeszcze wpłat. Pierwsza wpłata uruchomi prognozę.",
        "addDeposit": "Dodaj wpłatę", "addPhoto": "Dodaj zdjęcie", "fromGallery": "Galeria", "fromCamera": "Aparat", "fromLink": "Z linku",
        "removePhoto": "Usuń zdjęcie", "changePhoto": "Zmień zdjęcie", "adjustCrop": "Ustaw kadr", "done": "Gotowe", "use": "Użyj",
        "monthly": "Miesięcznie", "deposits": "Wpłaty", "withdrawals": "Wypłaty", "history": "Historia", "summary": "Podsumowanie",
        "totalIn": "Wpłaty razem", "totalOut": "Wypłaty razem", "largest": "Największa wpłata",
        "date": "Data", "note": "Notatka", "amount": "Kwota", "edit": "Edytuj", "delete": "Usuń",
        "deposit": "Wpłata", "withdrawal": "Wypłata", "newDeposit": "Nowa wpłata", "editDeposit": "Edytuj wpis",
        "save": "Zapisz", "savedStamp": "Zapisano", "cancel": "Anuluj", "maxWithdraw": "Możesz wypłacić najwyżej {max}.", "amountInvalid": "Wpisz kwotę większą od zera.",
        "newPrice": "Nowa cena (zł)", "next": "Dalej", "back": "Wstecz", "confirmPriceChange": "Cena zmieni się z {from} na {to}.",
        "difference": "Różnica", "willBeLeft": "Będzie brakować", "yesChange": "Tak, zmień cenę",
        "addGoal": "Dodaj cel", "main": "Główny", "setMain": "Ustaw jako główny", "editGoal": "Edytuj cel", "newGoal": "Nowy cel",
        "deleteGoal": "Usuń cel", "deleteGoalQ": "Usunąć cel „{name}” razem z jego wpłatami?", "suggestions": "Podpowiedzi z Apple Store",
        "ofPrice": "z {price}", "yourGoals": "Twoje cele",
        "profile": "Profil", "appearance": "Wygląd", "theme": "Motyw", "themeSystem": "Systemowy", "themeLight": "Jasny", "themeDark": "Ciemny",
        "sounds": "Dźwięki", "soundsDesc": "Ciche kliknięcia, moneta przy wpłacie. Wyciszony iPhone milczy.",
        "data": "Dane", "exportJson": "Eksportuj do JSON", "documents": "Dokumenty", "account": "Konto",
        "signOut": "Wyloguj", "deleteAccount": "Usuń konto", "deleteLocal": "Usuń dane z iPhone'a",
        "deleteAccountQ": "Usunąć konto i wszystkie dane (cele, wpłaty, zdjęcia)? Tego nie da się cofnąć.",
        "createAccount": "Załóż konto lub zaloguj się", "localDesc": "Dane są tylko na tym iPhonie. Załóż konto, aby mieć je też na stronie.",
        "privacy": "Polityka prywatności", "terms": "Regulamin", "info": "Informacje",
        "updateTitle": "Dostępna nowa wersja", "updateBody": "Na Macu otwórz Terminal, wklej komendę, potem w Xcode wybierz Product → Clean Build Folder i naciśnij ▶.",
        "copy": "Kopiuj", "copied": "Skopiowano", "syncing": "Synchronizacja…", "offline": "Brak połączenia. Zmiany wyślą się później.",
        "error": "Coś poszło nie tak: {msg}", "lastSync": "Zsynchronizowano {time}", "syncNow": "Synchronizuj teraz",
        "showPhoto": "Pokaż zdjęcie", "widgetDesc": "Postęp głównego celu.", "version": "Wersja",
    ]

    static let en: [String: String] = [
        "appName": "macbook progress",
        "tagline": "Save for a MacBook and see the month you can buy it.",
        "tabStart": "Start", "tabDeposits": "Deposits", "tabGoals": "Goals", "tabSettings": "Settings",
        "signIn": "Sign in", "signUp": "Create account", "email": "Email", "password": "Password", "name": "Name",
        "passwordHint": "At least 6 characters.", "continueWithout": "Continue without an account",
        "withoutHint": "Data stays on this iPhone only.", "checkEmail": "Check your inbox and click the confirmation link, then sign in.",
        "language": "Language",
        "onbTitle": "What are you saving for?", "onbSub": "Pick a MacBook or type your own goal. You can change the name and price.",
        "customGoal": "Custom goal", "search": "Search models", "sortPopular": "Popular", "sortModel": "Model", "sortPrice": "Price",
        "priceNote": "Approximate prices from apple.com/pl", "goalName": "Name", "goalPrice": "Price (PLN)", "startSaving": "Start saving",
        "forecast": "Purchase forecast: {month}, at {pace} a month",
        "forecastNone": "The purchase forecast appears after your first deposit", "forecastDone": "Fully saved. You can buy it",
        "progress": "Progress", "saved": "Saved", "price": "Price", "left": "Left",
        "thisMonth": "This month", "pace": "Pace", "perMonth": "/mo", "avgDeposit": "Average deposit", "depositCount": "Deposits",
        "changePrice": "Change price", "cumulative": "Saved over time", "forecastLegend": "forecast", "priceLine": "price",
        "recent": "Recent deposits", "noDeposits": "No deposits yet. The first one starts the forecast.",
        "addDeposit": "Add deposit", "addPhoto": "Add photo", "fromGallery": "Gallery", "fromCamera": "Camera", "fromLink": "From link",
        "removePhoto": "Remove photo", "changePhoto": "Change photo", "adjustCrop": "Adjust crop", "done": "Done", "use": "Use",
        "monthly": "Monthly", "deposits": "Deposits", "withdrawals": "Withdrawals", "history": "History", "summary": "Summary",
        "totalIn": "Total deposited", "totalOut": "Total withdrawn", "largest": "Largest deposit",
        "date": "Date", "note": "Note", "amount": "Amount", "edit": "Edit", "delete": "Delete",
        "deposit": "Deposit", "withdrawal": "Withdrawal", "newDeposit": "New deposit", "editDeposit": "Edit entry",
        "save": "Save", "savedStamp": "Saved", "cancel": "Cancel", "maxWithdraw": "You can withdraw at most {max}.", "amountInvalid": "Enter an amount above zero.",
        "newPrice": "New price (PLN)", "next": "Next", "back": "Back", "confirmPriceChange": "The price changes from {from} to {to}.",
        "difference": "Difference", "willBeLeft": "Left to save", "yesChange": "Yes, change price",
        "addGoal": "Add goal", "main": "Main", "setMain": "Set as main", "editGoal": "Edit goal", "newGoal": "New goal",
        "deleteGoal": "Delete goal", "deleteGoalQ": "Delete “{name}” with all its deposits?", "suggestions": "Apple Store suggestions",
        "ofPrice": "of {price}", "yourGoals": "Your goals",
        "profile": "Profile", "appearance": "Appearance", "theme": "Theme", "themeSystem": "System", "themeLight": "Light", "themeDark": "Dark",
        "sounds": "Sounds", "soundsDesc": "Quiet clicks, a coin on deposit. A muted iPhone stays silent.",
        "data": "Data", "exportJson": "Export to JSON", "documents": "Documents", "account": "Account",
        "signOut": "Sign out", "deleteAccount": "Delete account", "deleteLocal": "Delete data on this iPhone",
        "deleteAccountQ": "Delete the account and all data (goals, deposits, photos)? This cannot be undone.",
        "createAccount": "Create an account or sign in", "localDesc": "Data lives on this iPhone only. Create an account to see it on the website too.",
        "privacy": "Privacy policy", "terms": "Terms", "info": "Information",
        "updateTitle": "A new version is available", "updateBody": "On your Mac open Terminal, paste the command, then in Xcode choose Product → Clean Build Folder and press ▶.",
        "copy": "Copy", "copied": "Copied", "syncing": "Syncing…", "offline": "Offline. Changes will be sent later.",
        "error": "Something went wrong: {msg}", "lastSync": "Synced {time}", "syncNow": "Sync now",
        "showPhoto": "Show photo", "widgetDesc": "Progress of your main goal.", "version": "Version",
    ]
}
