export function StripeHandoff({
  title,
  body,
  appLink,
}: {
  title: string;
  body: string;
  appLink?: string;
}) {
  return (
    <main
      style={{
        minHeight: '100vh',
        margin: 0,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: 24,
        background: 'var(--canvas)',
        color: 'var(--text)',
        fontFamily: 'Geist, ui-sans-serif, system-ui, sans-serif',
      }}
    >
      {appLink ? (
        <script
          dangerouslySetInnerHTML={{
            __html: `window.location.replace(${JSON.stringify(appLink)});`,
          }}
        />
      ) : null}
      <section
        style={{
          width: '100%',
          maxWidth: 420,
          background: 'var(--sheet)',
          border: '1px solid var(--hairline)',
          borderRadius: 20,
          padding: 28,
          boxShadow: 'var(--shadow-popover)',
        }}
      >
        <p style={{ margin: '0 0 8px', fontSize: 13, fontWeight: 600, letterSpacing: '0.04em', color: 'var(--text)' }}>
          RYVO
        </p>
        <h1 style={{ margin: '0 0 12px', fontSize: 28, lineHeight: 1.2 }}>{title}</h1>
        <p style={{ margin: 0, fontSize: 16, lineHeight: 1.5, color: 'var(--text-muted)' }}>{body}</p>
        {appLink ? (
          <a
            href={appLink}
            style={{
              display: 'inline-block',
              marginTop: 20,
              background: 'var(--emphasis)',
              color: 'var(--emphasis-fg)',
              textDecoration: 'none',
              fontWeight: 600,
              borderRadius: 12,
              padding: '12px 16px',
            }}
          >
            Open the Ryvo Driver app
          </a>
        ) : null}
      </section>
    </main>
  );
}
