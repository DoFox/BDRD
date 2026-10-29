// Test de kern van invoer.html (validatie + SQL-generatie). Gebruik:
//   node testdata/test.js            controleert tegen testdata/verwacht/*.sql
//   node testdata/test.js --update   schrijft de verwachte .sql opnieuw
// Alle gegevens zijn verzonnen.
'use strict';
const fs = require('fs'), path = require('path'), vm = require('vm'), assert = require('assert');
const dir = __dirname;
const html = fs.readFileSync(path.join(dir, '..', 'invoer.html'), 'utf8');
const code = /<script id="core">([\s\S]*?)<\/script>/.exec(html)[1];
const ctx = {}; vm.createContext(ctx); vm.runInContext(code + '\nthis.Core = Core;', ctx);
const Core = ctx.Core;
const update = process.argv.includes('--update');
const NOW = new Date(2026, 9, 29, 13, 5, 11);   // vaste tijd: 2026-10-29 13:05:11 lokaal

// ---- generatoren voor geldige testwaarden ----
function bsn(seed) {            // 9 cijfers met geldige elfproef
  for (let n = seed; ; n++) {
    const s = String(n).padStart(8, '0');
    let sum = 0; for (let i = 0; i < 8; i++) sum += (9 - i) * +s[i];
    const last = sum % 11; if (last < 10) { const r = s + last; if (Core.validBsn(r)) return r; }
  }
}
function iban(cc, bank, acct) {  // NL99BANK0123456789 met correct controlegetal
  const body = bank + acct, tmp = body + cc + '00';
  let rem = 0; for (const ch of tmp) { const v = /\d/.test(ch) ? ch : String(ch.charCodeAt(0) - 55); for (const d of v) rem = (rem * 10 + +d) % 97; }
  return cc + String(98 - rem).padStart(2, '0') + body;
}
const IBAN1 = iban('NL', 'TEST', '0000000001'), IBAN2 = iban('NL', 'TEST', '0000000002'), IBAN3 = iban('NL', 'TEST', '0000000003');
const IBAN_BE = iban('BE', '', '539007547034');

const addrNL = (o) => Object.assign({ type: 'Home', street: 'Teststraat', hn: '12', suffix: 'B', pc: '1234 ab', city: 'Testdorp', country: 'NL', pobox: '', other: '', start: '2020-01-01' }, o);
const newAcc = (o) => Object.assign({ mode: 'new', nr: IBAN1, ptype: 'Betaalrekening', role: 'AccountHolder', relationship: '', roleStart: '', status: 'Active',
  contract: 'KEB Hana Bank Amsterdam', name: 'J. Jansen', opening: '2024-03-01', closing: '', currency: 'EUR' }, o);
const np = (o) => Object.assign({ type: 'NaturalPerson', nr: 'GEUNL01900000001', bsn: bsn(10000001), dob: '1980-05-17', fi: 'J', oi: 'P', fn: 'Jan', prefix: 'van', ln: 'Testman' }, o);
const le = (o) => Object.assign({ type: 'LegalEntity', nr: 'GEUNL01900000002', kvk: '12345678', org: 'Testbedrijf B.V.' }, o);
const base = (o) => Object.assign({ db: 'Test_BDRC', door: 'Test Medewerker', customer: np(), addresses: [addrNL()], accounts: [newAcc()], ubos: [] }, o);

function run(model) { const m = Core.prepare(JSON.parse(JSON.stringify(model))); return { m, errs: Core.validate(m, NOW) }; }
function paths(model) { return run(model).errs.map(e => e.path); }

let failed = 0, passed = 0;
function t(name, fn) { try { fn(); passed++; } catch (e) { failed++; console.log('FOUT  ' + name + '\n      ' + (e.message || e).split('\n').join('\n      ')); } }
function expectOk(name, model) { t(name, () => { const r = run(model); assert.strictEqual(JSON.stringify(r.errs), '[]'); }); }
function expectErr(name, model, path, frag) {
  t(name, () => {
    const r = run(model);
    const hit = r.errs.filter(e => e.path === path && (!frag || e.msg.includes(frag)));
    assert(hit.length, 'verwachtte fout op ' + path + (frag ? ' met "' + frag + '"' : '') + '; kreeg: ' + JSON.stringify(r.errs));
  });
}

