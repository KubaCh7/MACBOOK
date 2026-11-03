# macbook progress

Odkładaj pieniądze na MacBooka i zobacz, w którym miesiącu go kupisz.

| Część | Folder | Co to jest |
| --- | --- | --- |
| Strona (PWA) | `web/` | Vite + React + TypeScript, hosting na Vercelu (wdraża się sam z gałęzi `main`) |
| iPhone + widżety | `ios/` | Projekt Xcode: aplikacja SwiftUI (SwiftData, działa offline) i widżety WidgetKit (też na Macu) |
| Baza danych | `supabase/` | Migracje Supabase: tabele, zabezpieczenia RLS, zdjęcia, katalog MacBooków |

Wszystkie wersje mają to samo: logowanie e-mailem (albo tryb bez konta), cele z gwiazdką „główny”,
wpłaty i wypłaty, zmianę ceny w dwóch krokach, zdjęcie celu z kadrem, prognozę zakupu, wykresy,
ciche dźwięki, PL/EN, motyw jasny/ciemny, eksport do JSON i usunięcie konta.

**Bez kluczy w repo.** Klucze Supabase są tylko w `web/.env` i `ios/Config/Secrets.xcconfig`
(oba w `.gitignore`); w repo są wzory `.example`. Na Vercelu są ustawione jako zmienne środowiskowe.

---

## Poradnik instalacji na iPhonie (krok po kroku)

Potrzebujesz: Maca z Xcode, iPhone'a, kabla USB i darmowego konta Apple ID.

### 1. Xcode i Apple ID

1. Otwórz **App Store** na Macu, wyszukaj **Xcode**, kliknij **Pobierz** (to duży plik, trochę potrwa).
2. Uruchom Xcode. Zgódź się na instalację dodatkowych składników.
3. W menu u góry: **Xcode → Settings… → Accounts**. Kliknij **+** w lewym dolnym rogu → **Apple ID** → zaloguj się.
   Pojawi się zespół „**Twoje Imię (Personal Team)**”.

### 2. Pobranie projektu i plik z kluczami

Otwórz **Terminal** (Cmd+Spacja, wpisz „Terminal”, Enter) i wklej po kolei:

```bash
cd ~/Documents && git clone https://github.com/KubaCh7/MACBOOK.git
```

Jeśli Mac zapyta o „narzędzia wiersza poleceń” — kliknij **Zainstaluj** i powtórz komendę.

Teraz utwórz plik z kluczami. Gotową komendę z prawdziwym adresem i kluczem dostałeś w czacie
(klucze nie są trzymane w repozytorium). Wzór — podmień `TWOJ-PROJEKT`, `sb_publishable_...`
(Supabase → Project Settings → API Keys) i **`twojeimie`** na coś swojego, np. `jankowalski`
(tylko małe litery, bez spacji i polskich znaków):

```bash
cat > ~/Documents/MACBOOK/ios/Config/Secrets.xcconfig <<'EOF'
SUPABASE_HOST = TWOJ-PROJEKT.supabase.co
SUPABASE_PUBLISHABLE_KEY = sb_publishable_...
BUNDLE_ID_PREFIX = com.twojeimie
EOF
```

Bez tego pliku aplikacja też się zbuduje, ale będzie działać tylko w trybie „bez konta”.

Otwórz projekt:

```bash
open ~/Documents/MACBOOK/ios/MacbookProgress.xcodeproj
```

### 3. Podpisywanie (Team)

1. W Xcode po lewej kliknij niebieską ikonę **MacbookProgress** (na samej górze listy plików).
2. W środkowej części, w sekcji **TARGETS**, kliknij **MacbookProgress**, potem kartę **Signing & Capabilities**.
3. Zaznacz **Automatically manage signing**, a w polu **Team** wybierz **Twoje Imię (Personal Team)**.
4. To samo zrób dla drugiego targetu: **MacbookProgressWidgets**.

### 4. Podłączenie iPhone'a

1. Podłącz iPhone'a kablem do Maca. Na iPhonie dotknij **Ufaj temu komputerowi** i wpisz kod.
2. Na iPhonie: **Ustawienia → Prywatność i ochrona → Tryb dewelopera** → włącz, iPhone się uruchomi ponownie,
   potem potwierdź **Włącz**. (Opcja pojawia się dopiero po podłączeniu do Xcode.)
3. W Xcode u góry, obok przycisku ▶, kliknij nazwę urządzenia i wybierz **swojego iPhone'a**.
4. Naciśnij **▶** (albo Cmd+R). Gdy Mac zapyta o hasło do pęku kluczy — wpisz hasło do Maca
   i kliknij **Always Allow** (Zawsze pozwalaj); może zapytać 2–3 razy.

### 5. Zaufanie dla aplikacji na iPhonie

