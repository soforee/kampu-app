import { HttpClient } from '@angular/common/http';
import { inject, Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { Disponibilidad, Incidencia, MiVehiculo, Notificacion, PasajeroTraslado, TipoIncidencia, TrasladoConductor } from '../models';
import { API } from '../utils/api';

// Panel de campo (guía y conductor): todo pasa por PKG_CAMPO, que solo actúa sobre lo asignado a la sesión
@Injectable({ providedIn: 'root' })
export class CampoService {
  private http = inject(HttpClient);
  private url = `${API}/mis-asignaciones`;

  // En camino (EMBARQUE) -> pasajeros a bordo (EN_RUTA) -> finalizado
  avanzar(operacionId: number, estado: 'EMBARQUE' | 'EN_RUTA' | 'FINALIZADO'): Observable<TrasladoConductor> {
    return this.http.post<TrasladoConductor>(`${this.url}/traslados/${operacionId}/estado`, { estado });
  }
  pasajeros(operacionId: number): Observable<PasajeroTraslado[]> {
    return this.http.get<PasajeroTraslado[]>(`${this.url}/traslados/${operacionId}/pasajeros`);
  }
  abordaje(operacionId: number, pasajeroId: number, abordo: boolean): Observable<TrasladoConductor> {
    return this.http.put<TrasladoConductor>(`${this.url}/traslados/${operacionId}/pasajeros/${pasajeroId}`, { abordo });
  }

  historial(f: { desde?: string; hasta?: string; ruta?: string; placa?: string }): Observable<TrasladoConductor[]> {
    const params: { [k: string]: string } = {};
    for (const [k, v] of Object.entries(f)) if (v) params[k] = v;
    return this.http.get<TrasladoConductor[]>(`${this.url}/historial`, { params });
  }

  vehiculo(): Observable<MiVehiculo> { return this.http.get<MiVehiculo>(`${this.url}/vehiculo`); }
  jornada(vehiculoId: number, d: { kmInicial: number | null; combustibleInicial: string; kmFinal: number | null; combustibleFinal: string; observaciones: string }): Observable<MiVehiculo> {
    return this.http.put<MiVehiculo>(`${this.url}/vehiculo/${vehiculoId}/jornada`, d);
  }

  misIncidencias(): Observable<Incidencia[]> { return this.http.get<Incidencia[]>(`${this.url}/incidencias`); }
  reportar(d: { operacionId: number | null; tipo: TipoIncidencia; descripcion: string }): Observable<{ incidenciaId: number }> {
    return this.http.post<{ incidenciaId: number }>(`${this.url}/incidencias`, d);
  }

  disponibilidad(desde: string, hasta: string): Observable<Disponibilidad> {
    return this.http.get<Disponibilidad>(`${this.url}/disponibilidad`, { params: { desde, hasta } });
  }
  bloquear(d: { inicio: string; fin: string; motivo: string }): Observable<{ bloqueoId: number }> {
    return this.http.post<{ bloqueoId: number }>(`${this.url}/bloqueos`, d);
  }
  desbloquear(bloqueoId: number): Observable<void> { return this.http.delete<void>(`${this.url}/bloqueos/${bloqueoId}`); }

  // Agencia: novedades del personal de campo
  incidencias(): Observable<Incidencia[]> { return this.http.get<Incidencia[]>(`${API}/incidencias`); }
  atender(incidenciaId: number, respuesta: string): Observable<void> {
    return this.http.post<void>(`${API}/incidencias/${incidenciaId}/atender`, { respuesta });
  }

  // Campana: avisos del usuario
  notificaciones(): Observable<Notificacion[]> { return this.http.get<Notificacion[]>(`${API}/notificaciones`); }
  marcarLeidas(): Observable<void> { return this.http.post<void>(`${API}/notificaciones/leidas`, {}); }
  contacto(): Observable<{ telefono: string; email: string }> { return this.http.get<{ telefono: string; email: string }>(`${API}/contacto`); }
}
