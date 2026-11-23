import { ParamMap } from '@angular/router';

export interface ReservaPendiente {
  reservar: number;
  fecha?: string;
  cantidad?: number;
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
