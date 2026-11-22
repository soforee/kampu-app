import { DatePipe } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { EstadoUsuario, PersonalSinCuenta, RolInterno, UsuarioForm, UsuarioSistema } from '../../core/models';
import { AlertService } from '../../core/services/alert.service';
import { AuthService } from '../../core/services/auth.service';
import { UsuarioService } from '../../core/services/usuario.service';
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

/**
 * Usuarios del sistema (solo ADMIN, permiso GESTIONAR_USUARIOS).
 * El administrador crea las cuentas del personal y elige su rol; también cambia el rol,
 * revoca o restablece el acceso (desbloquea) y asigna una contraseña nueva.
 * Las cuentas de clientes no se crean aquí: el cliente se registra en el portal.
 */
@Component({
  selector: 'app-usuarios',
  standalone: true,
  imports: [FormsModule, DatePipe, PageHeaderComponent, BuscadorComponent, PaginacionComponent, IconComponent, ModalComponent, BadgeComponent],
  templateUrl: './usuarios.component.html'
})
export class UsuariosComponent {
  private api = inject(UsuarioService);
  private alerts = inject(AlertService);
  auth = inject(AuthService);

  min = PASSWORD_MIN;
  etiqueta = etiqueta;

  // Roles que el administrador puede asignar (chk_usu_rol) y qué puede hacer cada uno (PKG_SEGURIDAD_ROLES.puede)
  roles: { valor: RolInterno; texto: string; icono: string; detalle: string }[] = [
    { valor: 'ADMIN', texto: 'Administrador', icono: 'lock', detalle: 'Acceso completo: usuarios, auditoría, ventas, catálogo, logística y operaciones.' },
    { valor: 'VENTAS', texto: 'Ventas', icono: 'ticket', detalle: 'Clientes, reservas, pagos, cotizaciones y catálogo de paquetes. Sin usuarios ni gestión de flota.' },
    // (v11) Personal de campo: la cuenta es opcional y va ligada a su ficha de personal
    { valor: 'GUIA', texto: 'Guía', icono: 'flag', detalle: 'Solo sus salidas: itinerario, manifiesto y recojos. Sin montos ni clientes.' },
    { valor: 'CONDUCTOR', texto: 'Conductor', icono: 'map-pin', detalle: 'Solo sus traslados: vehículo, ruta y recojos. Sin montos ni clientes.' }
  ];
  esCampo = (rol: RolInterno) => rol === 'GUIA' || rol === 'CONDUCTOR';
  // Guías y conductores (por la función de su cargo) que aún no tienen cuenta
  personal = signal<PersonalSinCuenta[]>([]);
  personalPara = (rol: RolInterno) => this.personal().filter(p => p.rol === rol);

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

  // ---------- Nuevo usuario ----------
  abierto = signal(false);
  verClave = signal(false);
  form: UsuarioForm = this.vacio();
  v = new FormValidacion(() => ({
    nombre: V.nombrePersona(this.form.nombreCompleto),
    personal: this.esCampo(this.form.rol) && !this.form.personalId ? 'Elige la persona del personal que usará la cuenta.' : null,
    username: this.errorUsername(),
    email: this.form.email.trim() ? V.email(this.form.email) ?? this.emailRepetido() : 'El correo es obligatorio.',
    password: this.errorClave(this.form.password),
    confirmacion: !this.form.confirmacion ? 'Repite la contraseña.'
      : this.form.confirmacion !== this.form.password ? 'Las contraseñas no coinciden.' : null
  }));

  // ---------- Cambiar rol ----------
  editando = signal<UsuarioSistema | null>(null);
  nuevoRol: RolInterno = 'VENTAS';
  nuevoPersonal: number | null = null;

  // ---------- Contraseña nueva ----------
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
    return { username: '', nombreCompleto: '', email: '', rol: 'VENTAS', personalId: null, password: '', confirmacion: '' };
  }

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

  // Indicador orientativo de fortaleza (0 a 4)
  fuerza(p: string): number {
    let n = 0;
    if (p.length >= PASSWORD_MIN) n++;
    if (/[A-Z]/.test(p) && /[a-z]/.test(p)) n++;
    if (/\d/.test(p)) n++;
    if (/[^A-Za-z0-9]/.test(p) || p.length >= 12) n++;
    return n;
  }

  // Sugerencia de usuario a partir del nombre: "María Quispe" -> "mquispe"
  sugerirUsuario() {
    if (this.form.username.trim()) return;
    const partes = this.form.nombreCompleto.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()
      .replace(/[^a-z ]/g, '').trim().split(/\s+/).filter(Boolean);
    if (partes.length >= 2) this.form.username = (partes[0][0] + partes[1]).slice(0, 50);
  }

  private cargarPersonal() {
    this.api.personalSinCuenta().subscribe({ next: l => this.personal.set(l), error: () => this.personal.set([]) });
  }

  // Al elegir a la persona se completa su nombre (el usuario se sugiere a partir de él)
  elegirPersona(id: number | null) {
    this.form.personalId = id;
    const p = this.personal().find(x => x.personalId === id);
    if (p) { this.form.nombreCompleto = p.nombreCompleto; this.form.username = ''; this.sugerirUsuario(); }
    this.v.tocar('personal');
  }

  elegirRol(rol: RolInterno) {
    this.form.rol = rol;
    if (!this.esCampo(rol)) this.form.personalId = null;
    else if (this.form.personalId && !this.personalPara(rol).some(p => p.personalId === this.form.personalId)) this.form.personalId = null;
  }

  nuevo() {
    this.cargarPersonal();
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
      personalId: this.esCampo(this.form.rol) ? this.form.personalId : null
    };
    this.ocupado.set(true);
    this.api.crear(datos).subscribe({
      next: u => {
        this.ocupado.set(false);
        this.abierto.set(false);
        this.usuarios.set([...this.usuarios(), u]);
        this.marcar(u.usuarioId);
        this.alerts.toast(`Usuario ${u.username} creado como ${etiqueta(u.rol)}`);
      },
      error: e => { this.ocupado.set(false); this.alerts.error(mensajeError(e)); }
    });
  }

  abrirRol(u: UsuarioSistema) {
    this.cargarPersonal();
    this.nuevoRol = u.rol;
    this.nuevoPersonal = u.personalId;
    this.editando.set(u);
  }

  guardarRol() {
    const u = this.editando();
    if (!u || this.ocupado()) return;
    const campo = this.esCampo(this.nuevoRol);
    if (this.nuevoRol === u.rol && (!campo || this.nuevoPersonal === u.personalId)) { this.editando.set(null); return; }
    if (campo && !this.nuevoPersonal) { this.alerts.toast('Elige la persona del personal', 'error'); return; }
    this.ocupado.set(true);
    this.api.cambiarRol(u.usuarioId, this.nuevoRol, campo ? this.nuevoPersonal : null).subscribe({
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
    this.marcar(u.usuarioId);
  }

  private marcar(id: number) {
    this.resaltado.set(id);
    setTimeout(() => { if (this.resaltado() === id) this.resaltado.set(null); }, 2500);
  }
}
