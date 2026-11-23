import { DatePipe } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { CambioRolForm, CategoriaLicencia, EstadoUsuario, RolInterno, UsuarioForm, UsuarioSistema } from '../../core/models';
import { filtrarEscritura, filtrarPegado } from '../../core/utils/filtro';
import { hoy } from '../../core/utils/date.util';
import { AlertService } from '../../core/services/alert.service';
import { AuthService } from '../../core/services/auth.service';
import { UsuarioService } from '../../core/services/usuario.service';
import { TourStore } from '../../core/services/tour-store.service';
import { mensajeError } from '../../core/utils/api';
import { etiqueta } from '../../core/utils/etiquetas';
import { FormValidacion, V } from '../../core/utils/validacion';
import { BadgeComponent } from '../../shared/badge.component';
import { BuscadorComponent } from '../../shared/buscador.component';
import { IconComponent } from '../../shared/icon.component';
import { ModalComponent } from '../../shared/modal.component';
import { PageHeaderComponent } from '../../shared/page-header.component';
import { PaginacionComponent } from '../../shared/paginacion.component';

const PASSWORD_MIN = 8;
type FiltroRol = 'TODOS' | RolInterno | 'CAMPO';

@Component({
  selector: 'app-usuarios',
  standalone: true,
  imports: [FormsModule, DatePipe, PageHeaderComponent, BuscadorComponent, PaginacionComponent, IconComponent, ModalComponent, BadgeComponent],
  templateUrl: './usuarios.component.html'
})
export class UsuariosComponent {
  private api = inject(UsuarioService);
  private store = inject(TourStore);
  private alerts = inject(AlertService);
  auth = inject(AuthService);

  min = PASSWORD_MIN;
  etiqueta = etiqueta;

  roles: { valor: RolInterno; texto: string; icono: string; detalle: string }[] = [
    { valor: 'ADMIN', texto: 'Administrador', icono: 'lock', detalle: 'Acceso completo: usuarios, auditoría, ventas, catálogo, logística y operaciones.' },
    { valor: 'VENTAS', texto: 'Ventas', icono: 'ticket', detalle: 'Clientes, reservas, pagos, cotizaciones y catálogo de paquetes. Sin usuarios ni gestión de flota.' },
    { valor: 'GUIA', texto: 'Guía', icono: 'flag', detalle: 'Solo sus salidas: itinerario, manifiesto y recojos. Sin montos ni clientes.' },
    { valor: 'CONDUCTOR', texto: 'Conductor', icono: 'map-pin', detalle: 'Solo sus traslados: vehículo, ruta y recojos. Sin montos ni clientes.' }
  ];
  esCampo = (rol: RolInterno) => rol === 'GUIA' || rol === 'CONDUCTOR';
  mismoGrupo = (a: RolInterno, b: RolInterno) => this.esCampo(a) === this.esCampo(b);
  categorias: CategoriaLicencia[] = ['A-I', 'A-IIa', 'A-IIb', 'A-IIIa', 'A-IIIb', 'A-IIIc'];

  usuarios = signal<UsuarioSistema[]>([]);
  cargando = signal(true);
  error = signal('');
  ocupado = signal(false);
  resaltado = signal<number | null>(null);

  texto = signal('');
  filtroRol = signal<FiltroRol>('TODOS');
  filtros: { valor: FiltroRol; texto: string }[] = [
    { valor: 'TODOS', texto: 'Todos' }, { valor: 'ADMIN', texto: 'Administradores' },
    { valor: 'VENTAS', texto: 'Ventas' }, { valor: 'CAMPO', texto: 'Guías y conductores' }
  ];
  private cumple = (u: UsuarioSistema, f: FiltroRol) => f === 'TODOS' || u.rol === f || (f === 'CAMPO' && this.esCampo(u.rol));
  contar = (f: FiltroRol) => this.usuarios().filter(u => this.cumple(u, f)).length;

  filas = computed(() => {
    const t = this.texto().trim().toLowerCase();
    const r = this.filtroRol();
    return this.usuarios()
      .filter(u => this.cumple(u, r))
      .filter(u => !t || u.username.toLowerCase().includes(t) || u.nombreCompleto.toLowerCase().includes(t) || u.email.toLowerCase().includes(t));
  });
  pagina = signal(0);
  visibles = computed(() => {
    const filas = this.filas();
    const pagina = Math.min(this.pagina(), Math.max(0, Math.ceil(filas.length / 10) - 1));
    return filas.slice(pagina * 10, pagina * 10 + 10);
  });

