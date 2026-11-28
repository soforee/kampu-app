import { Routes } from '@angular/router';
import { LandingComponent } from './features/landing/landing.component';
import { LoginComponent } from './features/login/login.component';
import { ShellComponent } from './layout/shell.component';
import { clienteGuard, panelGuard, permisoGuard, personalGuard } from './core/services/guards';

const permiso = (p: string) => ({ permiso: p });

export const routes: Routes = [
  { path: '', component: LandingComponent, pathMatch: 'full' },
  { path: 'login', component: LoginComponent },
  { path: 'cotizar/:paqueteId', loadComponent: () => import('./features/cotizar/cotizador.component').then(m => m.CotizadorComponent) },
  { path: 'cotizacion/:codigo', loadComponent: () => import('./features/cotizar/cotizacion-detalle.component').then(m => m.CotizacionDetalleComponent) },
  { path: 'cotizacion/:codigo/reserva', loadComponent: () => import('./features/portal/paquete-cliente.component').then(m => m.PaqueteClienteComponent) },
  { path: 'seguimiento', loadComponent: () => import('./features/cotizar/seguimiento.component').then(m => m.SeguimientoComponent) },
  { path: 'registro', loadComponent: () => import('./features/portal/registro.component').then(m => m.RegistroComponent) },
  { path: 'confirmar-correo', loadComponent: () => import('./features/portal/confirmar-correo.component').then(m => m.ConfirmarCorreoComponent) },
  { path: 'mi-cuenta', loadComponent: () => import('./features/portal/mis-paquetes.component').then(m => m.MisPaquetesComponent), canActivate: [clienteGuard] },
  { path: 'mi-cuenta/paquetes/:id', loadComponent: () => import('./features/portal/paquete-cliente.component').then(m => m.PaqueteClienteComponent), canActivate: [clienteGuard] },
  {
    path: '',
    component: ShellComponent,
    canActivate: [personalGuard],
    canActivateChild: [permisoGuard],
    children: [
      { path: 'dashboard', loadComponent: () => import('./features/dashboard/dashboard.component').then(m => m.DashboardComponent), canActivate: [panelGuard] },
      { path: 'cotizaciones', loadComponent: () => import('./features/cotizaciones/cotizaciones.component').then(m => m.CotizacionesComponent), data: permiso('VER_COTIZACIONES') },
      { path: 'servicios-adicionales', loadComponent: () => import('./features/servicios/servicios.component').then(m => m.ServiciosComponent), data: permiso('GESTIONAR_CATALOGO') },
      { path: 'mis-asignaciones', loadComponent: () => import('./features/asignaciones/mis-asignaciones.component').then(m => m.MisAsignacionesComponent), data: permiso('VER_ASIGNACIONES_PROPIAS') },
      { path: 'historial-viajes', loadComponent: () => import('./features/campo/historial.component').then(m => m.HistorialViajesComponent), data: permiso('VER_ASIGNACIONES_PROPIAS') },
      { path: 'historial-tours', loadComponent: () => import('./features/campo/historial-tours.component').then(m => m.HistorialToursComponent), data: permiso('VER_ASIGNACIONES_PROPIAS') },
      { path: 'mi-vehiculo', loadComponent: () => import('./features/campo/mi-vehiculo.component').then(m => m.MiVehiculoComponent), data: permiso('VER_ASIGNACIONES_PROPIAS') },
      { path: 'mis-novedades', loadComponent: () => import('./features/campo/novedades.component').then(m => m.MisNovedadesComponent), data: permiso('VER_ASIGNACIONES_PROPIAS') },
      { path: 'disponibilidad', loadComponent: () => import('./features/campo/disponibilidad.component').then(m => m.DisponibilidadComponent), data: permiso('VER_ASIGNACIONES_PROPIAS') },
      { path: 'novedades', loadComponent: () => import('./features/incidencias/incidencias.component').then(m => m.IncidenciasComponent), data: permiso('VER_OPERACIONES') },
      { path: 'reservas', loadComponent: () => import('./features/reservas/reservas.component').then(m => m.ReservasComponent), data: permiso('VER_RESERVAS') },
      { path: 'reservas/nueva', loadComponent: () => import('./features/reservas/reserva-nueva.component').then(m => m.ReservaNuevaComponent), data: permiso('GESTIONAR_RESERVAS') },
      { path: 'reservas/:id', loadComponent: () => import('./features/reservas/reserva-detalle.component').then(m => m.ReservaDetalleComponent), data: permiso('VER_RESERVAS') },
      { path: 'salidas', loadComponent: () => import('./features/salidas/salidas.component').then(m => m.SalidasComponent), data: permiso('VER_RESUMEN') },
      { path: 'salidas/:id', loadComponent: () => import('./features/salidas/salida-detalle.component').then(m => m.SalidaDetalleComponent), data: permiso('VER_RESUMEN') },
      { path: 'paquetes', loadComponent: () => import('./features/paquetes/paquetes.component').then(m => m.PaquetesComponent), data: permiso('GESTIONAR_CATALOGO') },
      { path: 'pagos', loadComponent: () => import('./features/pagos/pagos.component').then(m => m.PagosComponent), data: permiso('VER_MONTOS') },
      { path: 'clientes', loadComponent: () => import('./features/clientes/clientes.component').then(m => m.ClientesComponent), data: permiso('VER_CLIENTES') },
      { path: 'operaciones', loadComponent: () => import('./features/operaciones/operaciones.component').then(m => m.OperacionesComponent), data: permiso('VER_OPERACIONES') },
      { path: 'personal', loadComponent: () => import('./features/recursos/recursos.component').then(m => m.RecursosComponent), data: { ...permiso('VER_LOGISTICA'), seccion: 'personal' } },
      { path: 'vehiculos', loadComponent: () => import('./features/recursos/recursos.component').then(m => m.RecursosComponent), data: { ...permiso('VER_LOGISTICA'), seccion: 'vehiculos' } },
      { path: 'proveedores', loadComponent: () => import('./features/recursos/recursos.component').then(m => m.RecursosComponent), data: { ...permiso('VER_LOGISTICA'), seccion: 'proveedores' } },
      { path: 'usuarios', loadComponent: () => import('./features/usuarios/usuarios.component').then(m => m.UsuariosComponent), data: permiso('GESTIONAR_USUARIOS') },
      { path: 'auditoria', loadComponent: () => import('./features/auditoria/auditoria.component').then(m => m.AuditoriaComponent), data: permiso('VER_AUDITORIA') }
    ]
  },
  { path: '**', redirectTo: '' }
];
