import { Component, Input } from '@angular/core';
import { etiqueta } from '../core/utils/etiquetas';

@Component({
  selector: 'app-badge',
  standalone: true,
  templateUrl: './badge.component.html'
})
export class BadgeComponent {
  @Input({ required: true }) estado = '';

  // Punto de color según el estado, con la paleta del logotipo:
  //   correcto -> oliva del logo (#4B5B1D) · en curso -> oliva medio · intermedio -> oliva claro
  //   aviso -> lima de la hoja (#C4BD45) · error -> terracota · el resto (completado, inactivo...) -> neutro
  private tonos: { [estado: string]: string } = {
    CONFIRMADA: 'correcto', APROBADO: 'correcto', PAGADO: 'correcto', ACTIVO: 'correcto', DISPONIBLE: 'correcto', OPERATIVO: 'correcto',
    FINALIZADO: 'correcto', PAGADO_COMPLETO: 'correcto', CREAR: 'correcto',
    EN_RUTA: 'curso', EN_CURSO: 'curso', EMBARQUE: 'curso', REGISTRO: 'curso',
    PARCIAL: 'intermedio', PROGRAMADA: 'intermedio', ASIGNADO: 'intermedio', POR_EMPEZAR: 'intermedio', ACTUALIZAR: 'intermedio',
    PENDIENTE: 'aviso', OCUPADO: 'aviso', MANTENIMIENTO: 'aviso', FALTA_PAGAR: 'aviso', LOGIN_FALLIDO: 'aviso',
    ANULADA: 'error', CANCELADA: 'error', RECHAZADO: 'error', SUSPENDIDO: 'error', CANCELADO: 'error', PENDIENTE_PAGO: 'error', ELIMINAR: 'error'
  };
  private puntos: { [tono: string]: string } = {
    correcto: 'bg-brand-600', curso: 'bg-brand-400', intermedio: 'bg-brand-200 ring-1 ring-brand-400',
    aviso: 'bg-leaf-400', error: 'bg-rose-500'
  };

  // Textos legibles de los estados del portal
  private textos: { [estado: string]: string } = {
    POR_EMPEZAR: 'Por empezar', EN_CURSO: 'En curso', TERMINADO: 'Terminado',
    PAGADO_COMPLETO: 'Pagado completo', FALTA_PAGAR: 'Falta pagar', PENDIENTE_PAGO: 'Pendiente de pago',
    CREAR: 'Alta', ACTUALIZAR: 'Modificación', ELIMINAR: 'Baja', REGISTRO: 'Registro web',
    LOGIN: 'Inicio de sesión', LOGOUT: 'Cierre de sesión', LOGIN_FALLIDO: 'Ingreso fallido'
  };

  get punto() { return this.puntos[this.tonos[this.estado]] ?? 'bg-zinc-400'; }
  get texto() { return this.textos[this.estado] ?? etiqueta(this.estado); }
}
