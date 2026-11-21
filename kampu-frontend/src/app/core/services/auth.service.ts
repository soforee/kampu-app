import { HttpClient } from '@angular/common/http';
import { computed, inject, Injectable, signal } from '@angular/core';
import { Observable } from 'rxjs';
import { Permiso, RegistroForm, Sesion } from '../models';
import { API } from '../utils/api';

const KEY = 'tm4_session';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private http = inject(HttpClient);
  private sesion = signal<Sesion | null>(this.cargar());
  usuario = computed(() => this.sesion());
  autenticado = computed(() => this.sesion() !== null);
  esCliente = computed(() => this.sesion()?.rol === 'CLIENTE');
  // (v11) Guía o conductor con cuenta: solo ven sus asignaciones
  esCampo = computed(() => this.sesion()?.rol === 'GUIA' || this.sesion()?.rol === 'CONDUCTOR');
  rol = computed(() => this.sesion()?.rol ?? null);
  // Permisos de la sesión (PKG_SEGURIDAD_ROLES.permisos): menú, rutas y botones dependen de esto
  permisos = computed(() => new Set<string>(this.sesion()?.permisos ?? []));

  puede(permiso: Permiso): boolean {
    return this.permisos().has(permiso);
  }

  private cargar(): Sesion | null {
    const texto = localStorage.getItem(KEY);
    if (!texto) return null;
    try {
      const s = JSON.parse(texto);
      // Sesiones guardadas antes de v11 no tienen token firmado: hay que volver a entrar
      return s && s.username && s.rol && s.token ? { ...s, permisos: Array.isArray(s.permisos) ? s.permisos : [] } : null;
    } catch {
      return null;
    }
  }

  // Personal interno: usuario · Cliente: correo o número de documento
  login(username: string, password: string): Observable<Sesion> {
    return this.http.post<Sesion>(`${API}/auth/login`, { username: username.trim(), password: password });
  }

  // "Registrarse": crea la cuenta del cliente y devuelve la sesión iniciada
  registrar(d: RegistroForm): Observable<Sesion> {
    return this.http.post<Sesion>(`${API}/auth/registro`, d);
  }

  guardarSesion(s: Sesion) {
    this.sesion.set(s);
    localStorage.setItem(KEY, JSON.stringify(s));
  }

  // Ruta de inicio según el rol
  inicio(): string {
    return this.esCliente() ? '/mi-cuenta' : this.esCampo() ? '/mis-asignaciones' : '/dashboard';
  }

  logout() {
    if (this.sesion()) this.http.post(`${API}/auth/logout`, {}).subscribe({ error: () => undefined });
    this.olvidar();
  }

  // Borra la sesión guardada en el navegador
  olvidar() {
    this.sesion.set(null);
    localStorage.removeItem(KEY);
  }
}
