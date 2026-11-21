import { HttpClient } from '@angular/common/http';
import { inject, Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { PersonalSinCuenta, RolInterno, UsuarioForm, UsuarioSistema } from '../models';
import { API } from '../utils/api';

// Usuarios del sistema (USUARIOS_SISTEMA). Solo el administrador: el backend responde 403 a otros roles.
@Injectable({ providedIn: 'root' })
export class UsuarioService {
  private http = inject(HttpClient);
  private url = `${API}/usuarios`;

  listar(): Observable<UsuarioSistema[]> {
    return this.http.get<UsuarioSistema[]>(this.url);
  }

  crear(datos: UsuarioForm): Observable<UsuarioSistema> {
    return this.http.post<UsuarioSistema>(this.url, datos);
  }

  cambiarRol(id: number, rol: RolInterno, personalId: number | null = null): Observable<UsuarioSistema> {
    return this.http.patch<UsuarioSistema>(`${this.url}/${id}/rol`, { rol: rol, personalId: personalId });
  }

  // (v11) Guías y conductores del personal que aún no tienen cuenta
  personalSinCuenta(): Observable<PersonalSinCuenta[]> {
    return this.http.get<PersonalSinCuenta[]>(`${this.url}/personal-sin-cuenta`);
  }

  // false: revoca el acceso (INACTIVO) · true: lo restablece (y desbloquea)
  cambiarAcceso(id: number, activo: boolean): Observable<UsuarioSistema> {
    return this.http.patch<UsuarioSistema>(`${this.url}/${id}/acceso`, { activo: activo });
  }

  cambiarClave(id: number, password: string, confirmacion: string): Observable<UsuarioSistema> {
    return this.http.patch<UsuarioSistema>(`${this.url}/${id}/clave`, { password: password, confirmacion: confirmacion });
  }
}
