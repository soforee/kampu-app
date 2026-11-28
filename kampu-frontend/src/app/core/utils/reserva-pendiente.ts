import { ParamMap } from '@angular/router';

export interface ReservaPendiente {
  reservar: number;
  fecha?: string;
  cantidad?: number;
}

const CLAVE_LOCAL = 'kampu_reserva_pendiente';

export function guardarReservaPendienteLocal(p: ReservaPendiente | null) {
  try {
    if (p) localStorage.setItem(CLAVE_LOCAL, JSON.stringify(p));
    else localStorage.removeItem(CLAVE_LOCAL);
  } catch {
  }
}

export function tomarReservaPendienteLocal(): ReservaPendiente | null {
  try {
    const texto = localStorage.getItem(CLAVE_LOCAL);
    localStorage.removeItem(CLAVE_LOCAL);
    const p = texto ? JSON.parse(texto) : null;
    return p && Number.isInteger(p.reservar) && p.reservar > 0 ? p : null;
  } catch {
    return null;
  }
}

export function leerReservaPendiente(q: ParamMap): ReservaPendiente | null {
  const reservar = Number(q.get('reservar'));
  if (!Number.isInteger(reservar) || reservar <= 0) return null;
  const fecha = q.get('fecha') ?? '';
  const cantidad = Number(q.get('cantidad'));
  return {
    reservar: reservar,
    fecha: /^\d{4}-\d{2}-\d{2}$/.test(fecha) ? fecha : undefined,
    cantidad: Number.isInteger(cantidad) && cantidad >= 1 && cantidad <= 99 ? cantidad : undefined
  };
}