  abierto = signal(false);
  verClave = signal(false);
  form: UsuarioForm = this.vacio();
  v = new FormValidacion(() => ({
    nombre: V.nombrePersona(this.form.nombreCompleto),
    documento: !this.esCampo(this.form.rol) ? null
      : !this.form.numeroDocumento.trim() ? 'El documento es obligatorio.'
      : /^[A-Za-z0-9]{6,20}$/.test(this.form.numeroDocumento.trim()) ? null : 'El documento solo admite letras y números (6 a 20 caracteres).',
    telefono: !this.esCampo(this.form.rol) ? null
      : !this.form.telefono.trim() ? 'El teléfono es obligatorio.' : V.telefono(this.form.telefono),
    ...this.erroresLicencia(this.form.rol === 'CONDUCTOR', this.form),
    username: this.errorUsername(),
    email: this.form.email.trim() ? V.email(this.form.email) ?? this.emailRepetido() : 'El correo es obligatorio.',
    password: this.errorClave(this.form.password),
    confirmacion: !this.form.confirmacion ? 'Repite la contraseña.'
      : this.form.confirmacion !== this.form.password ? 'Las contraseñas no coinciden.' : null
  }));

  editando = signal<UsuarioSistema | null>(null);
  cambio: CambioRolForm = { rol: 'VENTAS', numLicencia: '', catLicencia: '', vencLicencia: '' };
  vr = new FormValidacion(() => this.erroresLicencia(this.cambio.rol === 'CONDUCTOR' && this.editando()?.rol !== 'CONDUCTOR', this.cambio));

  claveDe = signal<UsuarioSistema | null>(null);
  clave = { password: '', confirmacion: '' };
  vc = new FormValidacion(() => ({
    password: this.errorClave(this.clave.password),
    confirmacion: !this.clave.confirmacion ? 'Repite la contraseña.'
      : this.clave.confirmacion !== this.clave.password ? 'Las contraseñas no coinciden.' : null
  }));

  constructor() {
    this.cargar();
  }

  cargar() {
    this.cargando.set(true);
    this.error.set('');
    this.api.listar().subscribe({
      next: lista => { this.usuarios.set(lista); this.cargando.set(false); },
      error: e => { this.error.set(mensajeError(e)); this.cargando.set(false); }
    });
  }

  esYo(u: UsuarioSistema) { return u.usuarioId === this.auth.usuario()?.usuarioId; }
  rolInfo(rol: RolInterno) { return this.roles.find(r => r.valor === rol)!; }

  private vacio(): UsuarioForm {
    return { username: '', nombreCompleto: '', email: '', rol: 'VENTAS', numeroDocumento: '', telefono: '',
      numLicencia: '', catLicencia: '', vencLicencia: '', password: '', confirmacion: '' };
  }

  private erroresLicencia(conduce: boolean, f: { numLicencia: string; catLicencia: string; vencLicencia: string }) {
    const lic = f.numLicencia.trim();
    return {
      licencia: !conduce ? null : !lic ? 'Ingresa el número de licencia.'
        : /^[A-Za-z0-9]{6,20}$/.test(lic) ? null : 'La licencia solo admite letras y números (6 a 20 caracteres).',
      categoria: conduce && !f.catLicencia ? 'Elige la categoría de la licencia.' : null,
      vencimiento: !conduce ? null : V.fecha(f.vencLicencia, 'La fecha de vencimiento')
        ?? (f.vencLicencia < hoy() ? 'La licencia está vencida.' : null)
    };
  }

  filtrar(evento: Event, tipo: string) { filtrarEscritura(evento, tipo); }
  pegar(evento: Event, tipo: string) { filtrarPegado(evento, tipo); }

  private errorUsername(): string | null {
    const u = this.form.username.trim();
    if (!u) return 'El nombre de usuario es obligatorio.';
    if (u.length < 3 || u.length > 50) return 'El usuario debe tener entre 3 y 50 caracteres.';
    if (!/^[A-Za-z0-9._-]+$/.test(u)) return 'Solo letras, números y los signos . _ - (sin espacios ni @).';
    return this.usuarios().some(x => x.username.toLowerCase() === u.toLowerCase()) ? 'Ese nombre de usuario ya existe.' : null;
  }

  private emailRepetido(): string | null {
    const e = this.form.email.trim().toLowerCase();
    return this.usuarios().some(x => x.email.toLowerCase() === e) ? 'Ese correo ya está registrado para otro usuario.' : null;
  }

  private errorClave(p: string): string | null {
    if (p.length < PASSWORD_MIN) return `La contraseña debe tener al menos ${PASSWORD_MIN} caracteres.`;
    return p.length > 64 ? 'La contraseña admite máximo 64 caracteres.' : null;
  }

  fuerza(p: string): number {
    let n = 0;
    if (p.length >= PASSWORD_MIN) n++;
    if (/[A-Z]/.test(p) && /[a-z]/.test(p)) n++;
    if (/\d/.test(p)) n++;
    if (/[^A-Za-z0-9]/.test(p) || p.length >= 12) n++;
    return n;
  }

  sugerirUsuario() {
    if (this.form.username.trim()) return;
    const partes = this.form.nombreCompleto.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()
      .replace(/[^a-z ]/g, '').trim().split(/\s+/).filter(Boolean);
    if (partes.length >= 2) this.form.username = (partes[0][0] + partes[1]).slice(0, 50);
  }

  elegirRol(rol: RolInterno) {
    this.form.rol = rol;
  }

  nuevo() {
    this.form = this.vacio();
    this.verClave.set(false);
    this.v.reiniciar();
    this.abierto.set(true);
  }

