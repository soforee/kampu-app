import { Component, DestroyRef, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { mensajeError } from '../../core/utils/api';
import { leerReservaPendiente } from '../../core/utils/reserva-pendiente';
import { AuthService } from '../../core/services/auth.service';
import { LogoComponent } from '../../shared/logo.component';
import { IconComponent } from '../../shared/icon.component';
import { FOTOS_DESTINOS } from '../landing/landing.models';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [FormsModule, RouterLink, LogoComponent, IconComponent],
  templateUrl: './login.component.html',
  styleUrl: './login.component.css'
})
export class LoginComponent {
  private auth = inject(AuthService);
  private router = inject(Router);
  // ?reservar=<paqueteId>: llega desde una cotización de la página principal; el cliente sigue a reservar ese paquete
  private pendiente = leerReservaPendiente(inject(ActivatedRoute).snapshot.queryParamMap);

  username = '';
  password = '';
  ver = signal(false);
  error = signal('');
  cargando = signal(false);
  // Se marca al intentar ingresar: desde ahí cada campo vacío muestra su propio mensaje
  enviado = signal(false);
  mayusculas = signal(false);

  // Fotos del panel izquierdo (las mismas de la página principal), cambian cada 7 s
  fotos = FOTOS_DESTINOS.filter(f => ['machu', 'colca', 'titicaca', 'ollantaytambo'].includes(f.clave));
  foto = signal(0);

  constructor() {
    if (this.auth.autenticado()) this.router.navigateByUrl(this.auth.inicio());
    const reducido = typeof matchMedia !== 'undefined' && matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (!reducido) {
      const id = setInterval(() => this.foto.set((this.foto() + 1) % this.fotos.length), 7000);
      inject(DestroyRef).onDestroy(() => clearInterval(id));
    }
  }

  faltaUsuario() { return this.enviado() && !this.username.trim(); }
  faltaClave() { return this.enviado() && !this.password; }

  // Al escribir se oculta el error del servidor; el aviso de mayúsculas ayuda a no fallar la contraseña
  escribiendo() { if (this.error()) this.error.set(''); }
  revisarMayusculas(e: KeyboardEvent) {
    if (typeof e.getModifierState === 'function') this.mayusculas.set(e.getModifierState('CapsLock'));
  }

  entrar() {
    this.enviado.set(true);
    if (!this.username.trim() || !this.password) {
      this.error.set('');
      return;
    }
    this.error.set('');
    this.cargando.set(true);
    this.auth.login(this.username, this.password).subscribe({
      next: (sesion) => {
        this.auth.guardarSesion(sesion);
        // Personal interno -> panel · Cliente -> "Mis paquetes" (con el paquete cotizado listo para reservar)
        if (this.auth.esCliente() && this.pendiente) this.router.navigate(['/mi-cuenta'], { queryParams: { ...this.pendiente } });
        else this.router.navigateByUrl(this.auth.inicio());
      },
      error: (err) => {
        this.error.set(mensajeError(err));
        this.cargando.set(false);
      }
    });
  }
}
