import { formatCurrency, formatDate } from '@/lib/utils';

export interface InvoiceRecord {
  id: string;
  invoiceNumber: string;
  total: number | string;
  email?: string | null;
  sentAt?: string | null;
  issuedAt: string;
  customer?: { user?: { fullName?: string; email?: string; phone?: string } };
  job?: {
    jobNumber?: string;
    pickupAddress?: string;
    dropoffAddress?: string | null;
    completedAt?: string | null;
    serviceCategory?: { name?: string };
    vehicle?: { make?: string; model?: string; plateNumber?: string; color?: string } | null;
    provider?: { user?: { fullName?: string } } | null;
  };
  payment?: { method?: string; status?: string; paidAt?: string | null } | null;
}

const ICONS = {
  user: '<circle cx="12" cy="8" r="4"/><path d="M4 21v-1a8 8 0 0 1 16 0v1"/>',
  mail: '<rect width="20" height="16" x="2" y="4" rx="2"/><path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"/>',
  phone: '<path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.8 19.8 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6A19.8 19.8 0 0 1 2.12 4.18 2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.12.9.33 1.77.62 2.61a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.47-1.19a2 2 0 0 1 2.11-.45c.84.29 1.71.5 2.61.62A2 2 0 0 1 22 16.92z"/>',
  pin: '<path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z"/><circle cx="12" cy="10" r="3"/>',
  car: '<path d="M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9L18 10l-2.7-3.6A2 2 0 0 0 13.7 5H10a2 2 0 0 0-1.7 1L6 10l-2.4 1.1C2.7 11.3 2 12.1 2 13v3c0 .6.4 1 1 1h2"/><circle cx="7" cy="17" r="2"/><path d="M9 17h6"/><circle cx="17" cy="17" r="2"/>',
  calendar: '<rect width="18" height="18" x="3" y="4" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/>',
  hash: '<path d="M4 9h16M4 15h16M10 3 8 21M16 3l-2 18"/>',
  card: '<rect width="20" height="14" x="2" y="5" rx="2"/><path d="M2 10h20"/>',
  receipt: '<path d="M4 2v20l2-1 2 1 2-1 2 1 2-1 2 1 2-1 2 1V2l-2 1-2-1-2 1-2-1-2 1-2-1-2 1Z"/><path d="M8 10h8M8 14h5"/>',
} as const;

function icon(name: keyof typeof ICONS) {
  return `<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${ICONS[name]}</svg>`;
}

