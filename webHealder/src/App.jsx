import { useEffect, useState } from 'react'
import { Link, Route, Routes, useLocation } from 'react-router-dom'
import { ArrowDown, ArrowUpRight, BellRing, Check, ChevronRight, Languages, Link2, Mail, Menu, Video, X } from 'lucide-react'
import { copy } from './content'

const SUPPORT_EMAIL = 'ivanyuantama.work@gmail.com'
const SCREENSHOT_AVAILABLE = false

function useLocale() {
  const { pathname } = useLocation()
  return pathname === '/en' || pathname.startsWith('/en/') ? 'en' : 'id'
}

function localPath(locale, path = '') {
  const clean = path === '/' ? '' : path
  return `${locale === 'en' ? '/en' : ''}${clean}` || '/'
}

function otherLanguagePath(pathname, locale) {
  if (locale === 'en') return pathname.replace(/^\/en(?=\/|$)/, '') || '/'
  return `/en${pathname === '/' ? '' : pathname}`
}

function PageMeta({ title, description, locale }) {
  useEffect(() => {
    document.documentElement.lang = locale
    document.title = title
    let meta = document.querySelector('meta[name="description"]')
    if (!meta) {
      meta = document.createElement('meta')
      meta.name = 'description'
      document.head.appendChild(meta)
    }
    meta.content = description
  }, [title, description, locale])
  return null
}

function Brand({ locale, compact = false }) {
  return (
    <Link to={localPath(locale)} className="brand" aria-label="Healder — home">
      <img src="/healder-logo.png" alt="" className={compact ? 'brand-logo brand-logo-small' : 'brand-logo'} />
      <span>Healder</span>
    </Link>
  )
}

function LanguageSwitch({ locale, pathname }) {
  const next = locale === 'id' ? 'EN' : 'ID'
  const label = locale === 'id' ? 'Switch to English' : 'Ganti ke Bahasa Indonesia'
  return (
    <Link to={otherLanguagePath(pathname, locale)} className="language-switch" aria-label={label}>
      <Languages size={17} aria-hidden="true" />
      {next}
    </Link>
  )
}

function Header({ locale, landing = false }) {
  const t = copy[locale]
  const { pathname } = useLocation()
  const [open, setOpen] = useState(false)
  const home = localPath(locale)
  const featureHref = landing ? '#features' : `${home}#features`
  const howHref = landing ? '#how-it-works' : `${home}#how-it-works`

  useEffect(() => setOpen(false), [pathname])

  return (
    <header className="site-header">
      <div className="header-inner">
        <Brand locale={locale} />
        <nav className="desktop-nav" aria-label="Primary navigation">
          <a href={featureHref}>{t.nav.features}</a>
          <a href={howHref}>{t.nav.how}</a>
          <a href={`mailto:${SUPPORT_EMAIL}`}>{t.nav.support}</a>
        </nav>
        <div className="header-actions">
          <LanguageSwitch locale={locale} pathname={pathname} />
          <button className="menu-button" aria-label={t.nav.menu} aria-expanded={open} onClick={() => setOpen((value) => !value)}>
            {open ? <X size={21} /> : <Menu size={21} />}
          </button>
        </div>
      </div>
      {open && (
        <nav className="mobile-nav" aria-label="Mobile navigation">
          <a href={featureHref} onClick={() => setOpen(false)}>{t.nav.features}<ChevronRight size={18} /></a>
          <a href={howHref} onClick={() => setOpen(false)}>{t.nav.how}<ChevronRight size={18} /></a>
          <a href={`mailto:${SUPPORT_EMAIL}`}>{t.nav.support}<ArrowUpRight size={18} /></a>
        </nav>
      )}
    </header>
  )
}

function Footer({ locale }) {
  const t = copy[locale].footer
  return (
    <footer className="site-footer">
      <div className="footer-inner">
        <div className="footer-brand">
          <Brand locale={locale} compact />
          <p>{t.note}</p>
        </div>
        <nav className="footer-links" aria-label="Footer navigation">
          <Link to={localPath(locale, '/support')}>{t.support}</Link>
          <Link to={localPath(locale, '/privacy')}>{t.privacy}</Link>
          <Link to={localPath(locale, '/terms')}>{t.terms}</Link>
          <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a>
        </nav>
      </div>
      <div className="footer-bottom">
        <p>© {new Date().getFullYear()} {t.rights}</p>
      </div>
    </footer>
  )
}

