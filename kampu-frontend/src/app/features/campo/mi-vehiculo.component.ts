import { DatePipe, DecimalPipe } from '@angular/common';
import { Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Combustible, MiVehiculo } from '../../core/models';
import { AlertService } from '../../core/services/alert.service';
import { CampoService } from '../../core/services/campo.service';
import { mensajeError } from '../../core/utils/api';
import { addDays, hoy } from '../../core/utils/date.util';
import { etiqueta } from '../../core/utils/etiquetas';
import { BadgeComponent } from '../../shared/badge.component';
import { IconComponent } from '../../shared/icon.component';
import { PageHeaderComponent } from '../../shared/page-header.component';

@Component({
  selector: 'app-mi-vehiculo',
  standalone: true,
  imports: [DatePipe, DecimalPipe, FormsModule, BadgeComponent, IconComponent, PageHeaderComponent],
  template: `
  <app-page-header titulo="Mi vehículo" subtitulo="La unidad que conduces hoy, sus documentos y el registro de kilometraje y combustible." />

  @if (error()) { <div class="card p-6 text-sm text-rose-700">{{ error() }}</div> }
  @else if (!datos()) { <div class="card h-40 animate-pulse bg-zinc-100"></div> }
  @else { @if (datos()!.vehiculo; as v) {
    <div class="grid gap-4 lg:grid-cols-3">
      <section class="card p-5 lg:col-span-1">
        <div class="flex items-start justify-between gap-3">
          <div><p class="font-mono text-2xl font-semibold text-zinc-900">{{ v.placa }}</p>
            <p class="text-sm text-zinc-600">{{ v.marcaModelo || etiqueta(v.tipoVehiculo) }} · {{ etiqueta(v.tipoVehiculo) }} · {{ v.capacidadPax }} asientos</p>
            @if (v.proveedor) { <p class="text-xs text-zinc-500">{{ v.proveedor }}</p> }</div>
          <app-badge [estado]="v.estado" />
        </div>
        <dl class="mt-4 space-y-3 text-sm">
          @for (d of documentos(v); track d.texto) {
            <div class="flex items-center justify-between gap-3 rounded-lg border px-3 py-2" [class]="d.clase">
              <dt>{{ d.texto }}</dt><dd class="font-medium">{{ d.fecha ? (d.fecha | date:'dd/MM/yyyy') : 'Sin registrar' }}@if (d.aviso) { · {{ d.aviso }} }</dd>
            </div>
          }
        </dl>
        @if (!datos()!.hoy) { <p class="mt-3 text-xs text-zinc-500">Es el vehículo de tu próximo traslado. La jornada se registra el día que lo conduces.</p> }
      </section>

      <section class="card p-5 lg:col-span-2">
        <h2 class="font-semibold text-zinc-900">Jornada de hoy</h2>
        <p class="text-sm text-zinc-500">Registra el kilometraje y el combustible al empezar; al terminar el día completa el final.</p>
        <div class="mt-4 grid gap-4 sm:grid-cols-2">
          <div><label class="label req" for="j-kmi">Km al empezar</label><input id="j-kmi" type="number" min="0" class="field tabular-nums" [(ngModel)]="j.kmInicial" [disabled]="!datos()!.hoy" inputmode="numeric"></div>
          <div><label class="label req" for="j-ci">Combustible al empezar</label>
            <select id="j-ci" class="field" [(ngModel)]="j.combustibleInicial" [disabled]="!datos()!.hoy">@for (c of niveles; track c) { <option [value]="c">{{ c === 'RESERVA' ? 'Reserva' : c === 'LLENO' ? 'Lleno' : c }}</option> }</select></div>
          <div><label class="label" for="j-kmf">Km al terminar</label><input id="j-kmf" type="number" min="0" class="field tabular-nums" [(ngModel)]="j.kmFinal" [disabled]="!datos()!.hoy" inputmode="numeric"></div>
          <div><label class="label" for="j-cf">Combustible al terminar</label>
            <select id="j-cf" class="field" [(ngModel)]="j.combustibleFinal" [disabled]="!datos()!.hoy"><option value="">—</option>@for (c of niveles; track c) { <option [value]="c">{{ c === 'RESERVA' ? 'Reserva' : c === 'LLENO' ? 'Lleno' : c }}</option> }</select></div>
          <div class="sm:col-span-2"><label class="label" for="j-obs">Observaciones <span class="opt">Opcional</span></label><input id="j-obs" class="field" maxlength="300" [(ngModel)]="j.observaciones" [disabled]="!datos()!.hoy" placeholder="Llanta baja, ruido en frenos…"></div>
        </div>
        @if (j.kmFinal !== null && j.kmInicial !== null && j.kmFinal >= j.kmInicial) { <p class="mt-2 text-sm text-zinc-600">Recorrido del día: <b>{{ j.kmFinal - j.kmInicial | number }} km</b></p> }
        <button type="button" class="btn-brand mt-4" [disabled]="!datos()!.hoy || guardando()" (click)="guardar(v.vehiculoId)"><app-icon name="check" size="w-4 h-4" /> {{ guardando() ? 'Guardando…' : 'Guardar jornada' }}</button>

        @if (datos()!.jornadas?.length) {
          <h3 class="form-section-title mt-6">Últimas jornadas</h3>
          <table class="tbl mt-2"><thead><tr><th class="th">Fecha</th><th class="th text-right">Km inicio</th><th class="th text-right">Km fin</th><th class="th">Combustible</th></tr></thead>
            <tbody>@for (x of datos()!.jornadas!; track x.fecha) {
              <tr><td class="td">{{ x.fecha | date:'dd/MM/yyyy' }}</td><td class="td text-right tabular-nums">{{ x.kmInicial | number }}</td>
                <td class="td text-right tabular-nums">{{ x.kmFinal !== null ? (x.kmFinal | number) : '—' }}</td><td class="td">{{ x.combustibleInicial }} → {{ x.combustibleFinal ?? '—' }}</td></tr>
            }</tbody></table>
        }
      </section>
    </div>
  } @else {
    <div class="card p-6 text-sm text-zinc-500">No tienes traslados con vehículo asignado desde hoy. Cuando la agencia te asigne uno, aparecerá aquí.</div>
  } }`
})
export class MiVehiculoComponent {
  private campo = inject(CampoService);
  private alerts = inject(AlertService);
  etiqueta = etiqueta;
  niveles: Combustible[] = ['LLENO', '3/4', '1/2', '1/4', 'RESERVA'];
  datos = signal<MiVehiculo | null>(null);
  error = signal('');
  guardando = signal(false);
  j = { kmInicial: null as number | null, combustibleInicial: 'LLENO', kmFinal: null as number | null, combustibleFinal: '', observaciones: '' };

