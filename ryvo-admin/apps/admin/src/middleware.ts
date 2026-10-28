import { NextRequest, NextResponse } from 'next/server';

const MARKETING_HOSTS = new Set(['ryvo.arcadexit.com', 'www.ryvo.arcadexit.com']);

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

  // Admin login/dashboard must not run on the public site (API CORS is admin-only).
  if (pathname === '/login' || pathname.startsWith('/login/')) {
    return NextResponse.redirect(new URL(pathname, 'https://ryvo.arcadexit.com'));
  }

  // Marketing domain: serve landing at `/`.
  if (pathname === '/') {
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
