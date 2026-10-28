declare global {
  interface Window {
    google?: typeof google;
  }
}

export interface MapMarker {
  id: string;
  lat: number;
  lng: number;
  label?: string;
  title?: string;
  /** Heading in degrees (0-360), shows a directional indicator when present. */
  heading?: number;
}

let loadPromise: Promise<typeof google> | null = null;
let loadedKey: string | null = null;

export function loadGoogleMaps(apiKey: string): Promise<typeof google> {
  if (typeof window === 'undefined') {
    return Promise.reject(new Error('Google Maps can only load in the browser'));
  }

  if (window.google?.maps && loadedKey === apiKey) {
    return Promise.resolve(window.google);
  }

  if (loadPromise && loadedKey === apiKey) {
    return loadPromise;
  }

  loadedKey = apiKey;
  loadPromise = new Promise((resolve, reject) => {
    const existing = document.getElementById('google-maps-script');
    if (existing) existing.remove();

    const script = document.createElement('script');
    script.id = 'google-maps-script';
    script.src = `https://maps.googleapis.com/maps/api/js?key=${encodeURIComponent(apiKey)}&libraries=places`;
    script.async = true;
    script.defer = true;
    script.onload = () => {
      if (window.google?.maps) resolve(window.google);
      else reject(new Error('Google Maps failed to initialize'));
    };
    script.onerror = () => reject(new Error('Failed to load Google Maps script'));
    document.head.appendChild(script);
  });

  return loadPromise;
}
