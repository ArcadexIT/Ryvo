export function cssColor(token: string): string {
  if (typeof document === 'undefined') return 'transparent';
  const probe = document.createElement('span');
  probe.style.color = `var(${token})`;
  document.body.appendChild(probe);
  const color = getComputedStyle(probe).color;
  probe.remove();
  return color || 'transparent';
}

export function opsMapStyles() {
  const color = (token: string) => cssColor(token);
  return [
    { elementType: 'geometry', stylers: [{ color: color('--input') }] },
    { elementType: 'labels.icon', stylers: [{ visibility: 'off' }] },
    { elementType: 'labels.text.fill', stylers: [{ color: color('--text-muted') }] },
    { elementType: 'labels.text.stroke', stylers: [{ color: color('--canvas') }] },
    { featureType: 'administrative', elementType: 'geometry', stylers: [{ color: color('--hairline') }] },
    { featureType: 'road', elementType: 'geometry', stylers: [{ color: color('--card') }] },
    { featureType: 'road', elementType: 'geometry.stroke', stylers: [{ color: color('--sheet') }] },
    { featureType: 'road.highway', elementType: 'geometry', stylers: [{ color: color('--hairline') }] },
    { featureType: 'road.arterial', elementType: 'labels.text.fill', stylers: [{ color: color('--text-muted') }] },
    { featureType: 'poi', stylers: [{ visibility: 'off' }] },
    { featureType: 'transit', stylers: [{ visibility: 'off' }] },
    { featureType: 'water', elementType: 'geometry', stylers: [{ color: color('--canvas') }] },
  ];
}
