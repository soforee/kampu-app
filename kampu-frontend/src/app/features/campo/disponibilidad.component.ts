import { DatePipe } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Disponibilidad } from '../../core/models';
import { AlertService } from '../../core/services/alert.service';
import { CampoService } from '../../core/services/campo.service';
import { AuthService } from '../../core/services/auth.service';
import { mensajeError } from '../../core/utils/api';
import { addDays, hoy } from '../../core/utils/date.util';
import { IconComponent } from '../../shared/icon.component';
import { PageHeaderComponent } from '../../shared/page-header.component';

interface Dia { fecha: string; delMes: boolean; trabajo: string[]; bloqueado: boolean; }

@Component({
  selector: 'app-disponibilidad',
  standalone: true,
  imports: [DatePipe, FormsModule, IconComponent, PageHeaderComponent],
  template: `
  <app-page-header titulo="Disponibilidad y turnos" subtitulo="Tus turnos programados, tus días libres y los horarios en que no estás disponible." />

  @if (esGuia) {
    <section class="card mb-4 p-4">
      <div class="flex flex-wrap items-center justify-between gap-2">
        <h2 class="font-semibold text-zinc-900">Mis certificaciones</h2>
        @if (aviso(); as a) { <span class="rounded-full px-2.5 py-0.5 text-xs font-medium" [class]="a.clase">{{ a.texto }}</span> }
      </div>
      <div class="mt-3 grid gap-3 sm:grid-cols-4">
        <div><label class="label" for="c-carne">Carné DIRCETUR / MINCETUR</label><input id="c-carne" class="field uppercase" maxlength="30" [(ngModel)]="cert.carneGuia"></div>
        <div><label class="label" for="c-venc">Vence el</label><input id="c-venc" type="date" class="field" [(ngModel)]="cert.vencCarne"></div>
        <div><label class="label" for="c-idiomas">Idiomas acreditados</label><input id="c-idiomas" class="field" maxlength="200" [(ngModel)]="cert.idiomas" placeholder="Español, inglés, quechua"></div>
        <div class="flex items-end"><button type="button" class="btn-dark w-full" [disabled]="guardandoCert()" (click)="guardarCert()">{{ guardandoCert() ? 'Guardando…' : 'Guardar' }}</button></div>
      </div>
    </section>
  }

  <div class="grid gap-4 lg:grid-cols-3">
    <section class="card p-4 lg:col-span-2">
      <div class="mb-3 flex items-center justify-between">
        <button type="button" class="icon-btn" aria-label="Mes anterior" (click)="mover(-1)"><app-icon name="chevron-left" size="w-4 h-4" /></button>
        <h2 class="font-semibold capitalize text-zinc-900">{{ mes() + '-01' | date:'MMMM y' }}</h2>
        <button type="button" class="icon-btn" aria-label="Mes siguiente" (click)="mover(1)"><app-icon name="chevron-right" size="w-4 h-4" /></button>
      </div>
      <div class="grid grid-cols-7 gap-1 text-center text-xs font-medium text-zinc-500">
        @for (d of ['Lu', 'Ma', 'Mi', 'Ju', 'Vi', 'Sá', 'Do']; track d) { <div class="py-1">{{ d }}</div> }
      </div>
      <div class="grid grid-cols-7 gap-1">
        @for (d of dias(); track d.fecha) {
          <button type="button" class="min-h-[72px] rounded-lg border p-1.5 text-left text-xs transition"
                  [class]="(elegido() === d.fecha ? 'border-brand-600 ring-2 ring-brand-600/20 ' : 'border-zinc-100 ') + (!d.delMes ? 'opacity-40 ' : '') + (d.bloqueado ? 'bg-rose-50 ' : d.trabajo.length ? 'bg-brand-50 ' : 'bg-white ')"
                  (click)="elegido.set(d.fecha)" [attr.aria-label]="d.fecha">
            <span class="block font-semibold" [class.text-brand-700]="d.fecha === hoy">{{ +d.fecha.slice(8) }}</span>
            @for (t of d.trabajo.slice(0, 2); track $index) { <span class="block truncate text-brand-800">{{ t }}</span> }
            @if (d.trabajo.length > 2) { <span class="block text-zinc-500">+{{ d.trabajo.length - 2 }}</span> }
            @if (d.bloqueado) { <span class="block text-rose-700">No disponible</span> }
            @if (!d.trabajo.length && !d.bloqueado && d.delMes) { <span class="block text-zinc-400">Libre</span> }
          </button>
        }
      </div>
      <p class="mt-3 flex flex-wrap gap-4 text-xs text-zinc-500">
        <span><span class="mr-1 inline-block h-3 w-3 rounded bg-brand-50 ring-1 ring-brand-200"></span>Turno asignado</span>
        <span><span class="mr-1 inline-block h-3 w-3 rounded bg-rose-50 ring-1 ring-rose-200"></span>No disponible</span>
        <span><span class="mr-1 inline-block h-3 w-3 rounded bg-white ring-1 ring-zinc-200"></span>Libre</span>
      </p>
    </section>

    <section class="card p-4">
      <h2 class="font-semibold text-zinc-900">{{ elegido() | date:'EEEE d MMM' }}</h2>
      <ul class="mt-2 space-y-1.5 text-sm">
        @for (t of delDia().traslados; track t.operacionId) { <li><b>{{ t.horaSalida | date:'HH:mm' }}–{{ t.horaLlegada | date:'HH:mm' }}</b> {{ t.codigoOperacion }} · {{ t.origen }} → {{ t.destino }}</li> }
        @for (s of delDia().salidas; track s.salidaId) { <li><b>{{ s.horaInicio }}</b> {{ s.paqueteNombre }} (guía)</li> }
        @for (b of delDia().bloqueos; track b.bloqueoId) {
          <li class="flex items-start justify-between gap-2 rounded-lg bg-rose-50 px-2 py-1.5 text-rose-800">
            <span>No disponible {{ b.inicio | date:'dd/MM HH:mm' }} – {{ b.fin | date:'dd/MM HH:mm' }}@if (b.motivo) { · {{ b.motivo }} }</span>
            @if (b.fin > ahora) { <button type="button" class="icon-btn-danger" aria-label="Quitar bloqueo" (click)="quitar(b.bloqueoId)"><app-icon name="trash" size="w-4 h-4" /></button> }
          </li>
        }
        @if (!delDia().traslados.length && !delDia().salidas.length && !delDia().bloqueos.length) { <li class="text-zinc-500">Día libre.</li> }
      </ul>

      @if (elegido() >= hoy) {
        <h3 class="form-section-title mt-5">Marcar no disponible</h3>
        <div class="mt-2 space-y-3">
          <label class="inline-flex items-center gap-2 text-sm text-zinc-700"><input type="checkbox" [(ngModel)]="todoElDia"> Todo el día</label>
          @if (!todoElDia) {
            <div class="grid grid-cols-2 gap-3">
              <div><label class="label" for="b-ini">Desde</label><input id="b-ini" type="time" class="field" [(ngModel)]="horaInicio"></div>
              <div><label class="label" for="b-fin">Hasta</label><input id="b-fin" type="time" class="field" [(ngModel)]="horaFin"></div>
            </div>
          }
          <div><label class="label" for="b-mot">Motivo <span class="opt">Opcional</span></label><input id="b-mot" class="field" maxlength="200" [(ngModel)]="motivo" placeholder="Cita médica, descanso…"></div>
          <button type="button" class="btn-dark w-full" [disabled]="enviando()" (click)="bloquear()">{{ enviando() ? 'Guardando…' : 'Guardar bloqueo' }}</button>
          <p class="hint">La agencia no podrá asignarte trabajo en ese horario. Si ya tienes un turno, pídele que lo reasigne.</p>
        </div>
      }
    </section>
  </div>`
})
export class DisponibilidadComponent {
  private campo = inject(CampoService);
  private alerts = inject(AlertService);
  esGuia = inject(AuthService).rol() === 'GUIA';
  cert = { carneGuia: '', vencCarne: '', idiomas: '' };
  guardandoCert = signal(false);
  private vencGuardado = signal<string | null>(null);
  aviso = computed(() => {
    const v = this.vencGuardado();
    if (!v) return null;
    if (v < hoy()) return { texto: 'Carné vencido', clase: 'bg-rose-100 text-rose-700' };
    if (v <= addDays(hoy(), 30)) return { texto: 'Carné por vencer', clase: 'bg-amber-100 text-amber-800' };
    return { texto: 'Carné vigente', clase: 'bg-brand-50 text-brand-800' };
  });
  hoy = hoy();
  ahora = new Date().toISOString().slice(0, 19);
  mes = signal(hoy().slice(0, 7));
  elegido = signal(hoy());
  datos = signal<Disponibilidad>({ traslados: [], salidas: [], bloqueos: [] });
  enviando = signal(false);
  todoElDia = true;
  horaInicio = '08:00';
  horaFin = '13:00';
  motivo = '';

