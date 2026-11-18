import { HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { AuthService } from './auth.service';

// Después del login, cada petición a la API lleva quién la hace (usuario, rol y su id).
// El backend lo usa para la bitácora, para el portal del cliente y para la sesión de Oracle.
export const usuarioInterceptor: HttpInterceptorFn = (req, next) => {
  const sesion = inject(AuthService).usuario();
  if (!sesion || !req.url.startsWith('/api/')) return next(req);
  const cabeceras: Record<string, string> = { 'X-Usuario': sesion.username, 'X-Rol': sesion.rol };
  if (sesion.usuarioId) cabeceras['X-Usuario-Id'] = String(sesion.usuarioId);
  if (sesion.clienteId) cabeceras['X-Cliente-Id'] = String(sesion.clienteId);
  return next(req.clone({ setHeaders: cabeceras }));
};
