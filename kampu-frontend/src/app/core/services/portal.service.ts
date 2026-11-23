import { HttpClient } from '@angular/common/http';
import { inject, Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { PasajeroDraft, Pago, PortalDetalle, PortalPaquete, PortalPasajero } from '../models';
import { API } from '../utils/api';

// Portal del cliente (v10): VW_PAQUETES_CLIENTE y PKG_GESTION_PAQUETES_CLIENTE (vía backend, conexión KAMPU_WEB)
@Injectable({ providedIn: 'root' })
export class PortalService {
  private http = inject(HttpClient);

  misPaquetes(): Observable<PortalPaquete[]> {
    return this.http.get<PortalPaquete[]>(`${API}/portal/paquetes`);
  }

  detalle(reservaId: number): Observable<PortalDetalle> {
    return this.http.get<PortalDetalle>(`${API}/portal/paquetes/${reservaId}`);
  }

  // El cliente elige paquete + fecha + cantidad (canal WEB; respeta la anticipación mínima del paquete)
  // El punto de recojo lo define la agencia: la reserva queda con el recojo por definir.
  // habitacionId: habitación de hotel, obligatoria si el paquete tiene noches.
  reservar(paqueteId: number, fecha: string, cantidad: number, habitacionId: number | null): Observable<PortalPaquete> {
    return this.http.post<PortalPaquete>(`${API}/portal/reservas`,
      { paqueteId: paqueteId, fecha: fecha, cantidad: cantidad, habitacionId: habitacionId });
  }

  informarPago(reservaId: number, monto: number, metodoPago: string, codigoTransaccion: string): Observable<Pago> {
    return this.http.post<Pago>(`${API}/portal/paquetes/${reservaId}/pagos`,
      { monto: monto, metodoPago: metodoPago, codigoTransaccion: codigoTransaccion });
  }

  registrarPasajero(reservaId: number, p: PasajeroDraft): Observable<PortalPasajero> {
    return this.http.post<PortalPasajero>(`${API}/portal/paquetes/${reservaId}/pasajeros`, {
      nombreCompleto: p.nombreCompleto, tipoDocumento: p.tipoDocumento, numeroDocumento: p.numeroDocumento,
      nacionalidad: p.nacionalidad, fechaNacimiento: p.fechaNacimiento ? p.fechaNacimiento : null
    });
  }

  eliminarPasajero(pasajeroId: number): Observable<void> {
    return this.http.delete<void>(`${API}/portal/pasajeros/${pasajeroId}`);
  }

  // ---------- Invitado sin cuenta: la reserva de su cotización, con el código + clave ----------
  private cot(codigo: string) { return `${API}/cotizaciones/${encodeURIComponent(codigo)}/reserva`; }

  detalleInvitado(codigo: string, clave: string): Observable<PortalDetalle> {
    return this.http.post<PortalDetalle>(this.cot(codigo), { clave });
  }

  informarPagoInvitado(codigo: string, clave: string, monto: number, metodoPago: string, codigoTransaccion: string): Observable<Pago> {
    return this.http.post<Pago>(`${this.cot(codigo)}/pagos`, { clave, pago: { monto, metodoPago, codigoTransaccion } });
  }

  registrarPasajeroInvitado(codigo: string, clave: string, p: PasajeroDraft): Observable<PortalPasajero> {
    return this.http.post<PortalPasajero>(`${this.cot(codigo)}/pasajeros`, { clave, pasajero: {
      nombreCompleto: p.nombreCompleto, tipoDocumento: p.tipoDocumento, numeroDocumento: p.numeroDocumento,
      nacionalidad: p.nacionalidad, fechaNacimiento: p.fechaNacimiento ? p.fechaNacimiento : null
    } });
  }

  eliminarPasajeroInvitado(codigo: string, clave: string, pasajeroId: number): Observable<void> {
    return this.http.post<void>(`${this.cot(codigo)}/pasajeros/${pasajeroId}/eliminar`, { clave });
  }

  solicitarAnulacionInvitado(codigo: string, clave: string, motivo: string): Observable<{ resultado: 'ANULADA' | 'SOLICITUD_REGISTRADA' }> {
    return this.http.post<{ resultado: 'ANULADA' | 'SOLICITUD_REGISTRADA' }>(`${this.cot(codigo)}/anulacion`, { clave, motivo });
  }

  // Sin pagos aprobados se anula al instante; con pagos queda una solicitud para la agencia
  solicitarAnulacion(reservaId: number, motivo: string): Observable<{ resultado: 'ANULADA' | 'SOLICITUD_REGISTRADA' }> {
    return this.http.post<{ resultado: 'ANULADA' | 'SOLICITUD_REGISTRADA' }>(`${API}/portal/paquetes/${reservaId}/anulacion`, { motivo: motivo });
  }
}
