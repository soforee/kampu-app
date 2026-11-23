import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { Permiso } from '../models';
import { AuthService } from './auth.service';

export const personalGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);
  if (!auth.autenticado()) return router.parseUrl('/login');
  return auth.esCliente() ? router.parseUrl('/mi-cuenta') : true;
};

export const panelGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  return auth.esCampo() ? inject(Router).parseUrl('/mis-asignaciones') : true;
};

export const clienteGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);
  if (!auth.autenticado()) return router.parseUrl('/login');
  return auth.esCliente() ? true : router.parseUrl(auth.inicio());
};

export const permisoGuard: CanActivateFn = (ruta) => {
  const auth = inject(AuthService);
  const permiso = ruta.data?.['permiso'] as Permiso | undefined;
  return !permiso || auth.puede(permiso) ? true : inject(Router).parseUrl(auth.inicio());
};
