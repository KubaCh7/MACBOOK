import { useI18n } from '../lib/i18n'
import { owner } from '../lib/supabase'

type Doc = 'privacy' | 'terms' | 'info'

/** Dokumenty prawne. Dane właściciela pochodzą ze zmiennych środowiskowych (VITE_OWNER_NAME, VITE_CONTACT_EMAIL). */
export function Legal({ doc }: { doc: Doc }) {
  const { t, lang } = useI18n()
  const who = owner.name || (lang === 'pl' ? 'właściciel aplikacji' : 'the app owner')
  const contact = owner.email ? <a href={`mailto:${owner.email}`}>{owner.email}</a> : <span>{lang === 'pl' ? 'adres podany w ustawieniach wdrożenia' : 'the address set for this deployment'}</span>
  const updated = lang === 'pl' ? 'Ostatnia aktualizacja: 3 listopada 2026' : 'Last updated: 3 November 2026'

  if (lang === 'en') {
    return (
      <article className="doc">
        <h1>{t(doc)}</h1>
        <p className="sub">{updated}</p>
        {doc === 'privacy' && (
          <>
            <h2>Controller</h2>
            <p>The controller of personal data is {who}. Contact: {contact}.</p>
            <h2>What we store</h2>
            <p>With an account: your email address, the name you give, your goals (name, price, photo and its crop), deposits and withdrawals (amount, date, note). Without an account, data stays in your browser or on your iPhone only and is not sent to us.</p>
            <h2>Why and on what basis</h2>
            <p>Only to run the app for you: to sync your savings between the website, iPhone and widgets (Art. 6(1)(b) GDPR, performance of a contract).</p>
            <h2>Where</h2>
            <p>Data is hosted by Supabase in the EU (Frankfurt). The website is served by Vercel. Photos are stored in a private bucket readable only by you.</p>
            <h2>Your rights</h2>
            <p>You can access, export (Settings → Export to JSON), correct and delete your data (Settings → Delete account removes everything at once). You can complain to the Polish supervisory authority (PUODO).</p>
            <h2>Retention</h2>
            <p>As long as you keep the account. Deleted entries are removed with the account.</p>
            <h2>Cookies and storage</h2>
            <p>No tracking or advertising. The browser keeps your session and preferences (language, theme, sounds) in local storage.</p>
          </>
        )}
        {doc === 'terms' && (
          <>
            <h2>The service</h2>
            <p>macbook progress is a free personal tool for planning savings. It does not hold money, take payments or give financial advice.</p>
            <h2>Prices</h2>
            <p>Model prices are approximate, taken from the Polish Apple Store, and may be out of date. Apple and MacBook are trademarks of Apple Inc.; this app is not affiliated with Apple.</p>
            <h2>Your account</h2>
            <p>Keep your password safe. You can delete your account at any time in Settings.</p>
            <h2>Liability</h2>
            <p>The app is provided as is. Forecasts are estimates based on your own entries.</p>
            <h2>Contact</h2>
            <p>{contact}</p>
          </>
        )}
        {doc === 'info' && (
          <>
            <h2>About</h2>
            <p>macbook progress: a website, an iPhone app and widgets for saving towards a MacBook.</p>
            <h2>Owner</h2>
            <p>{who}. Contact: {contact}.</p>
            <h2>Data processors</h2>
            <p>Supabase Inc. (database, sign-in, photo storage; EU region), Vercel Inc. (website hosting).</p>
          </>
        )}
        <p><a className="card-link" href="#/">{t('backToApp')}</a></p>
      </article>
    )
  }

  return (
    <article className="doc">
      <h1>{t(doc)}</h1>
      <p className="sub">{updated}</p>
      {doc === 'privacy' && (
        <>
          <h2>Administrator danych</h2>
          <p>Administratorem danych osobowych jest {who}. Kontakt: {contact}.</p>
          <h2>Jakie dane przechowujemy</h2>
          <p>Przy koncie: adres e-mail, podane imię, cele (nazwa, cena, zdjęcie i jego kadr) oraz wpłaty i wypłaty (kwota, data, notatka). W trybie bez konta dane zostają tylko w przeglądarce lub na iPhonie i nie są do nas wysyłane.</p>
          <h2>Cel i podstawa prawna</h2>
          <p>Wyłącznie działanie aplikacji: synchronizacja oszczędności między stroną, iPhone'em i widżetami (art. 6 ust. 1 lit. b RODO, wykonanie umowy o świadczenie usługi).</p>
          <h2>Gdzie są dane</h2>
          <p>Dane przechowuje Supabase w Unii Europejskiej (Frankfurt). Stronę udostępnia Vercel. Zdjęcia leżą w prywatnym zasobniku, do którego dostęp masz tylko Ty.</p>
          <h2>Twoje prawa</h2>
          <p>Masz prawo dostępu do danych, ich przeniesienia (Ustawienia → Eksportuj do JSON), sprostowania i usunięcia (Ustawienia → Usuń konto usuwa wszystko naraz), ograniczenia przetwarzania i sprzeciwu. Możesz złożyć skargę do Prezesa Urzędu Ochrony Danych Osobowych.</p>
          <h2>Jak długo</h2>
          <p>Dopóki masz konto. Po usunięciu konta usuwamy wszystkie dane, także zdjęcia.</p>
          <h2>Pliki cookie i pamięć przeglądarki</h2>
          <p>Nie śledzimy i nie wyświetlamy reklam. Przeglądarka przechowuje sesję logowania i ustawienia (język, motyw, dźwięki).</p>
        </>
      )}
      {doc === 'terms' && (
        <>
          <h2>Usługa</h2>
          <p>macbook progress to bezpłatne, osobiste narzędzie do planowania oszczędności. Nie przechowuje pieniędzy, nie przyjmuje płatności i nie jest doradztwem finansowym.</p>
          <h2>Ceny</h2>
          <p>Ceny modeli są orientacyjne, pochodzą z polskiego Apple Store i mogą być nieaktualne. Apple i MacBook to znaki towarowe Apple Inc.; aplikacja nie jest związana z Apple.</p>
          <h2>Konto</h2>
          <p>Chroń swoje hasło. Konto możesz usunąć w każdej chwili w Ustawieniach.</p>
          <h2>Odpowiedzialność</h2>
          <p>Aplikacja jest udostępniana w obecnej postaci. Prognozy to szacunki na podstawie Twoich wpisów.</p>
          <h2>Kontakt</h2>
          <p>{contact}</p>
        </>
      )}
      {doc === 'info' && (
        <>
          <h2>O aplikacji</h2>
          <p>macbook progress: strona, aplikacja na iPhone'a i widżety do odkładania pieniędzy na MacBooka.</p>
          <h2>Właściciel</h2>
          <p>{who}. Kontakt: {contact}.</p>
          <h2>Podmioty przetwarzające</h2>
          <p>Supabase Inc. (baza danych, logowanie, zdjęcia; region UE), Vercel Inc. (hosting strony).</p>
        </>
      )}
      <p><a className="card-link" href="#/">{t('backToApp')}</a></p>
    </article>
  )
}
