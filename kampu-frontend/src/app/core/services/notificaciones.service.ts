import { DestroyRef, inject, Injectable, signal } from '@angular/core';
import { Notificacion } from '../models';
import { AuthService } from './auth.service';
import { CampoService } from './campo.service';

// Campana: avisos que escribe la BD (NOTIFICACIONES) para el usuario con sesión. Se consultan cada minuto.
@Injectable({ providedIn: 'root' })
export class NotificacionesService {
  private campo = inject(CampoService);
  private auth = inject(AuthService);
  lista = signal<Notificacion[]>([]);
  sinLeer = signal(0);
  private reloj: ReturnType<typeof setInterval> | null = null;

  constructor() {
    inject(DestroyRef).onDestroy(() => this.detener());
  }

  iniciar() {
    if (this.reloj) return;
    this.cargar();
    this.reloj = setInterval(() => this.cargar(), 60_000);
  }

  detener() {
    if (this.reloj) clearInterval(this.reloj);
    this.reloj = null;
    this.lista.set([]);
    this.sinLeer.set(0);
  }

  cargar() {
    // Solo el personal interno (el cliente del portal no usa la campana)
    if (!this.auth.autenticado() || this.auth.esCliente()) { this.detener(); return; }
    this.campo.notificaciones().subscribe({
      next: l => { this.lista.set(l); this.sinLeer.set(l.filter(n => !n.leida).length); },
      error: () => undefined
    });
  }

  // Quedan leídas en la BD; en pantalla se siguen viendo resaltadas hasta la próxima consulta
  marcarLeidas() {
    if (!this.sinLeer()) return;
    this.sinLeer.set(0);
    this.campo.marcarLeidas().subscribe({ error: () => undefined });
  }
}
