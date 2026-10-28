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
        background: '#f7f7f5',
        color: '#1c1c1a',
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
          background: '#ffffff',
          border: '1px solid #e6e5e1',
          borderRadius: 16,
          padding: 28,
          boxShadow: '0 10px 20px -6px rgba(28, 28, 26, 0.09)',
        }}
      >
        <p style={{ margin: '0 0 8px', fontSize: 13, fontWeight: 600, letterSpacing: '0.04em', color: '#0b1220' }}>
          RYVO
        </p>
        <h1 style={{ margin: '0 0 12px', fontSize: 28, lineHeight: 1.2 }}>{title}</h1>
        <p style={{ margin: 0, fontSize: 16, lineHeight: 1.5, color: '#6b6a65' }}>{body}</p>
        {appLink ? (
          <a
            href={appLink}
            style={{
              display: 'inline-block',
              marginTop: 20,
              background: '#ff5500',
              color: '#ffffff',
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
