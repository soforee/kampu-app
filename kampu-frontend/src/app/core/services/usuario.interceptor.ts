import { HttpErrorResponse, HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { catchError, throwError } from 'rxjs';
import { AuthService } from './auth.service';

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
