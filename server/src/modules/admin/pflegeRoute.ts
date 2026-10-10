import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';

import type { AppConfig } from '../../app/config.js';
import type { ServerDependencies } from '../../app/dependencies.js';
import { type MeldungDocument, type Plattform, PLATTFORM_NAMEN, PLATTFORMEN, sortiereMeldungen } from '../appFeeds/model.js';
import {
    beschreibeMeldung,
    beschreibeVersion,
    type Befund,
    leseMeldung,
    leseVersion,
    type MeldungEingabe,
    type VersionEingabe,
    type Wirkung,
} from '../appFeeds/pruefung.js';
import {
    type Kopf,
    KONFLIKT,
    LEERE_MELDUNG,
    meldungAlsEingabe,
    renderMeldungenListe,
    renderMeldungFormular,
    renderMeldungLoeschen,
    renderMeldungVorschau,
    renderVersionen,
    renderVersionVorschau,
    versionAlsEingabe,
    type VersionFormular,
} from './pflegePage.js';
import { type AdminZugang, feld, type Formular, HTML_HEADERS } from './zugang.js';

// Pflege von Meldungen und Versionen unter /admin/meldungen und /admin/versionen
// (spec/app_feeds.md). Ablauf: Formular → Vorschau → Speichern → Redirect.

const HINWEISE: Record<string, string> = {
    gespeichert: 'Gespeichert. Die App lädt den neuen Stand beim nächsten Abruf.',
    geloescht: 'Gelöscht.',
};

// "neu" ist der Pfad des Anlegeformulars und deshalb keine gueltige ID.
const RESERVIERTE_IDS = ['neu'];

const hatFehler = (befunde: Befund[]) => befunde.some((b) => b.stufe === 'fehler');

const meldungEingabe = (formular: Formular | undefined): MeldungEingabe => {
    const eingabe = { ...LEERE_MELDUNG };
    for (const name of Object.keys(eingabe) as Array<keyof MeldungEingabe>) {
        eingabe[name] = feld(formular, name);
    }
    return eingabe;
};

const versionEingabe = (formular: Formular | undefined): VersionEingabe => {
    const eingabe = versionAlsEingabe(null);
    for (const name of Object.keys(eingabe) as Array<keyof VersionEingabe>) {
        eingabe[name] = feld(formular, name);
    }
    return eingabe;
};

const standVon = (document: { updated_at: Date } | null) => document?.updated_at.toISOString() ?? '';