  private rango = computed(() => {
    const primero = this.mes() + '-01';
    const dow = (new Date(primero + 'T00:00:00').getDay() + 6) % 7;
    const desde = addDays(primero, -dow);
    const fin = new Date(+this.mes().slice(0, 4), +this.mes().slice(5, 7), 0).getDate();
    const ultimo = this.mes() + '-' + String(fin).padStart(2, '0');
    const dowFin = (new Date(ultimo + 'T00:00:00').getDay() + 6) % 7;
    return { desde, hasta: addDays(ultimo, 6 - dowFin) };
  });

  dias = computed<Dia[]>(() => {
    const { desde, hasta } = this.rango();
    const d = this.datos();
    const r: Dia[] = [];
    for (let f = desde; f <= hasta; f = addDays(f, 1)) {
      const trabajo = [
        ...d.traslados.filter(t => t.horaSalida.slice(0, 10) === f).map(t => t.horaSalida.slice(11, 16) + ' ' + t.codigoOperacion),
        ...d.salidas.filter(s => s.fechaInicio <= f && s.fechaFin >= f).map(s => s.paqueteNombre)
      ];
      const bloqueado = d.bloqueos.some(b => this.cubre(b, f));
      r.push({ fecha: f, delMes: f.slice(0, 7) === this.mes(), trabajo, bloqueado });
    }
    return r;
  });

