import { HttpClient } from '@angular/common/http';
import { inject, Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { API, IMAGENES } from '../utils/api';

const MAX_MB = 10;
const TIPOS = ['image/jpeg', 'image/png', 'image/webp'];

@Injectable({ providedIn: 'root' })
export class ImagenService {
  private http = inject(HttpClient);

  url(ref?: string | null): string | null {
    const ruta = ref?.trim().replace(/^\/+/, '');
    return ruta ? `${IMAGENES}/${ruta}` : null;
  }

  validar(file: File): string {
    if (!TIPOS.includes(file.type)) return 'El archivo debe ser una imagen (JPG, PNG o WebP).';
    if (file.size > MAX_MB * 1024 * 1024) return `La imagen supera los ${MAX_MB} MB.`;
    return '';
  }

  subirHabitacion(file: File): Observable<{ imagen: string }> {
    const formData = new FormData();
    formData.append('file', file);
    return this.http.post<{ imagen: string }>(`${API}/habitaciones/imagen`, formData);
  }

  subir(file: File): Observable<{ imagen: string }> {
    const formData = new FormData();
    formData.append('file', file);
    return this.http.post<{ imagen: string }>(`${API}/paquetes/imagen`, formData);
  }
}
