import { Component } from '@angular/core';
import { RouterLink } from '@angular/router';
import { IconComponent } from '../../../shared/icon.component';
import { RevelarDirective } from '../../../shared/revelar.directive';

// "Cómo funciona": el recorrido real de un cliente en el sistema
@Component({
  selector: 'app-landing-pasos',
  standalone: true,
  imports: [IconComponent, RevelarDirective, RouterLink],
  templateUrl: './landing-pasos.component.html'
})
export class LandingPasosComponent {
  pasos = [
    { icono: 'compass', titulo: 'Elige tu tour', texto: 'Revisa los destinos, la duración y la próxima salida de cada paquete.' },
    { icono: 'ticket', titulo: 'Reserva tu cupo', texto: 'Cotiza con la agencia; registramos tu reserva y a cada pasajero.' },
    { icono: 'card', titulo: 'Paga a tu ritmo', texto: 'Adelanto y saldo en soles, dólares o euros, con cada pago registrado.' },
    { icono: 'check-circle', titulo: 'Sigue tu viaje', texto: 'Con tu cuenta ves el estado de tu paquete y tus pagos.' }
  ];
}