  constructor() {
    this.campo.vehiculo().subscribe({ next: d => this.mostrar(d), error: e => this.error.set(mensajeError(e)) });
  }

  private mostrar(d: MiVehiculo) {
    this.datos.set(d);
    const hoyJ = d.jornadas?.find(x => x.fecha === hoy());
    if (hoyJ) {
      this.j = { kmInicial: hoyJ.kmInicial, combustibleInicial: hoyJ.combustibleInicial, kmFinal: hoyJ.kmFinal,
        combustibleFinal: hoyJ.combustibleFinal ?? '', observaciones: hoyJ.observaciones ?? '' };
    } else {
      const ult = d.jornadas?.[0];
      this.j.kmInicial = ult ? (ult.kmFinal ?? ult.kmInicial) : null;
    }
  }

  documentos(v: NonNullable<MiVehiculo['vehiculo']>) {
    const pronto = addDays(hoy(), 30);
    return [
      { texto: 'Próximo mantenimiento', fecha: v.proxMantenimiento },
      { texto: 'SOAT', fecha: v.vencSoat },
      { texto: 'Revisión técnica', fecha: v.vencRevision }
    ].map(d => ({
      ...d,
      aviso: !d.fecha ? '' : d.fecha < hoy() ? 'vencido' : d.fecha <= pronto ? 'por vencer' : '',
      clase: !d.fecha ? 'border-zinc-200 text-zinc-500' : d.fecha < hoy() ? 'border-rose-200 bg-rose-50 text-rose-700'
        : d.fecha <= pronto ? 'border-amber-200 bg-amber-50 text-amber-800' : 'border-zinc-200 text-zinc-800'
    }));
  }

  guardar(vehiculoId: number) {
    const num = (x: number | null) => x === null || (x as unknown) === '' ? null : Number(x);
    if (num(this.j.kmInicial) === null) { this.alerts.toast('Indica el kilometraje al empezar', 'error'); return; }
    this.guardando.set(true);
    this.campo.jornada(vehiculoId, { ...this.j, kmInicial: num(this.j.kmInicial), kmFinal: num(this.j.kmFinal) }).subscribe({
      next: d => { this.guardando.set(false); this.mostrar(d); this.alerts.toast('Jornada guardada'); },
      error: e => { this.guardando.set(false); this.alerts.error(mensajeError(e)); }
    });
  }
}
