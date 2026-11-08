import { NextRequest, NextResponse } from 'next/server';

const MARKETING_HOSTS = new Set(['ryvo.arcadexit.com', 'www.ryvo.arcadexit.com']);
const ADMIN_HOST = 'https://ryvo.arcadexit.com';
// Routing hint only. The real session stays in localStorage; AuthGuard still checks it.
const ADMIN_SESSION_COOKIE = 'ryvo_admin_session';

export function middleware(request: NextRequest) {
  const host = request.headers.get('host')?.split(':')[0]?.toLowerCase() ?? '';
  const isMarketing = MARKETING_HOSTS.has(host);
  const { pathname } = request.nextUrl;

  // Static assets and Next internals pass through.
  if (
    pathname.startsWith('/_next') ||
    pathname.startsWith('/landing') ||
    pathname.startsWith('/logo') ||
    pathname.includes('.')
  ) {
    return NextResponse.next();
  }

  const url = request.nextUrl.clone();

  // Clean legal URLs on every host (admin preview + marketing).
  if (pathname === '/privacy-policy') {
    url.pathname = '/landing-page/privacy-policy';
    return NextResponse.rewrite(url);
  }
  if (pathname === '/terms' || pathname === '/terms/') {
    url.pathname = '/landing-page/terms';
    return NextResponse.rewrite(url);
  }

  // Clean contact/support URL on every host (admin preview + marketing).
  // Handles the trailing-slash variant (/contact/) used by Google Play too.
  if (pathname === '/contact' || pathname === '/contact/') {
    url.pathname = '/landing-page/contact';
    return NextResponse.rewrite(url);
  }

  if (!isMarketing) {
    return NextResponse.next();
  }

  // www has no certificate. Keep login on the apex, which is this same app.
  if (
    host !== 'ryvo.arcadexit.com' &&
    (pathname === '/login' || pathname.startsWith('/login/'))
  ) {
    return NextResponse.redirect(new URL(pathname + request.nextUrl.search, ADMIN_HOST));
  }

  // Public visitors get the marketing page. A signed-in admin gets the dashboard,
  // which also lives at `/`.
  if (pathname === '/' && request.cookies.get(ADMIN_SESSION_COOKIE)?.value !== '1') {
    url.pathname = '/landing-page';
    return NextResponse.rewrite(url);
  }

  // Normalize old /landing-page URLs to clean marketing URLs.
  if (pathname === '/landing-page') {
    url.pathname = '/';
    return NextResponse.redirect(url);
  }
  if (pathname === '/landing-page/privacy-policy') {
    url.pathname = '/privacy-policy';
    return NextResponse.redirect(url);
  }
  if (pathname === '/landing-page/terms') {
    url.pathname = '/terms';
    return NextResponse.redirect(url);
  }
  if (pathname === '/landing-page/contact') {
    url.pathname = '/contact';
    return NextResponse.redirect(url);
  }

  return NextResponse.next();
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico).*)'],
};
