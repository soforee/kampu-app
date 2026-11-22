import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { Permiso } from '../models';
import { AuthService } from './auth.service';

// Panel interno: solo personal (ADMIN / VENTAS). El cliente va a su portal.
export const personalGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);
  if (!auth.autenticado()) return router.parseUrl('/login');
  return auth.esCliente() ? router.parseUrl('/mi-cuenta') : true;
};

// (v11) El panel general no es para guías ni conductores: van a sus asignaciones
export const panelGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  return auth.esCampo() ? inject(Router).parseUrl('/mis-asignaciones') : true;
};

// Portal del cliente: solo rol CLIENTE
export const clienteGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);
  if (!auth.autenticado()) return router.parseUrl('/login');
  return auth.esCliente() ? true : router.parseUrl(auth.inicio());
};

// Pantalla que exige un permiso (data.permiso). Mismo permiso que pide el backend
// (SeguridadInterceptor -> PKG_SEGURIDAD_ROLES.puede), así no se muestra nada que daría 403.
export const permisoGuard: CanActivateFn = (ruta) => {
  const auth = inject(AuthService);
  const permiso = ruta.data?.['permiso'] as Permiso | undefined;
  return !permiso || auth.puede(permiso) ? true : inject(Router).parseUrl(auth.inicio());
};