const featureIcons = [Link2, BellRing, Video]

function PhonePreview({ t }) {
  return (
    <div className="visual-wrap" aria-label={t.screenAlt}>
      <div className="orbit orbit-one" />
      <div className="orbit orbit-two" />
      <div className="phone-shadow" />
      <div className="phone-frame">
        <div className="phone-speaker" />
        {SCREENSHOT_AVAILABLE ? (
          <img className="app-screen" src="/healder-app-screen.png" alt={t.screenAlt} />
        ) : (
          <div className="screen-pending">
            <img src="/healder-logo.png" alt="Healder" />
            <p>{t.screenPending}</p>
            <span>{t.screenNote}</span>
          </div>
        )}
      </div>
      <div className="connection-chip chip-left"><Link2 size={17} /><span>OTP</span><Check size={15} /></div>
      <div className="connection-chip chip-right"><Video size={17} /><span>Video</span></div>
    </div>
  )
}

function HomePage() {
  const locale = useLocale()
  const t = copy[locale]
  const metaTitle = locale === 'id' ? 'Healder — Lebih dekat dengan orang tua, setiap hari' : 'Healder — Stay closer to your parents, every day'
  const metaDescription = locale === 'id'
    ? 'Hubungkan orang tua dan anak untuk mengatur pengingat kesehatan dan tetap terhubung melalui panggilan video.'
    : 'Connect parents and their children to manage health reminders and stay in touch through video calls.'

  return (
    <div className="page-shell">
      <PageMeta title={metaTitle} description={metaDescription} locale={locale} />
      <Header locale={locale} landing />
      <main>
        <section className="hero" aria-labelledby="hero-title">
          <div className="hero-glow hero-glow-blue" />
          <div className="hero-glow hero-glow-teal" />
          <div className="section-inner hero-grid">
            <div className="hero-copy">
              <div className="eyebrow"><span className="eyebrow-dot" />{t.home.eyebrow}</div>
              <h1 id="hero-title">{t.home.title}</h1>
              <p className="hero-intro">{t.home.intro}</p>
              <div className="hero-actions">
                <span className="coming-soon">{t.home.soon}</span>
                <a href="#how-it-works" className="primary-button">{t.home.howCta}<ArrowDown size={19} /></a>
              </div>
            </div>
            <PhonePreview t={t.home} />
          </div>
        </section>

        <section id="features" className="features-section">
          <div className="section-inner">
            <div className="section-heading">
              <span className="section-kicker">{t.home.featureKicker}</span>
              <h2>{t.home.featureTitle}</h2>
            </div>
            <div className="feature-grid">
              {t.home.features.map(([title, description], index) => {
                const Icon = featureIcons[index]
                return (
                  <article className="feature-card" key={title}>
                    <div className={`feature-icon feature-icon-${index + 1}`}><Icon size={24} /></div>
                    <h3>{title}</h3>
                    <p>{description}</p>
                  </article>
                )
              })}
            </div>
          </div>
        </section>

        <section id="how-it-works" className="how-section">
          <div className="section-inner how-grid">
            <div className="section-heading how-heading">
              <span className="section-kicker">{t.home.howKicker}</span>
              <h2>{t.home.howTitle}</h2>
            </div>
            <ol className="steps-list">
              {t.home.steps.map((step, index) => (
                <li key={step}>
                  <span className="step-number">{String(index + 1).padStart(2, '0')}</span>
                  <p>{step}</p>
                </li>
              ))}
            </ol>
          </div>
        </section>
      </main>
      <Footer locale={locale} />
    </div>
  )
}