export const registerPflegeRoutes = (
    server: FastifyInstance,
    config: AppConfig,
    dependencies: ServerDependencies,
    zugang: AdminZugang,
): void => {
    const { meldungenRepository, versionenRepository } = dependencies;

    const kopf = (request: FastifyRequest): Kopf => {
        const ok = (request.query as Record<string, unknown> | undefined)?.ok;
        return {
            stand: dependencies.clock(),
            version: config.gitSha,
            csrf: zugang.csrf,
            hinweis: typeof ok === 'string' ? HINWEISE[ok] ?? null : null,
        };
    };

    const html = (reply: FastifyReply, inhalt: string, status = 200) => reply.status(status).headers(HTML_HEADERS).send(inhalt);

    const nichtGefunden = (reply: FastifyReply) =>
        reply.status(404).send({ error: { code: 'not_found', message: 'Not found' } });

    // Telegram-Nachricht im Hintergrund; ein Fehler dort macht das Speichern nicht rueckgaengig.
    const melde = (request: FastifyRequest, titel: string, wirkung: Wirkung[], pfad: string) => {
        const notifier = dependencies.notifier;
        if (notifier == null) {
            return;
        }
        const text = [
            `NaMi-App: ${titel}`,
            ...wirkung.map((w) => w.text),
            ...(config.publicBaseUrl == null ? [] : ['', `${config.publicBaseUrl}${pfad}`]),
        ].join('\n');
        notifier.send(text).catch((error: unknown) => request.log.error(error, 'Admin change notification failed'));
    };

    // Login fuer jede Route, bei POST zusaetzlich der Formularschutz.
    const geschuetzt = (
        handler: (request: FastifyRequest, reply: FastifyReply) => Promise<unknown>,
    ) => async (request: FastifyRequest, reply: FastifyReply) => {
        if (!zugang.istAngemeldet(request)) {
            return zugang.ablehnen(reply);
        }
        if (request.method === 'POST' && !zugang.formularErlaubt(request)) {
            return zugang.fremdesFormular(reply);
        }
        return handler(request, reply);
    };

    const idAusPfad = (request: FastifyRequest): string => (request.params as { id: string }).id;
    const idAusPfadOderNull = (request: FastifyRequest): string | null => (request.params as { id?: string }).id ?? null;

    // ---- Meldungen ----

    server.get('/admin/meldungen', zugang.routeOptions, geschuetzt(async (request, reply) =>
        html(reply, renderMeldungenListe(kopf(request), sortiereMeldungen(await meldungenRepository.findAll())))));

    server.get('/admin/meldungen/neu', zugang.routeOptions, geschuetzt(async (request, reply) =>
        html(reply, renderMeldungFormular(kopf(request), { bestehend: null, eingabe: LEERE_MELDUNG, stand: '', befunde: [] }))));

    server.get('/admin/meldungen/:id', zugang.routeOptions, geschuetzt(async (request, reply) => {
        const meldung = await meldungenRepository.find(idAusPfad(request));
        return meldung == null
            ? nichtGefunden(reply)
            : html(reply, renderMeldungFormular(kopf(request), { bestehend: meldung.id, eingabe: meldungAlsEingabe(meldung), stand: standVon(meldung), befunde: [] }));
    }));

    // Gemeinsamer Ablauf fuer neue (bestehend null) und bestehende Meldungen.
    const pruefeMeldungsFormular = async (request: FastifyRequest, bestehend: string | null) => {
        const formular = request.body as Formular;
        const eingabe = meldungEingabe(formular);
        const stand = feld(formular, 'stand');
        const bisher = bestehend == null ? null : await meldungenRepository.find(bestehend);
        const vergeben = new Set([...RESERVIERTE_IDS, ...(await meldungenRepository.findAll()).map((m) => m.id)]);
        const { meldung, befunde } = leseMeldung(eingabe, bisher, vergeben, dependencies.clock());
        const konflikt = stand !== standVon(bisher);
        return { eingabe, stand, bisher, meldung, befunde: konflikt ? [KONFLIKT, ...befunde] : befunde, konflikt };
    };

    const meldungVorschau = geschuetzt(async (request, reply) => {
        const id = idAusPfadOderNull(request);
        const p = await pruefeMeldungsFormular(request, id);
        if (id != null && p.bisher == null) {
            return nichtGefunden(reply);
        }
        if (hatFehler(p.befunde)) {
            return html(reply, renderMeldungFormular(kopf(request), { bestehend: id, eingabe: p.eingabe, stand: p.stand, befunde: p.befunde }), 422);
        }
        return html(reply, renderMeldungVorschau(kopf(request), {
            bestehend: id,
            eingabe: p.eingabe,
            stand: p.stand,
            meldung: p.meldung,
            befunde: p.befunde,
            wirkung: beschreibeMeldung(p.bisher, p.meldung),
        }));
    });

    const meldungSpeichern = geschuetzt(async (request, reply) => {
        const id = idAusPfadOderNull(request);
        const p = await pruefeMeldungsFormular(request, id);
        if (id != null && p.bisher == null) {
            return nichtGefunden(reply);
        }
        const formular = { bestehend: id, eingabe: p.eingabe, stand: p.stand };
        if (feld(request.body as Formular, 'aktion') === 'zurueck') {
            return html(reply, renderMeldungFormular(kopf(request), { ...formular, befunde: p.konflikt ? [KONFLIKT] : [] }));
        }
        if (hatFehler(p.befunde)) {
            return html(reply, renderMeldungFormular(kopf(request), { ...formular, befunde: p.befunde }), p.konflikt ? 409 : 422);
        }
        if (!(await meldungenRepository.save(p.meldung, p.bisher?.updated_at ?? null))) {
            return html(reply, renderMeldungFormular(kopf(request), { ...formular, befunde: [KONFLIKT] }), 409);
        }
        melde(request, p.bisher == null ? 'Meldung angelegt' : 'Meldung geändert', beschreibeMeldung(p.bisher, p.meldung), '/admin/meldungen');
        return reply.redirect('/admin/meldungen?ok=gespeichert', 303);
    });

    server.post('/admin/meldungen/neu/vorschau', zugang.routeOptions, meldungVorschau);
    server.post('/admin/meldungen/neu', zugang.routeOptions, meldungSpeichern);
    server.post('/admin/meldungen/:id/vorschau', zugang.routeOptions, meldungVorschau);
    server.post('/admin/meldungen/:id', zugang.routeOptions, meldungSpeichern);

    const zumLoeschen = async (request: FastifyRequest): Promise<MeldungDocument | null> => meldungenRepository.find(idAusPfad(request));

    server.get('/admin/meldungen/:id/loeschen', zugang.routeOptions, geschuetzt(async (request, reply) => {
        const meldung = await zumLoeschen(request);
        return meldung == null ? nichtGefunden(reply) : html(reply, renderMeldungLoeschen(kopf(request), meldung, beschreibeMeldung(meldung, null)));
    }));

    server.post('/admin/meldungen/:id/loeschen', zugang.routeOptions, geschuetzt(async (request, reply) => {
        const meldung = await zumLoeschen(request);
        if (meldung == null) {
            return nichtGefunden(reply);
        }
        const stand = feld(request.body as Formular, 'stand');
        if (stand !== standVon(meldung) || !(await meldungenRepository.delete(meldung.id, meldung.updated_at))) {
            return html(reply, renderMeldungFormular(kopf(request), {
                bestehend: meldung.id, eingabe: meldungAlsEingabe(meldung), stand: standVon(meldung), befunde: [KONFLIKT],
            }), 409);
        }
        melde(request, 'Meldung gelöscht', beschreibeMeldung(meldung, null), '/admin/meldungen');
        return reply.redirect('/admin/meldungen?ok=geloescht', 303);
    }));

    // ---- Versionen ----

    const plattformAusPfad = (request: FastifyRequest): Plattform | null =>
        PLATTFORMEN.find((p) => p === (request.params as { plattform: string }).plattform) ?? null;

    // Beide Karten; die gerade bearbeitete Plattform mit Eingabe und Befunden.
    const versionenSeite = async (request: FastifyRequest, bearbeitet?: { plattform: Plattform; formular: VersionFormular }) => {
        const versionen = await versionenRepository.findAll();
        const formulare = Object.fromEntries(PLATTFORMEN.map((plattform) => {
            if (bearbeitet?.plattform === plattform) {
                return [plattform, bearbeitet.formular];
            }
            const version = versionen.find((v) => v.plattform === plattform) ?? null;
            return [plattform, { eingabe: versionAlsEingabe(version), stand: standVon(version), befunde: [] }];
        })) as Record<Plattform, VersionFormular>;
        return renderVersionen(kopf(request), formulare);
    };

    const pruefeVersionsFormular = async (request: FastifyRequest, plattform: Plattform) => {
        const formular = request.body as Formular;
        const eingabe = versionEingabe(formular);
        const stand = feld(formular, 'stand');
        const bisher = (await versionenRepository.findAll()).find((v) => v.plattform === plattform) ?? null;
        const { version, befunde } = leseVersion(plattform, eingabe, bisher, dependencies.clock());
        const konflikt = stand !== standVon(bisher);
        return { eingabe, stand, bisher, version, befunde: konflikt ? [KONFLIKT, ...befunde] : befunde, konflikt };
    };

    server.get('/admin/versionen', zugang.routeOptions, geschuetzt(async (request, reply) => html(reply, await versionenSeite(request))));

    server.post('/admin/versionen/:plattform/vorschau', zugang.routeOptions, geschuetzt(async (request, reply) => {
        const plattform = plattformAusPfad(request);
        if (plattform == null) {
            return nichtGefunden(reply);
        }
        const p = await pruefeVersionsFormular(request, plattform);
        if (hatFehler(p.befunde)) {
            return html(reply, await versionenSeite(request, { plattform, formular: { eingabe: p.eingabe, stand: p.stand, befunde: p.befunde } }), 422);
        }
        return html(reply, renderVersionVorschau(kopf(request), {
            plattform,
            eingabe: p.eingabe,
            stand: p.stand,
            befunde: p.befunde,
            wirkung: beschreibeVersion(p.bisher, p.version),
        }));
    }));

    server.post('/admin/versionen/:plattform', zugang.routeOptions, geschuetzt(async (request, reply) => {
        const plattform = plattformAusPfad(request);
        if (plattform == null) {
            return nichtGefunden(reply);
        }
        const p = await pruefeVersionsFormular(request, plattform);
        const formular = (befunde: Befund[]) => ({ plattform, formular: { eingabe: p.eingabe, stand: p.stand, befunde } });
        if (feld(request.body as Formular, 'aktion') === 'zurueck') {
            return html(reply, await versionenSeite(request, formular(p.konflikt ? [KONFLIKT] : [])));
        }
        if (hatFehler(p.befunde)) {
            return html(reply, await versionenSeite(request, formular(p.befunde)), p.konflikt ? 409 : 422);
        }
        if (!(await versionenRepository.save(p.version, p.bisher?.updated_at ?? null))) {
            return html(reply, await versionenSeite(request, formular([KONFLIKT])), 409);
        }
        melde(
            request,
            `Versionen ${PLATTFORM_NAMEN[plattform]} ${p.bisher == null ? 'angelegt' : 'geändert'}`,
            beschreibeVersion(p.bisher, p.version),
            '/admin/versionen',
        );
        return reply.redirect('/admin/versionen?ok=gespeichert', 303);
    }));
};
