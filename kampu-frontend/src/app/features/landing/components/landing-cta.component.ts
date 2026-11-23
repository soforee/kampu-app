import { Component, Input, inject } from '@angular/core';
import { RouterLink } from '@angular/router';
import { AuthService } from '../../../core/services/auth.service';
import { IconComponent } from '../../../shared/icon.component';
import { RevelarDirective } from '../../../shared/revelar.directive';

@Component({
  selector: 'app-landing-cta',
  standalone: true,
  imports: [RouterLink, IconComponent, RevelarDirective],
  templateUrl: './landing-cta.component.html'
})
export class LandingCtaComponent {
  @Input() whatsapp = '';
  auth = inject(AuthService);
}
