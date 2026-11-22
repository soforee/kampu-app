import { Component, HostListener, computed, inject, signal } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { NavigationEnd, Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { filter, map } from 'rxjs';
import { AlertasService } from '../core/services/alertas.service';
import { AuthService } from '../core/services/auth.service';
import { TourStore } from '../core/services/tour-store.service';
import { AlertService } from '../core/services/alert.service';
import { IconComponent } from '../shared/icon.component';
import { LogoComponent } from '../shared/logo.component';
import { etiqueta } from '../core/utils/etiquetas';
import { Permiso } from '../core/models';

@Component({
  selector: 'app-shell',
  standalone: true,
  imports: [RouterOutlet, RouterLink, RouterLinkActive, IconComponent, LogoComponent],
  templateUrl: './shell.component.html',
  styleUrl: './shell.component.css'
})
export class ShellComponent {
  auth = inject(AuthService);
  private store = inject(TourStore);
  private router = inject(Router);
  private alerts = inject(AlertService);
  private avisos = inject(AlertasService);

  abierto = signal(false);
  // Escritorio: menú compacto (solo íconos, con nombre al pasar el cursor) o desplegado; se recuerda en este navegador
  compacto = signal(this.leerPreferencia());
  // Desplegables de la barra superior: 'busqueda' | 'avisos' | 'usuario' | null
  desplegado = signal<string | null>(null);
  consulta = signal('');
  alertas = this.avisos.lista;

  // Sección actual (título de la barra superior), según la ruta
  private url = toSignal(this.router.events.pipe(filter(e => e instanceof NavigationEnd), map(() => this.router.url)), { initialValue: this.router.url });

  // Menú según los permisos de la sesión (mismos que exigen app.routes.ts y el backend)
  private todo: { ruta: string; texto: string; icono: string; permiso?: Permiso }[] = [
    { ruta: '/dashboard', texto: 'Panel', icono: 'chart', permiso: 'VER_RESUMEN' },
    { ruta: '/mis-asignaciones', texto: 'Mis asignaciones', icono: 'flag', permiso: 'VER_ASIGNACIONES_PROPIAS' },
    { ruta: '/cotizaciones', texto: 'Cotizaciones', icono: 'inbox', permiso: 'VER_COTIZACIONES' },
    { ruta: '/reservas', texto: 'Reservas', icono: 'ticket', permiso: 'VER_RESERVAS' },
    { ruta: '/salidas', texto: 'Salidas', icono: 'calendar', permiso: 'VER_RESUMEN' },
    { ruta: '/paquetes', texto: 'Paquetes', icono: 'package', permiso: 'GESTIONAR_CATALOGO' },
    { ruta: '/servicios-adicionales', texto: 'Adicionales', icono: 'tag', permiso: 'GESTIONAR_CATALOGO' },
    { ruta: '/pagos', texto: 'Pagos', icono: 'card', permiso: 'VER_MONTOS' },
    { ruta: '/clientes', texto: 'Clientes', icono: 'users', permiso: 'VER_CLIENTES' },
    { ruta: '/operaciones', texto: 'Tráfico', icono: 'truck', permiso: 'VER_OPERACIONES' },
    { ruta: '/recursos', texto: 'Logística', icono: 'map-pin', permiso: 'VER_LOGISTICA' },
    { ruta: '/usuarios', texto: 'Usuarios', icono: 'id', permiso: 'GESTIONAR_USUARIOS' },
    { ruta: '/auditoria', texto: 'Auditoría', icono: 'file-text', permiso: 'VER_AUDITORIA' }
  ];
  menu = computed(() => this.todo.filter(m => !m.permiso || this.auth.puede(m.permiso)));
  seccion = computed(() => this.todo.find(m => this.url().startsWith(m.ruta)) ?? this.todo[0]);

  // Búsqueda global sobre los datos ya cargados (solo lo que el rol puede ver)
  resultados = computed(() => {
    const q = this.consulta().trim().toLowerCase();
    if (q.length < 2) return [];
    const r: { tipo: string; icono: string; texto: string; detalle: string; ruta: (string | number)[] }[] = [];
    const tiene = (...t: (string | null | undefined)[]) => t.some(x => (x ?? '').toLowerCase().includes(q));
    if (this.auth.puede('VER_RESERVAS')) {
      for (const x of this.store.reservas()) {
        const codigo = this.store.codigoReserva(x.reservaId), cliente = this.store.nombreCliente(x);
        if (tiene(codigo, cliente)) r.push({ tipo: 'Reserva', icono: 'ticket', texto: codigo + ' · ' + cliente, detalle: this.store.getPaquete(this.store.getSalida(x.salidaId)?.paqueteId)?.nombre ?? '', ruta: ['/reservas', x.reservaId] });
      }
    }
    if (this.auth.puede('VER_CLIENTES')) {
      for (const c of this.store.clientes()) {
        if (tiene(c.nombreCompleto, c.numeroDocumento, c.email)) r.push({ tipo: 'Cliente', icono: 'users', texto: c.nombreCompleto, detalle: c.tipoDocumento + ' ' + c.numeroDocumento, ruta: ['/clientes'] });
      }
    }
    if (this.auth.puede('VER_RESUMEN')) {
      for (const x of this.store.salidas()) {
        const nombre = this.store.getPaquete(x.paqueteId)?.nombre ?? '';
        if (tiene(nombre)) r.push({ tipo: 'Salida', icono: 'calendar', texto: nombre, detalle: x.fechaInicio, ruta: ['/salidas', x.salidaId] });
      }
    }
    return r.slice(0, 8);
  });

  irA(ruta: (string | number)[]) {
    this.desplegado.set(null);
    this.consulta.set('');
    this.router.navigate(ruta);
  }

  alternar(panel: string) {
    this.desplegado.set(this.desplegado() === panel ? null : panel);
  }

  // Cierra los desplegables al hacer clic fuera de la barra superior
  @HostListener('document:click', ['$event'])
  clicFuera(e: MouseEvent) {
    if (!(e.target as HTMLElement).closest('[data-barra]')) this.desplegado.set(null);
  }
  rolTexto = computed(() => etiqueta(this.auth.rol()));

  pendientes = computed(() => this.store.reservas().filter(r => r.estadoReserva === 'PENDIENTE').length);
  iniciales = computed(() => (this.auth.usuario()?.username ?? '?').slice(0, 2).toUpperCase());

  constructor() {
    if (!this.auth.autenticado()) {
      this.router.navigate(['/login']);
      return;
    }
    this.cargarDatos();
  }

  private cargarDatos() {
    this.store.cargar(true, error => {
      if (error && this.auth.autenticado()) this.alerts.error(error, 'No se pudieron cargar los datos');
    });
  }

  // Tooltip del menú compacto (solo escritorio): se ubica a la altura del ícono, fuera del menú
  tip = signal<{ texto: string; top: number } | null>(null);
  mostrarTip(texto: string, e: Event) {
    if (!this.compacto() || window.innerWidth < 1024) return;
    const r = (e.currentTarget as HTMLElement).getBoundingClientRect();
    this.tip.set({ texto, top: Math.round(r.top + r.height / 2) });
  }

  alternarMenu() {
    this.tip.set(null);
    this.compacto.set(!this.compacto());
    try { localStorage.setItem('kampu.menuCompacto', this.compacto() ? '1' : '0'); } catch { /* sin almacenamiento: solo dura la sesión */ }
  }

  private leerPreferencia() {
    try { return localStorage.getItem('kampu.menuCompacto') === '1'; } catch { return false; }
  }

  async salir() {
    if (await this.alerts.confirm('Se cerrará tu sesión actual.', 'Cerrar sesión', 'Cerrar sesión')) {
      this.auth.logout();
      this.store.limpiar();
      this.router.navigate(['/login']);
    }
  }
}