function escapeHtml(value: string) {
  return value.replace(/[&<>"']/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char] ?? char);
}

function text(value?: string | null, fallback = '—') {
  const clean = value?.trim();
  return escapeHtml(clean || fallback);
}

function labelize(value?: string | null) {
  if (!value) return '—';
  return value
    .replace(/[_-]+/g, ' ')
    .replace(/\b\w/g, (char) => char.toUpperCase());
}

export function customerName(invoice: InvoiceRecord) {
  return invoice.customer?.user?.fullName || 'Customer';
}

export function customerEmail(invoice: InvoiceRecord) {
  return invoice.email || invoice.customer?.user?.email || '';
}

function vehicleLabel(invoice: InvoiceRecord) {
  const vehicle = invoice.job?.vehicle;
  return [vehicle?.color, vehicle?.make, vehicle?.model, vehicle?.plateNumber].filter(Boolean).join(' ');
}

let logoPromise: Promise<string> | null = null;

function loadInvoiceLogo() {
  if (!logoPromise) logoPromise = knockOutLogo('/logo-mark.png');
  return logoPromise;
}

function knockOutLogo(src: string) {
  return new Promise<string>((resolve) => {
    const image = new Image();
    image.onload = () => {
      const size = 160;
      const canvas = document.createElement('canvas');
      canvas.width = size;
      canvas.height = size;
      const context = canvas.getContext('2d');
      if (!context) {
        resolve('');
        return;
      }
      const scale = Math.min(size / image.width, size / image.height);
      const width = image.width * scale;
      const height = image.height * scale;
      context.drawImage(image, (size - width) / 2, (size - height) / 2, width, height);
      const pixels = context.getImageData(0, 0, size, size);
      const data = pixels.data;
      for (let index = 0; index < data.length; index += 4) {
        const red = data[index] ?? 0;
        const green = data[index + 1] ?? 0;
        const blue = data[index + 2] ?? 0;
        const max = Math.max(red, green, blue);
        const lime = green > red + 18 && green > blue + 8 && green > 36;
        if (lime) continue;
        if (max < 24) data[index + 3] = 0;
        else if (max < 56) data[index + 3] = Math.round(((max - 24) / 32) * 255);
      }
      context.putImageData(pixels, 0, 0);
      resolve(canvas.toDataURL('image/png'));
    };
    image.onerror = () => resolve('');
    image.src = src;
  });
}

const STYLES = `
  :root { color-scheme: light; }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    background: #eef3f8;
    color: #090a0d;
    font-family: "Plus Jakarta Sans", Inter, ui-sans-serif, system-ui, sans-serif;
  }
  .page { max-width: 820px; margin: 0 auto; padding: 28px 16px 40px; }
  .sheet {
    background: #fff;
    border: 1px solid #e2e8f0;
    border-radius: 24px;
    overflow: hidden;
  }
  .accent { height: 6px; background: linear-gradient(90deg, #c8f56a, #3dcc62 55%, #14b85c); }
  .pad { padding: 28px 32px; }
  .top { display: flex; justify-content: space-between; gap: 24px; align-items: flex-start; }
  .brand { display: flex; align-items: center; gap: 12px; }
  .brand img { width: 52px; height: 52px; object-fit: contain; }
  .mark {
    width: 52px; height: 52px; border-radius: 16px;
    display: grid; place-items: center;
    background: #152437; color: #c8f56a;
  }
  .name { font-size: 22px; font-weight: 800; letter-spacing: -0.05em; line-height: 1; }
  .tag { margin-top: 4px; color: #64748b; font-size: 12px; letter-spacing: 0.14em; text-transform: uppercase; }
  .kicker { margin: 0; color: #64748b; font-size: 12px; font-weight: 700; letter-spacing: 0.16em; text-transform: uppercase; text-align: right; }
  .number { margin: 4px 0 0; font-size: 26px; font-weight: 800; letter-spacing: -0.04em; text-align: right; }
  .pill {
    display: inline-flex; align-items: center; gap: 6px;
    margin-top: 10px; border-radius: 999px; padding: 4px 10px;
    font-size: 12px; font-weight: 700;
  }
  .pill.sent { background: #dcfce7; color: #166534; }
  .pill.wait { background: #fef3c7; color: #92400e; }
  .dot { width: 7px; height: 7px; border-radius: 99px; background: currentColor; }
  .hero {
    display: flex; justify-content: space-between; gap: 20px; align-items: stretch;
    margin-top: 26px;
  }
  .who { flex: 1; }
  .eyebrow { margin: 0 0 8px; color: #64748b; font-size: 11px; font-weight: 700; letter-spacing: 0.12em; text-transform: uppercase; }
  .who h2 { margin: 0; font-size: 20px; letter-spacing: -0.03em; }
  .contacts { display: flex; flex-wrap: wrap; gap: 8px 16px; margin-top: 10px; color: #334155; font-size: 13px; }
  .contacts > span, .meta > span { display: flex; align-items: center; gap: 8px; }
  .ico {
    width: 26px; height: 26px; border-radius: 999px;
    display: inline-grid; place-items: center; flex: none;
    background: #ecfdf3; color: #05944f;
  }
  .due {
    min-width: 210px; border-radius: 18px; padding: 16px 18px 16px 22px;
    background: #152437; color: #fff; text-align: right; position: relative; overflow: hidden;
  }
  .due:before {
    content: ""; position: absolute; left: 0; top: 0; bottom: 0; width: 5px;
    background: linear-gradient(#c8f56a, #14b85c);
  }
  .due p { margin: 0; color: #8b9aaf; font-size: 11px; font-weight: 700; letter-spacing: 0.14em; text-transform: uppercase; }
  .due strong { display: block; margin-top: 6px; font-size: 32px; letter-spacing: -0.05em; font-variant-numeric: tabular-nums; }
  .split { display: grid; grid-template-columns: 1.15fr 0.85fr; }
  .block { padding: 8px 32px 24px; }
  .block + .block { border-left: 1px solid #e2e8f0; }
  .route { display: grid; gap: 0; margin-top: 4px; }
  .stop { display: grid; grid-template-columns: 18px 1fr; column-gap: 12px; }
  .rail { display: flex; flex-direction: column; align-items: center; }
  .bead { width: 10px; height: 10px; border-radius: 99px; background: #14b85c; margin-top: 4px; }
  .bead.sq { border-radius: 2px; background: transparent; border: 2px solid #152437; width: 9px; height: 9px; }
  .stem { width: 1.5px; flex: 1; min-height: 18px; background: #cbd5e1; }
  .stop p { margin: 0; font-size: 14px; line-height: 1.4; }
  .stop small { display: block; margin-top: 2px; color: #64748b; font-size: 11px; letter-spacing: 0.08em; text-transform: uppercase; }
  .meta { display: grid; gap: 12px; margin-top: 4px; font-size: 14px; }
  .meta b { display: block; font-weight: 600; }
  .meta small { color: #64748b; font-size: 11px; letter-spacing: 0.08em; text-transform: uppercase; }
  table { width: 100%; border-collapse: collapse; }
  th {
    text-align: left; padding: 12px 16px; color: #64748b;
    font-size: 11px; letter-spacing: 0.1em; text-transform: uppercase;
    border-bottom: 1px solid #e2e8f0; background: #f8fafc;
  }
  td { padding: 14px 16px; border-bottom: 1px solid #f1f5f9; font-size: 14px; vertical-align: top; }
  .num { text-align: right; font-variant-numeric: tabular-nums; font-weight: 700; }
  .muted { color: #64748b; font-weight: 500; }
  .totals { display: flex; justify-content: flex-end; padding: 8px 32px 28px; }
  .totals div {
    min-width: 240px; display: flex; justify-content: space-between; align-items: baseline; gap: 24px;
    border-top: 2px solid #090a0d; padding-top: 12px;
  }
  .totals span { color: #64748b; font-size: 13px; }
  .totals strong { font-size: 24px; letter-spacing: -0.04em; font-variant-numeric: tabular-nums; }
  footer {
    display: flex; justify-content: space-between; gap: 16px; align-items: center;
    padding: 16px 32px 22px; color: #64748b; font-size: 12px;
    border-top: 1px solid #e2e8f0;
  }
  .stats { display: flex; gap: 10px; margin: 22px 0 8px; }
  .stat { flex: 1; background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 14px; padding: 12px 14px; }
  .stat b { display: block; margin-top: 4px; font-size: 18px; letter-spacing: -0.03em; font-variant-numeric: tabular-nums; }
  @media (max-width: 720px) {
    .top, .hero, .split, footer { display: block; }
    .block + .block { border-left: 0; border-top: 1px solid #e2e8f0; }
    .kicker, .number { text-align: left; }
    .due { margin-top: 16px; text-align: left; }
    .pad, .block, .totals, footer, th:first-child, td:first-child { padding-left: 18px; }
    .pad, .block, .totals, footer, th:last-child, td:last-child { padding-right: 18px; }
  }
  @media print {
    body { background: #fff; }
    .page { padding: 0; max-width: none; }
    .sheet { border: 0; border-radius: 0; }
  }
`;

function brand(logo: string) {
  const mark = logo
    ? `<img src="${logo}" alt="Ryvo">`
    : `<div class="mark">${icon('receipt')}</div>`;
  return `<div class="brand">${mark}<div><div class="name">RYVO</div><div class="tag">Mobility</div></div></div>`;
}

function shell(title: string, body: string) {
  return `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${escapeHtml(title)}</title><style>${STYLES}</style></head><body><div class="page"><article class="sheet"><div class="accent"></div>${body}</article></div></body></html>`;
}

export function invoiceDocument(invoice: InvoiceRecord, logo: string) {
  const sent = Boolean(invoice.sentAt);
  const service = invoice.job?.serviceCategory?.name || 'Trip';
  const trip = invoice.job?.jobNumber || '';
  const payment = [labelize(invoice.payment?.method), labelize(invoice.payment?.status)].filter((part) => part !== '—').join(' · ');
  return shell(
    invoice.invoiceNumber,
    `<header class="pad">
      <div class="top">
        ${brand(logo)}
        <div>
          <p class="kicker">Invoice</p>
          <h1 class="number">${text(invoice.invoiceNumber)}</h1>
          <div class="pill ${sent ? 'sent' : 'wait'}"><i class="dot"></i>${sent ? `Sent ${escapeHtml(formatDate(invoice.sentAt!))}` : 'Not sent'}</div>
        </div>
      </div>
      <div class="hero">
        <div class="who">
          <p class="eyebrow">Billed to</p>
          <h2>${text(customerName(invoice))}</h2>
          <div class="contacts">
            <span><i class="ico">${icon('mail')}</i>${text(customerEmail(invoice))}</span>
            <span><i class="ico">${icon('phone')}</i>${text(invoice.customer?.user?.phone)}</span>
          </div>
        </div>
        <aside class="due">
          <p>Amount due</p>
          <strong>${escapeHtml(formatCurrency(Number(invoice.total)))}</strong>
        </aside>
      </div>
    </header>
    <section class="split">
      <div class="block">
        <p class="eyebrow">Route</p>
        <div class="route">
          <div class="stop">
            <div class="rail"><i class="bead"></i><i class="stem"></i></div>
            <p><small>Pickup</small>${text(invoice.job?.pickupAddress)}</p>
          </div>
          <div class="stop">
            <div class="rail"><i class="bead sq"></i></div>
            <p><small>Dropoff</small>${text(invoice.job?.dropoffAddress)}</p>
          </div>
        </div>
      </div>
      <div class="block">
        <p class="eyebrow">Trip</p>
        <div class="meta">
          <span><i class="ico">${icon('calendar')}</i><span><small>Issued</small><b>${escapeHtml(formatDate(invoice.issuedAt))}</b></span></span>
          <span><i class="ico">${icon('hash')}</i><span><small>Trip</small><b>${text(trip)}</b></span></span>
          <span><i class="ico">${icon('car')}</i><span><small>Service</small><b>${text(service)}</b></span></span>
          <span><i class="ico">${icon('user')}</i><span><small>Driver</small><b>${text(invoice.job?.provider?.user?.fullName)}</b></span></span>
          <span><i class="ico">${icon('car')}</i><span><small>Vehicle</small><b>${text(vehicleLabel(invoice))}</b></span></span>
          <span><i class="ico">${icon('card')}</i><span><small>Payment</small><b>${text(payment === '' ? null : payment)}</b></span></span>
        </div>
      </div>
    </section>
    <table>
      <thead><tr><th>Description</th><th class="num">Amount</th></tr></thead>
      <tbody>
        <tr>
          <td>${text(service)}${trip ? `<div class="muted">${text(trip)}</div>` : ''}</td>
          <td class="num">${escapeHtml(formatCurrency(Number(invoice.total)))}</td>
        </tr>
      </tbody>
    </table>
    <div class="totals"><div><span>Total</span><strong>${escapeHtml(formatCurrency(Number(invoice.total)))}</strong></div></div>
    <footer><span>Thank you for riding with Ryvo.</span><span>${text(invoice.invoiceNumber)}</span></footer>`,
  );
}

export function listDocument(invoices: InvoiceRecord[], logo: string) {
  const total = invoices.reduce((sum, invoice) => sum + Number(invoice.total), 0);
  const sent = invoices.filter((invoice) => invoice.sentAt).length;
  const body = invoices
    .map(
      (invoice) => `<tr>
        <td><b>${text(invoice.invoiceNumber)}</b></td>
        <td>${text(customerName(invoice))}<div class="muted">${text(customerEmail(invoice), '')}</div></td>
        <td>${text(invoice.job?.jobNumber)}</td>
        <td>${invoice.sentAt ? 'Sent' : 'Not sent'}</td>
        <td>${escapeHtml(formatDate(invoice.issuedAt))}</td>
        <td class="num">${escapeHtml(formatCurrency(Number(invoice.total)))}</td>
      </tr>`,
    )
    .join('');
  return shell(
    'Ryvo invoices',
    `<header class="pad">
      <div class="top">
        ${brand(logo)}
        <div>
          <p class="kicker">Statement</p>
          <h1 class="number">Invoices</h1>
        </div>
      </div>
      <div class="stats">
        <div class="stat"><span class="muted">Invoices</span><b>${invoices.length}</b></div>
        <div class="stat"><span class="muted">Sent</span><b>${sent}</b></div>
        <div class="stat"><span class="muted">Not sent</span><b>${invoices.length - sent}</b></div>
        <div class="stat"><span class="muted">Total</span><b>${escapeHtml(formatCurrency(total))}</b></div>
      </div>
    </header>
    <table>
      <thead><tr><th>Invoice</th><th>Customer</th><th>Trip</th><th>Status</th><th>Issued</th><th class="num">Total</th></tr></thead>
      <tbody>${body}</tbody>
    </table>
    <div class="totals"><div><span>Total</span><strong>${escapeHtml(formatCurrency(total))}</strong></div></div>
    <footer><span>Ryvo invoice statement</span><span>${invoices.length} invoices</span></footer>`,
  );
}

function openPrint(html: string) {
  const frame = window.open('', '_blank', 'noopener,noreferrer,width=880,height=980');
  if (!frame) return;
  frame.document.write(html);
  frame.document.close();
  frame.focus();
  frame.print();
}

function downloadHtml(filename: string, html: string) {
  const blob = new Blob([html], { type: 'text/html;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  link.click();
  URL.revokeObjectURL(url);
}

export function printInvoice(invoice: InvoiceRecord) {
  void loadInvoiceLogo().then((logo) => openPrint(invoiceDocument(invoice, logo)));
}

export function downloadInvoice(invoice: InvoiceRecord) {
  void loadInvoiceLogo().then((logo) => downloadHtml(`${invoice.invoiceNumber}.html`, invoiceDocument(invoice, logo)));
}

export function printInvoiceList(invoices: InvoiceRecord[]) {
  void loadInvoiceLogo().then((logo) => openPrint(listDocument(invoices, logo)));
}

export function downloadInvoiceList(invoices: InvoiceRecord[]) {
  void loadInvoiceLogo().then((logo) => downloadHtml('ryvo-invoices.html', listDocument(invoices, logo)));
}
