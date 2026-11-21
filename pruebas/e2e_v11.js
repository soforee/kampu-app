// Uso: node pruebas/e2e_v11.js [carpeta-capturas]  (requiere Playwright; KAMPU_WEB = URL del frontend)
// E2E sin simulaciones: navegador real -> Angular (ng serve) -> Spring Boot -> Oracle 23
const { chromium } = require('playwright');
const OUT = process.argv[2] || '.';
const W = process.env.KAMPU_WEB || 'http://localhost:4200';
let ok = 0, fallas = 0;
const check = (n, c, extra = '') => { if (c) { ok++; console.log('[OK]   ', n, extra); } else { fallas++; console.log('[FALLA]', n, extra); } };
(async () => {
  const b = await chromium.launch();
  const errores = [];
  const nueva = async (vp = { width: 1366, height: 900 }) => {
    const ctx = await b.newContext({ viewport: vp, acceptDownloads: true });
    const p = await ctx.newPage();
    p.on('pageerror', e => errores.push(e.message));
    p.on('console', m => { if (m.type() === 'error' && !/40[1349]|Failed to load resource/.test(m.text())) errores.push(m.text()); });
    return p;
  };
  const login = async (p, u, pass = 'Kampu2026*') => {
    await p.goto(W + '/login'); await p.fill('#usuario, input[autocomplete=username]', u).catch(async () => { await p.locator('input').first().fill(u); });
    await p.locator('input[type=password]').fill(pass); await p.keyboard.press('Enter'); await p.waitForURL(u => !u.toString().includes('/login'));
  };

  // ---------- 1. Visitante sin cuenta
  const v = await nueva();
  await v.goto(W + '/');
  await v.waitForSelector('[data-testid=cotizar]');
  await v.locator('[data-testid=cotizar]').first().click();
  await v.waitForURL(/\/cotizar\/\d+/);
  await v.waitForSelector('[data-testid=modo-invitado]');
  check('Cotizador abre sin login y marca "como visitante"', await v.isVisible('[data-testid=modo-invitado]'));
  await v.waitForSelector('[data-testid=cotizar-total]');
  const total1 = await v.textContent('[data-testid=cotizar-total]');
  await v.click('[aria-label="Adultos: uno más"]');
  await v.click('[aria-label="Niños: uno más"]');
  const primerServicio = v.locator('input[data-testid^=servicio-]').first();
  await primerServicio.check();
  await v.waitForTimeout(900);
  const total2 = await v.textContent('[data-testid=cotizar-total]');
  check('Personalizar cambia el precio calculado por el servidor', total1 !== total2, `${total1.trim()} -> ${total2.trim()}`);
  await v.screenshot({ path: OUT + '/01-cotizador-visitante.png', fullPage: true });
  await v.click('[data-testid=cotizar-guardar]');
  await v.waitForURL(/\/cotizacion\/KC-/);
  await v.waitForSelector('[data-testid=credenciales]');
  const codigo = (await v.textContent('[data-testid=codigo]')).trim();
  const clave = (await v.textContent('[data-testid=clave]')).trim();
  check('Guardar muestra código y clave', /^KC-\d{4}-\d{6}$/.test(codigo) && /^[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$/.test(clave), `${codigo} ${clave}`);
  check('Mismo total en el detalle', (await v.textContent('[data-testid=detalle-total]')).trim() === total2.trim());
  await v.screenshot({ path: OUT + '/02-cotizacion-guardada.png', fullPage: true });
  const [descarga] = await Promise.all([v.waitForEvent('download'), v.click('[data-testid=pdf]')]);
  check('Descarga el PDF', (await descarga.suggestedFilename()) === `cotizacion-${codigo}.pdf`);
  // Modificar
  await v.click('[data-testid=modificar]');
  await v.waitForURL(/editar=/);
  await v.waitForSelector('[data-testid=cotizar-total]');
  await v.waitForTimeout(600);
  await v.click('[aria-label="Niños: uno menos"]');
  await v.waitForTimeout(900);
  const total3 = (await v.textContent('[data-testid=cotizar-total]')).trim();
  await v.click('[data-testid=cotizar-guardar]');
  await v.waitForURL(/\/cotizacion\/KC-/);
  await v.waitForSelector('[data-testid=detalle-total]');
  check('Modificar guarda el nuevo total', (await v.textContent('[data-testid=detalle-total]')).trim() === total3, total3);
  check('Historial registra la modificación', (await v.textContent('[data-testid=historial]')).includes('Modificada'));
  // Solicitar reserva sin cuenta
  await v.click('[data-testid=abrir-solicitud]');
  await v.fill('#s-nombre', 'Rocío Paredes López');
  await v.fill('#s-doc', '74125896');
  await v.fill('#s-email', 'rocio.paredes@example.com');
  await v.locator('#s-telefono').fill('912345678');
  await v.screenshot({ path: OUT + '/03-solicitud.png', fullPage: true });
  await v.click('[data-testid=enviar-solicitud]');
  await v.waitForSelector('.swal2-popup');
  await v.click('.swal2-confirm');
  await v.waitForFunction(() => document.querySelector('[data-testid=estado-texto]')?.textContent?.includes('Solicitud'));
  check('Solicitud enviada sin cuenta -> pendiente', (await v.textContent('[data-testid=estado-texto]')).includes('Solicitud de reserva pendiente'));

  // ---------- 2. Recuperar desde otro dispositivo con código + clave
  const otro = await nueva({ width: 390, height: 844 });
  await otro.goto(W + '/seguimiento');
  await otro.fill('[data-testid=seg-codigo]', codigo);
  await otro.fill('[data-testid=seg-clave]', 'AAAA-BBBB-CCCC');
  await otro.click('[data-testid=seg-abrir]');
  await otro.waitForSelector('[role=alert]');
  check('Clave equivocada no abre la cotización', (await otro.textContent('[role=alert]')).includes('no son correctos'));
  await otro.fill('[data-testid=seg-clave]', clave.toLowerCase());
  await otro.click('[data-testid=seg-abrir]');
  await otro.waitForSelector('[data-testid=estado-texto]');
  check('Otro dispositivo (celular) recupera con código + clave', (await otro.textContent('[data-testid=estado-texto]')).includes('Solicitud'));
  await otro.screenshot({ path: OUT + '/04-seguimiento-celular.png', fullPage: true });

  // ---------- 3. El operador gestiona la solicitud
  const op = await nueva();
  await login(op, 'koperador');
  check('Operador ve el menú Cotizaciones', await op.isVisible('a[href="/cotizaciones"]'));
  await op.click('a[href="/cotizaciones"]');
  await op.waitForSelector(`[data-testid="ver-${codigo}"]`);
  await op.click(`[data-testid="ver-${codigo}"]`);
  await op.waitForSelector('[data-testid=confirmar]');
  await op.screenshot({ path: OUT + '/05-operador-solicitud.png' });
  await op.click('[data-testid=confirmar]');
  await op.click('.swal2-confirm');
  await op.waitForFunction(() => document.querySelector('[role=dialog]')?.textContent?.includes('KR-'));
  const txt = await op.textContent('[role=dialog]');
  const reserva = txt.match(/KR-\d{4}-\d+/)[0];
  check('Operador confirma -> reserva creada', !!reserva, reserva);
  const r = await op.request.get(W + '/api/v1/reservas', { headers: {} });
  check('El operador sigue sin acceso a la lista de reservas (403)', r.status() === 401 || r.status() === 403, String(r.status()));

  // ---------- 4. El visitante ve su reserva
  await v.reload();
  await v.waitForSelector('[data-testid=reserva]');
  check('Visitante ve su código de reserva', (await v.textContent('[data-testid=reserva]')).includes(reserva));
  await v.screenshot({ path: OUT + '/06-visitante-reserva.png', fullPage: true });

  // ---------- 5. Ventas ve la reserva con los adicionales
  const ve = await nueva();
  await login(ve, 'kventas');
  await ve.goto(W + '/reservas');
  await ve.waitForSelector(`text=${reserva}`);
  check('Ventas ve la reserva creada por la cotización', await ve.isVisible(`text=${reserva}`));

  // ---------- 6. Guía y conductor
  const gu = await nueva();
  await login(gu, 'kguia');
  check('Guía entra directo a Mis asignaciones', gu.url().endsWith('/mis-asignaciones'), gu.url());
  await gu.waitForSelector('[data-testid=salidas-guia] article');
  const menuGuia = await gu.$$eval('aside nav a, nav a[href^="/"]', as => as.map(a => a.getAttribute('href')).filter(h => h && h.startsWith('/') && h !== '/'));
  check('Menú del guía: solo Mis asignaciones', menuGuia.every(h => h === '/mis-asignaciones'), JSON.stringify([...new Set(menuGuia)]));
  await gu.locator('[data-testid^=ver-salida-]').first().click();
  await gu.waitForSelector('[data-testid=manifiesto] li:not(:has-text("Cargando"))'); await gu.waitForTimeout(400);
  await gu.screenshot({ path: OUT + '/07-guia.png', fullPage: true });
  await gu.goto(W + '/reservas');
  await gu.waitForTimeout(800);
  check('Guía que escribe /reservas vuelve a sus asignaciones', gu.url().endsWith('/mis-asignaciones'), gu.url());
  const co = await nueva();
  await login(co, 'kconductor');
  await co.waitForSelector('[data-testid=traslados-conductor] article');
  check('Conductor ve sus traslados', (await co.$$('[data-testid=traslados-conductor] article')).length > 0);
  await co.screenshot({ path: OUT + '/08-conductor.png', fullPage: true });

  // ---------- 7. Admin crea cuenta de guía para una persona del personal
  const ad = await nueva();
  await login(ad, 'kadmin');
  await ad.goto(W + '/usuarios');
  await ad.click('[data-testid=nuevo-usuario]');
  await ad.click('[role=dialog] label:has([data-testid=rol-GUIA])');
  await ad.waitForSelector('[data-testid=u-personal]');
  await ad.selectOption('[data-testid=u-personal]', { index: 1 });
  await ad.fill('#u-email', 'carlos.guia@kampu.pe');
  await ad.fill('#u-pass', 'Kampu2026*'); await ad.fill('#u-conf', 'Kampu2026*');
  await ad.screenshot({ path: OUT + '/09-admin-cuenta-guia.png' });
  await ad.click('text=Crear usuario');
  await ad.waitForSelector('text=ficha de personal: Carlos');
  check('Admin crea cuenta GUIA ligada a Carlos', await ad.isVisible('text=ficha de personal: Carlos'));

  // ---------- 8. Regresiones
  await ve.goto(W + '/dashboard'); await ve.waitForTimeout(1500);
  check('Ventas: panel carga', await ve.isVisible('text=Panel') || ve.url().endsWith('/dashboard'));
  const cl = await nueva();
  await login(cl, 'maria.rios@example.com');
  await cl.waitForSelector('[data-testid=paquete-cliente]');
  check('Cliente registrado: Mis paquetes sigue funcionando', (await cl.$$('[data-testid=paquete-cliente]')).length > 0);
  await cl.goto(W + '/cotizar/1');
  await cl.waitForSelector('[data-testid=modo-cliente]');
  check('Cliente registrado cotiza "con tu cuenta"', await cl.isVisible('[data-testid=modo-cliente]'));

  console.log('Errores de consola/página:', errores.length ? errores : 'ninguno');
  console.log(`\nRESULTADO E2E: ${ok} OK, ${fallas} FALLAS`);
  await b.close();
})().catch(e => { console.error('ERROR', e); process.exit(1); });
