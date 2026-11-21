import { HttpErrorResponse, HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { catchError, throwError } from 'rxjs';
import { AuthService } from './auth.service';

// (v11) Cada petición a la API lleva la sesión firmada por el backend ("Authorization: Bearer ...").
// Ya no se envían X-Usuario / X-Rol: el backend no confía en datos que el navegador pueda inventar.
// Si el backend responde 401 con una sesión guardada (venció o la cuenta se desactivó), se cierra la sesión.
export const usuarioInterceptor: HttpInterceptorFn = (req, next) => {
  const auth = inject(AuthService);
  const router = inject(Router);
  const sesion = auth.usuario();
  if (!req.url.startsWith('/api/')) return next(req);
  const peticion = sesion?.token ? req.clone({ setHeaders: { Authorization: 'Bearer ' + sesion.token } }) : req;
  return next(peticion).pipe(catchError((e: unknown) => {
    if (e instanceof HttpErrorResponse && e.status === 401 && sesion && !req.url.includes('/auth/')) {
      auth.olvidar();
      router.navigate(['/login'], { queryParams: { vencida: 1 } });
    }
    return throwError(() => e);
  }));
};
