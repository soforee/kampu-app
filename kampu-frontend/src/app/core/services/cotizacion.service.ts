import { HttpClient } from '@angular/common/http';
import { inject, Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { Cotizacion } from '../models';
import { API } from '../utils/api';

// Cotización pública: no necesita sesión ni crea nada en la base de datos
@Injectable({ providedIn: 'root' })
export class CotizacionService {
  private http = inject(HttpClient);

  cotizar(paqueteId: number, fecha: string, cantidad: number, lugarRecojoId: number | null): Observable<Cotizacion> {
    return this.http.post<Cotizacion>(`${API}/cotizaciones`,
      { paqueteId: paqueteId, fecha: fecha, cantidad: cantidad, lugarRecojoId: lugarRecojoId });
  }
}