function SupportPage() {
  const locale = useLocale()
  const t = copy[locale]
  const description = locale === 'id' ? 'Dapatkan bantuan untuk menggunakan aplikasi Healder.' : 'Get help with the Healder app.'
  return (
    <div className="page-shell inner-page">
      <PageMeta title={`${t.support.title} — Healder`} description={description} locale={locale} />
      <Header locale={locale} />
      <main className="support-main">
        <div className="support-layout">
          <section className="support-intro">
            <div className="support-icon"><Mail size={26} /></div>
            <h1>{t.support.title}</h1>
            <p>{t.support.intro}</p>
          </section>
          <section className="support-card" aria-label={t.support.emailLabel}>
            <span className="field-label">{t.support.emailLabel}</span>
            <a className="support-email" href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a>
            <a className="primary-button email-button" href={`mailto:${SUPPORT_EMAIL}`}>
              <Mail size={19} />{t.support.button}
            </a>
            <div className="support-divider" />
            <h2>{t.support.detailsTitle}</h2>
            <p>{t.support.detailsIntro}</p>
            <ul className="detail-list">
              {t.support.details.map((item) => <li key={item}><Check size={17} />{item}</li>)}
            </ul>
            <p className="privacy-tip">{t.support.screenshot}</p>
          </section>
          <div className="emergency-note">{t.support.emergency}</div>
        </div>
      </main>
      <Footer locale={locale} />
    </div>
  )
}

function LegalPage({ type }) {
  const locale = useLocale()
  const t = copy[locale]
  const isPrivacy = type === 'privacy'
  const title = isPrivacy ? t.legal.privacyTitle : t.legal.termsTitle
  const intro = isPrivacy ? t.legal.privacyIntro : t.legal.termsIntro
  const sections = isPrivacy ? t.legal.privacySections : t.legal.termsSections
  const questionTitle = isPrivacy ? t.legal.privacyQuestions : t.legal.termsQuestions
  const items = isPrivacy ? t.legal.privacyItems : t.legal.termsItems
  const description = locale === 'id' ? `${title}, draf internal untuk aplikasi Healder.` : `${title}, internal draft for the Healder app.`

  return (
    <div className="page-shell inner-page">
      <PageMeta title={`${title} — Healder`} description={description} locale={locale} />
      <Header locale={locale} />
      <main className="legal-main">
        <article className="legal-document">
          <header className="legal-header">
            <span className="draft-badge">{t.legal.draft}</span>
            <h1>{title}</h1>
            <p className="legal-intro">{intro}</p>
            <p className="legal-status">{t.legal.updated}</p>
          </header>
          <div className="legal-body">
            {sections.map(([heading, paragraphs], index) => (
              <section key={heading}>
                <span className="legal-index">{String(index + 1).padStart(2, '0')}</span>
                <div>
                  <h2>{heading}</h2>
                  {paragraphs.map((paragraph) => <p key={paragraph}>{paragraph}</p>)}
                </div>
              </section>
            ))}
            <section className="question-section">
              <span className="legal-index">?</span>
              <div>
                <h2>{questionTitle}</h2>
                <ol>
                  {items.map((item) => <li key={item}>{item}</li>)}
                </ol>
              </div>
            </section>
            <div className="legal-contact">
              <Mail size={19} />
              <a href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a>
            </div>
          </div>
        </article>
      </main>
      <Footer locale={locale} />
    </div>
  )
}

function NotFoundPage() {
  const locale = useLocale()
  return (
    <div className="page-shell inner-page">
      <Header locale={locale} />
      <main className="not-found">
        <p>404</p>
        <h1>{locale === 'id' ? 'Halaman tidak ditemukan' : 'Page not found'}</h1>
        <Link className="primary-button" to={localPath(locale)}>{locale === 'id' ? 'Kembali ke beranda' : 'Back to home'}</Link>
      </main>
      <Footer locale={locale} />
    </div>
  )
}

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<HomePage />} />
      <Route path="/support" element={<SupportPage />} />
      <Route path="/privacy" element={<LegalPage type="privacy" />} />
      <Route path="/terms" element={<LegalPage type="terms" />} />
      <Route path="/en" element={<HomePage />} />
      <Route path="/en/support" element={<SupportPage />} />
      <Route path="/en/privacy" element={<LegalPage type="privacy" />} />
      <Route path="/en/terms" element={<LegalPage type="terms" />} />
      <Route path="*" element={<NotFoundPage />} />
    </Routes>
  )
}
