// Enlaces para navegar y contactar desde el celular del personal de campo

// Google Maps con indicaciones hasta el destino (coordenadas o, si faltan, la dirección/nombre)
export function rutaGoogle(lat: number | null | undefined, lon: number | null | undefined, texto?: string | null): string {
  const destino = lat != null && lon != null ? `${lat},${lon}` : encodeURIComponent(texto ?? '');
  return `https://www.google.com/maps/dir/?api=1&destination=${destino}&travelmode=driving`;
}

// Waze: con coordenadas navega directo; sin ellas busca el texto
export function rutaWaze(lat: number | null | undefined, lon: number | null | undefined, texto?: string | null): string {
  return lat != null && lon != null
    ? `https://waze.com/ul?ll=${lat},${lon}&navigate=yes`
    : `https://waze.com/ul?q=${encodeURIComponent(texto ?? '')}&navigate=yes`;
}

// Solo dígitos; si es un celular peruano de 9 dígitos se antepone 51
export function digitosTelefono(tel?: string | null): string {
  const d = (tel ?? '').replace(/\D/g, '');
  return d.length === 9 && d.startsWith('9') ? '51' + d : d;
}
export function enlaceWhatsapp(tel?: string | null, texto = ''): string {
  return `https://wa.me/${digitosTelefono(tel)}${texto ? '?text=' + encodeURIComponent(texto) : ''}`;
}
export function enlaceLlamada(tel?: string | null): string {
  return `tel:+${digitosTelefono(tel)}`;
}