// ---- goede invoer + verwachte SQL ----
const cases = {
  natuurlijk_persoon_nieuwe_rekening: base({ customer: np({ ln: "D'Angelo" }) }),
  natuurlijk_persoon_gemachtigde_bestaande_rekening: base({
    customer: np({ nr: 'GEUNL01900000003', bsn: bsn(20000001) }),
    accounts: [newAcc({ mode: 'existing', nr: IBAN2, role: 'AuthorizedRepresentative', relationship: 'Guardian', roleStart: '2025-02-01' })] }),
  rechtspersoon_met_nieuwe_ubo_en_bestaande_ubo: base({
    customer: le(), addresses: [addrNL({ type: 'RegisteredOffice' })],
    accounts: [newAcc({ nr: IBAN3, ptype: 'Spaarrekening', name: 'Testbedrijf B.V.', currency: 'USD' })],
    ubos: [{ mode: 'existing', nr: 'GEUNL01900000010', start: '2024-03-01' },
           { mode: 'new', nr: 'GEUNL01900000011', start: '', bsn: bsn(30000001), dob: '1975-12-01', fi: 'M', oi: '', fn: 'Marie', prefix: '', ln: 'Müller-Ñoño',
             addr: { type: 'Home', street: '', hn: '', suffix: '', pc: '', city: 'München', country: 'DE', pobox: '', other: 'Hauptstraße 5, 80331 München', start: '' } }] }),
  gesloten_rekening_in_vreemde_valuta: base({ customer: np({ nr: 'GEUNL01900000004', bsn: bsn(40000001) }),
    accounts: [newAcc({ nr: IBAN_BE, status: 'Discontinued', closing: '2025-01-31', currency: 'GBP' })] })
};
Object.keys(cases).forEach(name => {
  t('geldig: ' + name, () => {
    const { m, errs } = run(cases[name]);
    assert.strictEqual(JSON.stringify(errs), '[]');
    const out = Core.generate(m, NOW);
    const f = path.join(dir, 'verwacht', name + '.sql');
    const inp = path.join(dir, 'invoer', name + '.json');
    if (update) { fs.mkdirSync(path.dirname(f), { recursive: true }); fs.mkdirSync(path.dirname(inp), { recursive: true });
      fs.writeFileSync(f, out.sql); fs.writeFileSync(inp, JSON.stringify(cases[name], null, 2) + '\n'); }
    else assert.strictEqual(out.sql, fs.readFileSync(f, 'utf8'), 'SQL wijkt af van ' + f);
    assert(/\r\n/.test(out.sql) && !/[^\r]\n/.test(out.sql), 'regeleinde moet CRLF zijn');
    assert(/^handinvoer_GEUNL01\d{9}_20261029-130511\.sql$/.test(out.file));
  });
});
t('apostrof wordt verdubbeld', () => {
  const { m } = run(cases.natuurlijk_persoon_nieuwe_rekening);
  assert(Core.generate(m, NOW).sql.includes("N'D''Angelo'"));
});
t('postcode genormaliseerd', () => {
  const { m } = run(base());
  assert.strictEqual(m.addresses[0].pc, '1234AB');
});
t('rol-startdatum standaard = openingsdatum', () => {
  const { m } = run(base());
  assert.strictEqual(m.accounts[0].roleStart, '2024-03-01');
});

