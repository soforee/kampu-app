import { Component, Input } from '@angular/core';
import { etiqueta } from '../core/utils/etiquetas';

@Component({
  selector: 'app-badge',
  standalone: true,
  templateUrl: './badge.component.html'
})
export class BadgeComponent {
  @Input({ required: true }) estado = '';

  // Tono del punto de color según el estado; el resto (completado, inactivo, sesiones...) queda en gris
  private tonos: { [estado: string]: string } = {
    CONFIRMADA: 'verde', APROBADO: 'verde', PAGADO: 'verde', ACTIVO: 'verde', DISPONIBLE: 'verde', OPERATIVO: 'verde', FINALIZADO: 'verde', PAGADO_COMPLETO: 'verde', CREAR: 'verde',
    PENDIENTE: 'ambar', OCUPADO: 'ambar', MANTENIMIENTO: 'ambar', FALTA_PAGAR: 'ambar', LOGIN_FALLIDO: 'ambar',
    ANULADA: 'rojo', CANCELADA: 'rojo', RECHAZADO: 'rojo', SUSPENDIDO: 'rojo', CANCELADO: 'rojo', PENDIENTE_PAGO: 'rojo', ELIMINAR: 'rojo',
    PARCIAL: 'azul', PROGRAMADA: 'azul', ASIGNADO: 'azul', POR_EMPEZAR: 'azul', ACTUALIZAR: 'azul', EMBARQUE: 'azul',
    EN_RUTA: 'marca', EN_CURSO: 'marca', REGISTRO: 'marca', REEMBOLSADO: 'marca'
  };
  private puntos: { [tono: string]: string } = {
    verde: 'bg-emerald-500', ambar: 'bg-amber-400', rojo: 'bg-rose-500', azul: 'bg-sky-500', marca: 'bg-brand-500'
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