  crear() {
    if (this.ocupado()) return;
    if (!this.v.valido()) { this.alerts.toast('Revisa los campos marcados en rojo', 'error'); return; }
    const datos: UsuarioForm = {
      ...this.form,
      username: this.form.username.trim(),
      nombreCompleto: this.form.nombreCompleto.trim().replace(/\s+/g, ' '),
      email: this.form.email.trim().toLowerCase(),
      numeroDocumento: this.esCampo(this.form.rol) ? this.form.numeroDocumento.trim().toUpperCase() : '',
      telefono: this.esCampo(this.form.rol) ? this.form.telefono.trim() : '',
      numLicencia: this.form.rol === 'CONDUCTOR' ? this.form.numLicencia.trim().toUpperCase() : '',
      catLicencia: this.form.rol === 'CONDUCTOR' ? this.form.catLicencia : '',
      vencLicencia: this.form.rol === 'CONDUCTOR' ? this.form.vencLicencia : ''
    };
    this.ocupado.set(true);
    this.api.crear(datos).subscribe({
      next: u => {
        this.ocupado.set(false);
        this.abierto.set(false);
        this.usuarios.set([...this.usuarios(), u]);
        if (this.esCampo(u.rol)) this.store.cargarPersonal();
        this.marcar(u.usuarioId);
        this.alerts.toast(`Usuario ${u.username} creado como ${etiqueta(u.rol)}`);
      },
      error: e => { this.ocupado.set(false); this.alerts.error(mensajeError(e)); }
    });
  }

  abrirRol(u: UsuarioSistema) {
    this.cambio = { rol: u.rol, numLicencia: '', catLicencia: '', vencLicencia: '' };
    this.vr.reiniciar();
    this.editando.set(u);
  }

  guardarRol() {
    const u = this.editando();
    if (!u || this.ocupado()) return;
    if (this.cambio.rol === u.rol) { this.editando.set(null); return; }
    if (!this.vr.valido()) { this.alerts.toast('Revisa los campos marcados en rojo', 'error'); return; }
    this.ocupado.set(true);
    this.api.cambiarRol(u.usuarioId, { ...this.cambio, numLicencia: this.cambio.numLicencia.trim().toUpperCase() }).subscribe({
      next: r => {
        this.ocupado.set(false);
        this.editando.set(null);
        this.reemplazar(r);
        this.alerts.toast(`${r.username} ahora es ${etiqueta(r.rol)}`);
      },
      error: e => { this.ocupado.set(false); this.alerts.error(mensajeError(e)); }
    });
  }

  async cambiarAcceso(u: UsuarioSistema) {
    const activar = u.estado !== 'ACTIVO';
    const ok = activar
      ? await this.alerts.confirm(u.estado === 'BLOQUEADO'
          ? `Se desbloqueará a ${u.username} y se reiniciarán sus intentos fallidos.`
          : `${u.username} podrá volver a iniciar sesión.`, u.estado === 'BLOQUEADO' ? 'Desbloquear usuario' : 'Reactivar usuario', 'Sí, activar')
      : await this.alerts.confirm(`${u.username} ya no podrá iniciar sesión. Sus registros se conservan.`, 'Desactivar usuario', 'Sí, desactivar');
    if (!ok) return;
    this.api.cambiarAcceso(u.usuarioId, activar).subscribe({
      next: r => { this.reemplazar(r); this.alerts.toast(activar ? 'Acceso restablecido' : 'Acceso revocado'); },
      error: e => this.alerts.error(mensajeError(e))
    });
  }

  abrirClave(u: UsuarioSistema) {
    this.clave = { password: '', confirmacion: '' };
    this.verClave.set(false);
    this.vc.reiniciar();
    this.claveDe.set(u);
  }

  guardarClave() {
    const u = this.claveDe();
    if (!u || this.ocupado()) return;
    if (!this.vc.valido()) { this.alerts.toast('Revisa los campos marcados en rojo', 'error'); return; }
    this.ocupado.set(true);
    this.api.cambiarClave(u.usuarioId, this.clave.password, this.clave.confirmacion).subscribe({
      next: r => {
        this.ocupado.set(false);
        this.claveDe.set(null);
        this.reemplazar(r);
        this.alerts.toast('Contraseña actualizada');
      },
      error: e => { this.ocupado.set(false); this.alerts.error(mensajeError(e)); }
    });
  }

  textoAcceso(estado: EstadoUsuario) {
    return estado === 'ACTIVO' ? 'Desactivar' : estado === 'BLOQUEADO' ? 'Desbloquear' : 'Reactivar';
  }

  private reemplazar(u: UsuarioSistema) {
    this.usuarios.set(this.usuarios().map(x => x.usuarioId === u.usuarioId ? u : x));
    if (this.esCampo(u.rol)) this.store.cargarPersonal();
    this.marcar(u.usuarioId);
  }

  private marcar(id: number) {
    this.resaltado.set(id);
    setTimeout(() => { if (this.resaltado() === id) this.resaltado.set(null); }, 2500);
  }
}
