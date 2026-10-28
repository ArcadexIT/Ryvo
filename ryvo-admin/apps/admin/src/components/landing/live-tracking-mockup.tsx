const ROUTE_PATH =
  'M 42 228 C 42 206 88 198 108 174 C 130 148 84 138 76 116 C 68 94 114 88 138 68 C 156 52 142 34 160 26';

function RyvoMarkPaths() {
  return (
    <>
      <path
        d="M12.2 12.8 A 12 12 0 0 1 28.6 10.6"
        fill="none"
        stroke="var(--landing-orange)"
        strokeWidth="6.4"
        strokeLinecap="round"
      />
      <path
        d="M27.8 27.2 A 12 12 0 0 1 11.4 29.4"
        fill="none"
        stroke="var(--landing-orange)"
        strokeWidth="6.4"
        strokeLinecap="round"
      />
    </>
  );
}

function RyvoMark({ className, size = 22 }: { className?: string; size?: number }) {
  return (
    <svg viewBox="0 0 40 40" width={size} height={size} className={className} aria-hidden>
      <RyvoMarkPaths />
    </svg>
  );
}

function RyvoWordmark({ light = true }: { light?: boolean }) {
  return (
    <span className={`inline-flex items-center gap-[1px] ${light ? 'text-white' : 'text-[#111]'}`}>
      <span className="text-[15px] font-extrabold leading-none tracking-tight">J</span>
      <RyvoMark size={15} className="-mx-px" />
      <span className="text-[15px] font-extrabold leading-none tracking-tight">mp</span>
    </span>
  );
}

function MapPin() {
  return (
    <g className="live-tracking-pin" transform="translate(160 26)">
      <circle className="live-tracking-pin-pulse" r="16" fill="var(--landing-orange)" />
      <path
        d="M0 -18 C-8.5 -18 -15 -11.2 -15 -2.4 C-15 9.2 0 22 0 22 S15 9.2 15 -2.4 C15 -11.2 8.5 -18 0 -18 Z"
        fill="var(--landing-orange)"
      />
      <circle cy="-5" r="4.5" fill="white" />
    </g>
  );
}

function RyvoCar() {
  return (
    <g>
      <circle r="15" fill="white" />
      <rect x="-12" y="-7" width="24" height="14" rx="4.5" fill="var(--landing-orange)" />
      <rect x="3.5" y="-5.4" width="7" height="10.8" rx="2" fill="#1a222c" />
      <rect x="-9" y="-5" width="10" height="10" rx="1.6" fill="#c94312" />
      <text
        x="-3.5"
        y="2.8"
        fill="white"
        fontSize="7.5"
        fontWeight="800"
        textAnchor="middle"
        fontFamily="ui-sans-serif, system-ui, sans-serif"
      >
        J
      </text>
      <rect x="-8" y="-8.6" width="5.2" height="2.1" rx="1" fill="#111" />
      <rect x="-8" y="6.5" width="5.2" height="2.1" rx="1" fill="#111" />
      <rect x="3.2" y="-8.6" width="5.2" height="2.1" rx="1" fill="#111" />
      <rect x="3.2" y="6.5" width="5.2" height="2.1" rx="1" fill="#111" />
    </g>
  );
}

export function LiveTrackingMockup() {
  return (
    <figure className="live-tracking-phone" aria-label="RYVO live tracking a driver heading to pickup">
      <div className="live-tracking-bezel">
        <div className="live-tracking-screen">
          <div className="live-tracking-island" aria-hidden />

          <div className="pointer-events-none absolute inset-x-0 top-8 z-10 flex items-center justify-center">
            <RyvoWordmark />
          </div>

          <svg className="absolute inset-0 h-full w-full" viewBox="0 0 220 360" aria-hidden>
            <rect width="220" height="360" fill="#101820" />
            <g stroke="#1c2733" strokeWidth="10" fill="none">
              <path d="M0 92 H220" />
              <path d="M0 156 H220" />
              <path d="M0 220 H220" />
              <path d="M0 284 H220" />
              <path d="M54 0 V360" />
              <path d="M116 0 V360" />
              <path d="M176 0 V360" />
            </g>
            <g fill="#16202b">
              <rect x="10" y="48" width="36" height="32" rx="4" />
              <rect x="66" y="42" width="40" height="38" rx="4" />
              <rect x="10" y="106" width="34" height="38" rx="4" />
              <rect x="66" y="108" width="38" height="34" rx="4" />
              <rect x="10" y="170" width="36" height="36" rx="4" />
              <rect x="66" y="170" width="36" height="36" rx="4" />
              <rect x="128" y="108" width="36" height="34" rx="4" />
              <rect x="128" y="170" width="34" height="36" rx="4" />
              <rect x="128" y="42" width="34" height="32" rx="4" />
              <rect x="66" y="234" width="38" height="36" rx="4" />
            </g>

            <path
              d={ROUTE_PATH}
              fill="none"
              stroke="#3d2418"
              strokeWidth="9"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
            <path
              className="live-tracking-route-travel"
              d={ROUTE_PATH}
              fill="none"
              stroke="var(--landing-orange)"
              strokeWidth="6.5"
              strokeLinecap="round"
              strokeLinejoin="round"
              pathLength="1"
            />
            <path id="ryvo-live-route" d={ROUTE_PATH} fill="none" stroke="none" />

            <MapPin />

            <g className="live-tracking-vehicle">
              <animateMotion
                dur="8s"
                repeatCount="indefinite"
                rotate="auto"
                calcMode="linear"
                keyTimes="0;0.08;0.72;0.9;1"
                keyPoints="0;0;1;1;1"
              >
                <mpath href="#ryvo-live-route" />
              </animateMotion>
              <RyvoCar />
            </g>
            <g className="live-tracking-vehicle-static" transform="translate(108 174)">
              <RyvoCar />
            </g>
          </svg>

          <div className="live-tracking-status">
            <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-[#111]">
              <RyvoMark size={18} />
            </span>
            <div className="min-w-0 flex-1">
              <p className="truncate text-[13px] font-bold leading-tight">RYVO on the way</p>
              <p className="live-tracking-eta mt-0.5 truncate text-[11px] leading-tight">
                Arriving in 6 min
              </p>
              <div className="mt-2 flex items-center gap-1.5">
                <span className="relative h-1 flex-1 overflow-hidden rounded-full bg-[#ece8e4]">
                  <span className="live-tracking-progress absolute inset-y-0 left-0 rounded-full bg-[var(--landing-orange)]" />
                </span>
                <span className="h-2 w-2 rounded-full bg-[var(--landing-orange)]" />
              </div>
            </div>
          </div>
        </div>
      </div>
    </figure>
  );
}