  delDia = computed(() => {
    const f = this.elegido();
    const d = this.datos();
    return {
      traslados: d.traslados.filter(t => t.horaSalida.slice(0, 10) === f),
      salidas: d.salidas.filter(s => s.fechaInicio <= f && s.fechaFin >= f),
      bloqueos: d.bloqueos.filter(b => this.cubre(b, f))
    };
  });

  private cubre(b: { inicio: string; fin: string }, f: string) {
    return b.inicio < addDays(f, 1) + 'T00:00' && b.fin > f + 'T00:00';
  }

  constructor() {
    this.cargar();
    if (this.esGuia) this.campo.certificaciones().subscribe({ next: c => this.mostrarCert(c), error: () => undefined });
  }

  private mostrarCert(c: { carneGuia: string | null; vencCarne: string | null; idiomas: string | null }) {
    this.cert = { carneGuia: c.carneGuia ?? '', vencCarne: c.vencCarne ?? '', idiomas: c.idiomas ?? '' };
    this.vencGuardado.set(c.vencCarne);
  }

  guardarCert() {
    const carne = this.cert.carneGuia.trim();
    if (!!carne !== !!this.cert.vencCarne) { this.alerts.toast('Indica el carné y su vencimiento juntos', 'error'); return; }
    this.guardandoCert.set(true);
    this.campo.guardarCertificaciones({ carneGuia: carne, vencCarne: this.cert.vencCarne || null, idiomas: this.cert.idiomas.trim() }).subscribe({
      next: c => { this.guardandoCert.set(false); this.mostrarCert(c); this.alerts.toast('Certificaciones guardadas'); },
      error: e => { this.guardandoCert.set(false); this.alerts.error(mensajeError(e)); }
    });
  }

  private cargar() {
    const { desde, hasta } = this.rango();
    this.campo.disponibilidad(desde, hasta).subscribe({ next: d => this.datos.set(d), error: e => this.alerts.error(mensajeError(e)) });
  }

  mover(n: number) {
    const [a, m] = this.mes().split('-').map(Number);
    const d = new Date(a, m - 1 + n, 1);
    this.mes.set(`${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`);
    this.elegido.set(this.mes() + '-01');
    this.cargar();
  }

  bloquear() {
    const f = this.elegido();
    const inicio = this.todoElDia ? `${f}T00:00:00` : `${f}T${this.horaInicio}:00`;
    const fin = this.todoElDia ? `${addDays(f, 1)}T00:00:00` : `${f}T${this.horaFin}:00`;
    if (fin <= inicio) { this.alerts.toast('La hora final debe ser posterior a la inicial', 'error'); return; }
    this.enviando.set(true);
    this.campo.bloquear({ inicio, fin, motivo: this.motivo.trim() }).subscribe({
      next: () => { this.enviando.set(false); this.motivo = ''; this.alerts.toast('Bloqueo guardado'); this.cargar(); },
      error: e => { this.enviando.set(false); this.alerts.error(mensajeError(e)); }
    });
  }

  async quitar(id: number) {
    if (!(await this.alerts.confirm('Volverás a estar disponible en ese horario.', 'Quitar bloqueo', 'Quitar'))) return;
    this.campo.desbloquear(id).subscribe({ next: () => { this.alerts.toast('Bloqueo quitado'); this.cargar(); }, error: e => this.alerts.error(mensajeError(e)) });
  }
}