// ---- elke validatieregel ----
expectErr('naam medewerker verplicht', base({ door: '' }), 'door');
expectErr('databasenaam ongeldig', base({ db: 'My]; DROP' }), 'db');
expectErr('klantnummer formaat', base({ customer: np({ nr: 'GEUNL0190000001' }) }), 'customer.nr', 'GEUNL01');
expectErr('klantnummer verplicht', base({ customer: np({ nr: '' }) }), 'customer.nr');
expectErr('BSN elfproef', base({ customer: np({ bsn: '123456789' }) }), 'customer.bsn', 'elfproef');
expectErr('BSN lengte', base({ customer: np({ bsn: '1234567' }) }), 'customer.bsn', '8 of 9');
expectErr('BSN verplicht bij NL Home + rekeninghouder', base({ customer: np({ bsn: '' }) }), 'customer.bsn', 'verplicht');
expectOk('BSN niet verplicht zonder NL Home-adres', base({ customer: np({ bsn: '' }), addresses: [addrNL({ country: 'DE', pc: '', street: '', hn: '', city: 'Berlijn', other: 'Straße 1' })] }));
expectOk('BSN van 8 cijfers (voorloopnul)', base({ customer: np({ bsn: (() => { for (let n = 1000000; ; n++) { const s = String(n).padStart(9, '0'); if (Core.validBsn(s) && s[0] === '0') return s.slice(1); } })() }) }));
expectErr('geboortedatum toekomst', base({ customer: np({ dob: '2026-10-30' }) }), 'customer.dob', 'toekomst');
expectErr('geboortedatum ongeldig', base({ customer: np({ dob: '2026-02-30' }) }), 'customer.dob');
expectErr('eerste voorletter 1 teken', base({ customer: np({ fi: 'JP' }) }), 'customer.fi');
expectErr('voorletters zonder punten', base({ customer: np({ oi: 'P.Q' }) }), 'customer.oi');
expectErr('achternaam verplicht', base({ customer: np({ ln: '' }) }), 'customer.ln');
expectErr('achternaam lengte', base({ customer: np({ ln: 'x'.repeat(201) }) }), 'customer.ln', 'te lang');
expectErr('tussenvoegsel lengte', base({ customer: np({ prefix: 'x'.repeat(11) }) }), 'customer.prefix', 'te lang');
expectErr('KvK verplicht', base({ customer: le({ kvk: '' }), addresses: [addrNL({ type: 'RegisteredOffice' })], ubos: [{ mode: 'existing', nr: 'GEUNL01900000010' }] }), 'customer.kvk');
expectErr('organisatienaam verplicht', base({ customer: le({ org: '' }), addresses: [addrNL({ type: 'RegisteredOffice' })], ubos: [{ mode: 'existing', nr: 'GEUNL01900000010' }] }), 'customer.org');
expectErr('IBAN controlegetal', base({ accounts: [newAcc({ nr: IBAN1.slice(0, 2) + '00' + IBAN1.slice(4) })] }), 'accounts.0.nr', 'IBAN');
expectErr('NL IBAN patroon', base({ accounts: [newAcc({ nr: iban('NL', '1234', '0000000001') })] }), 'accounts.0.nr', 'Nederlands');
expectOk('IBAN met spaties en kleine letters', base({ accounts: [newAcc({ nr: IBAN1.toLowerCase().replace(/(.{4})/g, '$1 ') })] }));
expectErr('postcode formaat NL', base({ addresses: [addrNL({ pc: '12345' })] }), 'addresses.0.pc', '1234AB');
expectErr('NL straat vereist huisnummer', base({ addresses: [addrNL({ hn: '' })] }), 'addresses.0.hn');
expectErr('NL straat vereist plaats', base({ addresses: [addrNL({ city: '' })] }), 'addresses.0.city');
expectErr('NL straat vereist postcode', base({ addresses: [addrNL({ pc: '' })] }), 'addresses.0.pc');
expectErr('straat en postbus niet allebei', base({ addresses: [addrNL({ pobox: '123' })] }), 'addresses.0.pobox', 'óf');
expectErr('postbus zonder woord Postbus', base({ addresses: [addrNL({ street: '', hn: '', pobox: 'Postbus 123' })] }), 'addresses.0.pobox', 'Postbus');
expectErr('adres zonder straat/postbus/overig', base({ addresses: [addrNL({ street: '', hn: '', pc: '', city: '' })] }), 'addresses.0.street');
expectErr('land ongeldig', base({ addresses: [addrNL({ country: 'XX' })] }), 'addresses.0.country');
expectErr('RegisteredOffice niet voor natuurlijk persoon', base({ addresses: [addrNL({ type: 'RegisteredOffice' }), addrNL()] }), 'addresses.0.type');
expectErr('Home niet voor rechtspersoon', base({ customer: le(), addresses: [addrNL({ type: 'Home' })], ubos: [{ mode: 'existing', nr: 'GEUNL01900000010' }] }), 'addresses.0.type');
expectErr('Home-adres verplicht voor NP-rekeninghouder', base({ addresses: [addrNL({ type: 'Postal' })] }), 'addresses', 'Home');
expectErr('dubbel adrestype', base({ addresses: [addrNL(), addrNL()] }), 'addresses.1.type', 'al ingevoerd');
expectErr('adres lengte straat', base({ addresses: [addrNL({ street: 'x'.repeat(101) })] }), 'addresses.0.street', 'te lang');
expectErr('geen rekening', base({ accounts: [] }), 'accounts', 'minimaal');
expectErr('dubbele rekening', base({ accounts: [newAcc(), newAcc()] }), 'accounts.1.nr', 'al ingevoerd');
expectOk('zelfde rekening in twee valuta’s', base({ accounts: [newAcc(), newAcc({ currency: 'USD' })] }));
expectErr('valuta ongeldig', base({ accounts: [newAcc({ currency: 'XXX' })] }), 'accounts.0.currency');
expectErr('openingsdatum verplicht', base({ accounts: [newAcc({ opening: '' })] }), 'accounts.0.opening');
expectErr('Discontinued vereist sluitingsdatum', base({ accounts: [newAcc({ status: 'Discontinued' })] }), 'accounts.0.closing');
expectErr('Active heeft geen sluitingsdatum', base({ accounts: [newAcc({ closing: '2025-01-01' })] }), 'accounts.0.closing', 'geen sluitingsdatum');
expectErr('Frozen heeft geen sluitingsdatum', base({ accounts: [newAcc({ status: 'Frozen', closing: '2025-01-01' })] }), 'accounts.0.closing');
expectErr('opening = sluiting', base({ accounts: [newAcc({ status: 'Discontinued', closing: '2024-03-01' })] }), 'accounts.0.closing', 'gelijk');
expectErr('sluiting voor opening', base({ accounts: [newAcc({ status: 'Discontinued', closing: '2023-01-01' })] }), 'accounts.0.closing', 'vóór');
expectErr('gemachtigde vereist relatie', base({ accounts: [newAcc({ mode: 'existing', role: 'AuthorizedRepresentative' })] }), 'accounts.0.relationship');
expectErr('relatie alleen bij gemachtigde (genegeerd → leeg)', base({ accounts: [newAcc({ mode: 'existing', role: 'AuthorizedRepresentative', relationship: 'Boze Geest' })] }), 'accounts.0.relationship');
t('relatie bij AccountHolder wordt niet meegenomen', () => { assert.strictEqual(run(base({ accounts: [newAcc({ relationship: 'Guardian' })] })).m.accounts[0].relationship, ''); });
expectErr('nieuwe rekening vereist AccountHolder', base({ accounts: [newAcc({ role: 'AuthorizedRepresentative', relationship: 'Guardian' })] }), 'accounts.0.role', 'AccountHolder');
expectErr('rol-startdatum ongeldig', base({ accounts: [newAcc({ roleStart: '2024-13-01' })] }), 'accounts.0.roleStart');
expectErr('bestaande + nieuwe rekening zelfde nummer', base({ accounts: [newAcc(), newAcc({ mode: 'existing', role: 'AuthorizedRepresentative', relationship: 'Guardian' })] }), 'accounts.1.nr');
expectErr('rechtspersoon rekeninghouder vereist UBO', base({ customer: le(), addresses: [addrNL({ type: 'RegisteredOffice' })] }), 'ubos', 'minimaal één UBO');
expectErr('UBO dezelfde als rechtspersoon', base({ customer: le(), addresses: [addrNL({ type: 'RegisteredOffice' })], ubos: [{ mode: 'existing', nr: 'GEUNL01900000002' }] }), 'ubos.0.nr');
expectErr('dubbele UBO', base({ customer: le(), addresses: [addrNL({ type: 'RegisteredOffice' })], ubos: [{ mode: 'existing', nr: 'GEUNL01900000010' }, { mode: 'existing', nr: 'GEUNL01900000010' }] }), 'ubos.1.nr');
expectErr('UBO klantnummer formaat', base({ customer: le(), addresses: [addrNL({ type: 'RegisteredOffice' })], ubos: [{ mode: 'existing', nr: 'X' }] }), 'ubos.0.nr');
expectErr('nieuwe UBO: achternaam verplicht', base({ customer: le(), addresses: [addrNL({ type: 'RegisteredOffice' })], ubos: [{ mode: 'new', nr: 'GEUNL01900000011', ln: '', addr: addrNL() }] }), 'ubos.0.ln');
expectErr('nieuwe UBO: adres gecontroleerd', base({ customer: le(), addresses: [addrNL({ type: 'RegisteredOffice' })], ubos: [{ mode: 'new', nr: 'GEUNL01900000011', ln: 'Test', addr: addrNL({ pc: 'abc' }) }] }), 'ubos.0.addr.pc');
expectErr('nieuwe UBO: BSN elfproef', base({ customer: le(), addresses: [addrNL({ type: 'RegisteredOffice' })], ubos: [{ mode: 'new', nr: 'GEUNL01900000011', ln: 'Test', bsn: '111111111', addr: addrNL() }] }), 'ubos.0.bsn');
expectErr('UBO bij natuurlijk persoon niet toegestaan', base({ ubos: [{ mode: 'existing', nr: 'GEUNL01900000010' }] }), 'ubos', 'alleen voor rechtspersonen');
expectErr('tekst NULL niet toegestaan', base({ customer: np({ fn: 'null' }) }), 'customer.fn', 'NULL');
expectErr('tekst NULL in adres', base({ addresses: [addrNL({ city: 'NULL' })] }), 'addresses.0.city', 'NULL');
expectOk('naam Nullens is geen NULL', base({ customer: np({ ln: 'Nullens' }) }));
t('begin- en eindspaties worden verwijderd', () => { assert.strictEqual(run(base({ customer: np({ ln: '  Test  ' }) })).m.customer.ln, 'Test'); });
t('alle fouten tegelijk', () => { assert(run(base({ door: '', customer: np({ nr: 'x', ln: '' }) })).errs.length >= 3); });

console.log((failed ? 'MISLUKT' : 'OK') + ': ' + passed + ' geslaagd, ' + failed + ' mislukt' + (update ? ' (verwachte uitvoer bijgewerkt)' : ''));
process.exit(failed ? 1 : 0);