Przy pierwszym uruchomieniu iPhone pokaże „Niezaufany deweloper”. Wejdź w
**Ustawienia → Ogólne → VPN i urządzenia zarządzane** → kliknij swój Apple ID → **Ufaj**.
Wróć do Xcode i naciśnij ▶ jeszcze raz.

**Widżety:** przytrzymaj palec na ekranie początkowym → **Edytuj → Dodaj widżet** → „macbook progress”.
Na ekranie blokady: przytrzymaj ekran blokady → **Dostosuj** → dotknij miejsca na widżety.
Opcję **Pokaż zdjęcie** zmienisz, przytrzymując widżet → **Edytuj widżet**.

### 6. Aktualizacja (gdy w aplikacji pojawi się „Dostępna nowa wersja”)

```bash
cd ~/Documents/MACBOOK && git checkout -- . && git pull
```

Potem w Xcode: ponownie wybierz **Team** w obu targetach (krok 3), **Product → Clean Build Folder**
(Shift+Cmd+K) i **▶**. Twoje dane zostają.

### 7. Instalacja na telefonie kolegi (inne Apple ID)

1. Kolega podłącza swojego iPhone'a kablem do **Twojego** Maca i dotyka **Ufaj**.
2. Kolega włącza **Tryb dewelopera** (krok 4.2).
3. W Xcode wybierasz u góry **jego iPhone'a** i naciskasz **▶** (podpisujesz swoim Personal Team).
4. Na jego iPhonie: **Ustawienia → Ogólne → VPN i urządzenia zarządzane → Ufaj**.

Limity darmowego konta: aplikacja działa **7 dni**, potem trzeba znów podłączyć telefon i nacisnąć ▶.
Darmowe konto pozwala na maksymalnie **3 aplikacje** naraz na jednym urządzeniu i ok. **10 identyfikatorów
aplikacji w tygodniu** — każde urządzenie z innym `BUNDLE_ID_PREFIX` zużywa nowe.

### 8. Ważne uwagi

- **Darmowe konto = 7 dni.** Po tym czasie aplikacja przestaje się otwierać — podłącz iPhone'a i naciśnij ▶.
  **Dane zostają** (są na iPhonie i, przy koncie, w Supabase).
- **TestFlight** (instalacja bez kabla, na 90 dni) i **plik DMG/aplikacja na Maca** wymagają płatnego
  konta **Apple Developer Program (99 USD rocznie)**. To opcja na później — wszystko inne działa za darmo.
- Aplikację z iPhone'a możesz też uruchomić na Macu z czipem Apple: w Xcode wybierz u góry
  **My Mac (Designed for iPad)** i ▶ (też 7 dni na darmowym koncie).

### 9. Wersja bez instalowania (najprościej)

Na iPhonie otwórz stronę w **Safari** → **Udostępnij** (kwadrat ze strzałką) → **Do ekranu początkowego**.
Na Macu: **Safari → Plik → Dodaj do Docka**. Działa jak aplikacja, aktualizuje się sama.

**Widżet z iPhone'a na biurku Maca** (macOS Sonoma lub nowszy, ten sam Apple ID, iPhone w pobliżu):
kliknij prawym na biurku → **Edytuj widżety** → włącz **Używaj widżetów iPhone'a** (Ustawienia systemowe →
Biurko i Dock) → przeciągnij widżet „macbook progress” na biurko.

---

## Dla programisty

**Strona:**

```bash
cd web && cp .env.example .env && npm install && npm run dev
```

Podgląd z przykładowymi danymi (tylko w tej przeglądarce): `http://localhost:5173/?demo`.

Zmienne na Vercelu: `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY`, `VITE_OWNER_NAME`,
`VITE_CONTACT_EMAIL` (dwie ostatnie — dane właściciela w dokumentach prawnych; nie wpisuj ich do kodu).
Projekt Vercela: Root Directory = `web`.

**Nowa wersja iOS:** zwiększ `APP_BUILD` w `ios/Config/Base.xcconfig`, a w Supabase:

```sql
update app_config set value = jsonb_set(value, '{latest_build}', '2') where key = 'ios_update';
```

**Supabase:** opis tabel w `supabase/README.md`. Logowanie e-mailem: w panelu Supabase
(Authentication → URL Configuration) ustaw **Site URL** na adres strony, żeby link z e-maila
potwierdzającego otwierał stronę. Jeśli wolisz bez potwierdzania e-maili: Authentication →
Sign In / Providers → Email → wyłącz **Confirm email**.

**Wygląd:** styl „achromatic ledger” (skill design-taste-frontend, `draw.mjs --app --kind wallet`):
tło #f8f8f8, płaskie białe karty, czarny przycisk główny, font Geist, jedyny kolor (#1d5fbf) na danych.
Sprawdzone `lint.mjs --app` i `inspect.mjs --app` na 1440 / 768 / 390 px.
