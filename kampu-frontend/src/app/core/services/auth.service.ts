import { HttpClient } from '@angular/common/http';
import { computed, inject, Injectable, signal } from '@angular/core';
import { Observable } from 'rxjs';
import { Permiso, RegistroForm, RegistroPendiente, Sesion } from '../models';
import { API } from '../utils/api';

const KEY = 'tm4_session';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private http = inject(HttpClient);
  private sesion = signal<Sesion | null>(this.cargar());
  usuario = computed(() => this.sesion());
  autenticado = computed(() => this.sesion() !== null);
  esCliente = computed(() => this.sesion()?.rol === 'CLIENTE');
  esCampo = computed(() => this.sesion()?.rol === 'GUIA' || this.sesion()?.rol === 'CONDUCTOR');
  rol = computed(() => this.sesion()?.rol ?? null);
  permisos = computed(() => new Set<string>(this.sesion()?.permisos ?? []));

  puede(permiso: Permiso): boolean {
    return this.permisos().has(permiso);
  }

  private cargar(): Sesion | null {
    const texto = localStorage.getItem(KEY);
    if (!texto) return null;
    try {
      const s = JSON.parse(texto);
      return s && s.username && s.rol && s.token ? { ...s, permisos: Array.isArray(s.permisos) ? s.permisos : [] } : null;
    } catch {
      return null;
    }
  }

  login(username: string, password: string): Observable<Sesion> {
    return this.http.post<Sesion>(`${API}/auth/login`, { username: username.trim(), password: password });
  }

  registrar(d: RegistroForm): Observable<RegistroPendiente> {
    return this.http.post<RegistroPendiente>(`${API}/auth/registro`, d);
  }

  confirmarCorreo(token: string): Observable<Sesion> {
    return this.http.post<Sesion>(`${API}/auth/confirmar`, { token });
  }

  reenviarConfirmacion(email: string): Observable<void> {
    return this.http.post<void>(`${API}/auth/reenviar-confirmacion`, { email });
  }

  guardarSesion(s: Sesion) {
    this.sesion.set(s);
    localStorage.setItem(KEY, JSON.stringify(s));
  }

  inicio(): string {
    return this.esCliente() ? '/mi-cuenta' : this.esCampo() ? '/mis-asignaciones' : '/dashboard';
  }

  logout() {
    if (this.sesion()) this.http.post(`${API}/auth/logout`, {}).subscribe({ error: () => undefined });
    this.olvidar();
  }

  olvidar() {
    this.sesion.set(null);
    localStorage.removeItem(KEY);
  }
}
