import { HttpClient } from '@angular/common/http';
import { inject, Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import {
  CalculoCotizacion, Cotizacion, CotizacionCreada, DatosCotizacion, EstadoCotizacion, ServicioAdicional, SolicitudReserva, HabitacionCotizable } from '../models';
import { API } from '../utils/api';

/**
 * (v11) Cotizaciones. El visitante opera la suya con código + clave (la clave va siempre en el cuerpo,
 * nunca en la URL). Los montos los calcula el servidor: aquí solo se envía lo que el visitante elige.
 */
@Injectable({ providedIn: 'root' })
export class CotizacionService {
  private http = inject(HttpClient);
  private url = `${API}/cotizaciones`;

  serviciosDe(paqueteId: number): Observable<ServicioAdicional[]> {
    return this.http.get<ServicioAdicional[]>(`${API}/servicios-adicionales/paquete/${paqueteId}`);
  }

  calcular(d: DatosCotizacion): Observable<CalculoCotizacion> {
    return this.http.post<CalculoCotizacion>(`${this.url}/calcular`, d);
  }

  crear(d: DatosCotizacion): Observable<CotizacionCreada> {
    return this.http.post<CotizacionCreada>(this.url, d);
  }

  // clave vacía: el cliente con sesión abre las suyas
  // Habitaciones de hotel de proveedores de hospedaje (sección 5 del cotizador)
  habitaciones(): Observable<HabitacionCotizable[]> {
    return this.http.get<HabitacionCotizable[]>(`${this.url}/habitaciones`);
  }

  abrir(codigo: string, clave: string): Observable<Cotizacion> {
    return this.http.post<Cotizacion>(`${this.url}/acceso`, { codigo: codigo, clave: clave });
  }

  modificar(codigo: string, clave: string, d: DatosCotizacion): Observable<Cotizacion> {
    return this.http.put<Cotizacion>(`${this.url}/${encodeURIComponent(codigo)}`, { clave: clave, datos: d });
  }

  solicitar(codigo: string, clave: string, s: SolicitudReserva): Observable<Cotizacion> {
    return this.http.post<Cotizacion>(`${this.url}/${encodeURIComponent(codigo)}/solicitud`, { ...s, clave: clave });
  }

  cancelar(codigo: string, clave: string): Observable<Cotizacion> {
    return this.http.post<Cotizacion>(`${this.url}/${encodeURIComponent(codigo)}/cancelacion`, { clave: clave });
  }

  pdf(codigo: string, clave: string): Observable<Blob> {
    return this.http.post(`${this.url}/${encodeURIComponent(codigo)}/pdf`, { clave: clave }, { responseType: 'blob' });
  }

  // Cliente con cuenta
  mias(): Observable<Cotizacion[]> {
    return this.http.get<Cotizacion[]>(`${this.url}/mias`);
  }

  // Personal (VER_/GESTIONAR_COTIZACIONES)
  listar(estado: EstadoCotizacion | '' = ''): Observable<Cotizacion[]> {
    return this.http.get<Cotizacion[]>(this.url, { params: estado ? { estado: estado } : {} });
  }

  detalle(id: number): Observable<Cotizacion> {
    return this.http.get<Cotizacion>(`${this.url}/gestion/${id}`);
  }

  pdfPersonal(id: number): Observable<Blob> {
    return this.http.get(`${this.url}/gestion/${id}/pdf`, { responseType: 'blob' });
  }

  confirmar(id: number): Observable<Cotizacion> {
    return this.http.post<Cotizacion>(`${this.url}/gestion/${id}/confirmar`, {});
  }

  rechazar(id: number, motivo: string): Observable<Cotizacion> {
    return this.http.post<Cotizacion>(`${this.url}/gestion/${id}/rechazar`, { motivo: motivo });
  }
}

// Guarda un archivo descargado (PDF) con su nombre
export function guardarArchivo(blob: Blob, nombre: string) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = nombre;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
