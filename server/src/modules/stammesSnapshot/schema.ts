import { z } from 'zod';

import { AppError } from '../../shared/errors.js';

const SUPPORTED_SCHEMA_VERSION = '2026-10-01';
// ISO 8601 erlaubt beliebig viele Nachkommastellen; Dart sendet z. B. Mikrosekunden.
const ISO_TIMESTAMP_PATTERN = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,9})?(?:Z|[+-]\d{2}:\d{2})$/;

const missingRequiredFieldCode = 'missing_required_field';
const invalidDateTimeCode = 'invalid_datetime';
const invalidMetricValueCode = 'invalid_metric_value';
const unsupportedSchemaVersionCode = 'unsupported_schema_version';
const invalidStammPlausibilityCode = 'invalid_stamm_plausibility';
const invalidSnapshotPayloadCode = 'invalid_snapshot_payload';
const invalidCoverageCode = 'invalid_coverage';

export const STUFEN = ['biber', 'woelflinge', 'jungpfadfinder', 'pfadfinder', 'rover'] as const;
export type Stufe = (typeof STUFEN)[number];
export const ABDECKUNGEN = ['stamm', 'gruppen'] as const;
export type Abdeckung = (typeof ABDECKUNGEN)[number];
// Begrenzt die Payload; ein Stamm hat in der Praxis deutlich weniger Stufengruppen.
export const MAX_GRUPPEN = 50;

const requiredStringField = () =>
    z.any().transform((value, ctx) => {
        if (typeof value !== 'string' || value.trim() === '') {
            ctx.addIssue({
                code: 'custom',
                message: missingRequiredFieldCode,
            });

            return z.NEVER;
        }

        return value.trim();
    });

const optionalStringField = z.any().optional().transform((value, ctx) => {
    if (value === undefined || value === null) {
        return null;
    }

    if (typeof value !== 'string' || value.trim() === '') {
        ctx.addIssue({
            code: 'custom',
            message: invalidSnapshotPayloadCode,
        });

        return z.NEVER;
    }

    return value.trim();
});

const isoDateTimeField = () =>
    z.any().transform((value, ctx) => {
        if (value === undefined || value === null || value === '') {
            ctx.addIssue({
                code: 'custom',
                message: missingRequiredFieldCode,
            });

            return z.NEVER;
        }

        if (
            typeof value !== 'string'
            || !ISO_TIMESTAMP_PATTERN.test(value.trim())
            || Number.isNaN(Date.parse(value.trim()))
        ) {
            ctx.addIssue({
                code: 'custom',
                message: invalidDateTimeCode,
            });

            return z.NEVER;
        }

        return value.trim();
    });

const schemaVersionField = z.any().transform((value, ctx) => {
    if (typeof value !== 'string' || value.trim() === '') {
        ctx.addIssue({
            code: 'custom',
            message: missingRequiredFieldCode,
        });

        return z.NEVER;
    }

    if (value.trim() !== SUPPORTED_SCHEMA_VERSION) {
        ctx.addIssue({
            code: 'custom',
            message: unsupportedSchemaVersionCode,
        });

        return z.NEVER;
    }

    return value.trim();
});

const nullableMetricField = z.any().optional().transform((value, ctx) => {
    if (value === undefined || value === null) {
        return null;
    }

    if (typeof value !== 'number' || !Number.isInteger(value) || value < 0) {
        ctx.addIssue({
            code: 'custom',
            message: invalidMetricValueCode,
        });

        return z.NEVER;
    }

    return value;
});

const countByGenderSchema = z
    .preprocess(
        (value) => value ?? {},
        z.object({
            gesamt: nullableMetricField,
            maennlich: nullableMetricField,
            weiblich: nullableMetricField,
            divers: nullableMetricField,
            geschlecht_unbekannt: nullableMetricField,
        }),
    )
    .transform((value) => ({
        gesamt: value.gesamt ?? null,
        maennlich: value.maennlich ?? null,
        weiblich: value.weiblich ?? null,
        divers: value.divers ?? null,
        geschlecht_unbekannt: value.geschlecht_unbekannt ?? null,
    }));

const aktiveMitgliederSchema = z
    .preprocess(
        (value) => value ?? {},
        z.object({
            gesamt: nullableMetricField,
            normaler_beitrag: nullableMetricField,
            familienermaessigter_beitrag: nullableMetricField,
            sozialermaessigter_beitrag: nullableMetricField,
        }),
    )
    .transform((value) => ({
        gesamt: value.gesamt ?? null,
        normaler_beitrag: value.normaler_beitrag ?? null,
        familienermaessigter_beitrag: value.familienermaessigter_beitrag ?? null,
        sozialermaessigter_beitrag: value.sozialermaessigter_beitrag ?? null,
    }));

const leitendeSchema = z
    .preprocess(
        (value) => value ?? {},
        z.object({
            gesamt: nullableMetricField,
            unter_21: nullableMetricField,
            von_21_bis_30: nullableMetricField,
            von_31_bis_40: nullableMetricField,
            von_41_bis_50: nullableMetricField,
            von_51_bis_60: nullableMetricField,
            ueber_60: nullableMetricField,
        }),
    )
    .transform((value) => ({
        gesamt: value.gesamt ?? null,
        unter_21: value.unter_21 ?? null,
        von_21_bis_30: value.von_21_bis_30 ?? null,
        von_31_bis_40: value.von_31_bis_40 ?? null,
        von_41_bis_50: value.von_41_bis_50 ?? null,
        von_51_bis_60: value.von_51_bis_60 ?? null,
        ueber_60: value.ueber_60 ?? null,
    }));

// Nur stammweite Kennzahlen; Stufenwerte bildet der Server aus den Gruppen.
const metricsSchema = z
    .object({
        aktive_mitglieder: aktiveMitgliederSchema,
        passive_mitglieder: nullableMetricField,
        leitende: leitendeSchema,
        nicht_leitende_erwachsene: nullableMetricField,
        stammesvorstand: nullableMetricField,
        kuraten: nullableMetricField,
    })
    .transform((value) => ({
        aktive_mitglieder: value.aktive_mitglieder,
        passive_mitglieder: value.passive_mitglieder ?? null,
        leitende: value.leitende,
        nicht_leitende_erwachsene: value.nicht_leitende_erwachsene ?? null,
        stammesvorstand: value.stammesvorstand ?? null,
        kuraten: value.kuraten ?? null,
    }));

export type StammMetrics = z.infer<typeof metricsSchema>;
export type CountByGender = z.infer<typeof countByGenderSchema>;

const stufeField = z.any().transform((value, ctx) => {
    if (value === undefined || value === null || value === '') {
        ctx.addIssue({ code: 'custom', message: missingRequiredFieldCode });
        return z.NEVER;
    }
    if (typeof value !== 'string' || !(STUFEN as readonly string[]).includes(value)) {
        ctx.addIssue({ code: 'custom', message: invalidSnapshotPayloadCode });
        return z.NEVER;
    }
    return value as Stufe;
});

const requiredBooleanField = z.any().transform((value, ctx) => {
    if (typeof value !== 'boolean') {
        ctx.addIssue({
            code: 'custom',
            message: value === undefined || value === null ? missingRequiredFieldCode : invalidSnapshotPayloadCode,
        });
        return z.NEVER;
    }
    return value;
});

// Nicht abgedeckte Gruppen tragen nur zur Gruppenstruktur bei, ihre Zaehler werden verworfen.
const gruppeSchema = z
    .object({
        gruppe_id: requiredStringField(),
        stufe: stufeField,
        abgedeckt: requiredBooleanField,
        mitglieder: countByGenderSchema,
        leitende: countByGenderSchema,
    })
    .transform((value) => ({
        gruppe_id: value.gruppe_id,
        stufe: value.stufe,
        abgedeckt: value.abgedeckt,
        mitglieder: value.abgedeckt ? value.mitglieder : null,
        leitende: value.abgedeckt ? value.leitende : null,
    }));

export type SnapshotGruppe = z.infer<typeof gruppeSchema>;

const abdeckungField = z.any().transform((value, ctx) => {
    if (value === undefined || value === null || value === '') {
        ctx.addIssue({ code: 'custom', message: missingRequiredFieldCode });
        return z.NEVER;
    }
    if (typeof value !== 'string' || !(ABDECKUNGEN as readonly string[]).includes(value)) {
        ctx.addIssue({ code: 'custom', message: invalidSnapshotPayloadCode });
        return z.NEVER;
    }
    return value as Abdeckung;
});

const gruppenField = z.any().transform((value, ctx) => {
    if (value === undefined || value === null) {
        ctx.addIssue({ code: 'custom', message: missingRequiredFieldCode });
        return z.NEVER;
    }
    if (!Array.isArray(value) || value.length === 0 || value.length > MAX_GRUPPEN) {
        ctx.addIssue({ code: 'custom', message: invalidSnapshotPayloadCode });
        return z.NEVER;
    }

    const gruppen: SnapshotGruppe[] = [];
    value.forEach((entry, index) => {
        const parsed = gruppeSchema.safeParse(entry ?? {});
        if (!parsed.success) {
            for (const issue of parsed.error.issues) {
                ctx.addIssue({ ...issue, path: [index, ...issue.path] });
            }
            return;
        }
        gruppen.push(parsed.data);
    });

    return gruppen;
});

const stammesSnapshotSchema = z.object({
    schema_version: schemaVersionField,
    stamm_id: requiredStringField(),
    dv_id: optionalStringField,
    bezirk_id: optionalStringField,
    sender_id: requiredStringField(),
    sent_at: isoDateTimeField(),
    source_data_as_of: isoDateTimeField(),
    abdeckung: abdeckungField,
    gruppen: gruppenField,
    metrics: z.any(),
}).transform((value, ctx) => {
    const { abdeckung, gruppen } = value;
    const ids = new Set(gruppen.map((gruppe) => gruppe.gruppe_id));
    const abgedeckte = gruppen.filter((gruppe) => gruppe.abgedeckt);

    if (
        ids.size !== gruppen.length
        || (abdeckung === 'stamm' && abgedeckte.length !== gruppen.length)
        || (abdeckung === 'gruppen' && abgedeckte.length === 0)
    ) {
        ctx.addIssue({ code: 'custom', message: invalidCoverageCode, path: ['gruppen'] });
        return z.NEVER;
    }

    if (!abgedeckte.some((gruppe) => (gruppe.mitglieder?.gesamt ?? 0) > 0)) {
        ctx.addIssue({ code: 'custom', message: invalidStammPlausibilityCode, path: ['gruppen'] });
        return z.NEVER;
    }

    // Stammweite Werte aus einer Teilsicht waeren falsch und werden verworfen.
    let metrics: StammMetrics | null = null;
    if (abdeckung === 'stamm') {
        if (value.metrics === undefined || value.metrics === null) {
            ctx.addIssue({ code: 'custom', message: missingRequiredFieldCode, path: ['metrics'] });
            return z.NEVER;
        }
        const parsedMetrics = metricsSchema.safeParse(value.metrics);
        if (!parsedMetrics.success) {
            for (const issue of parsedMetrics.error.issues) {
                ctx.addIssue({ ...issue, path: ['metrics', ...issue.path] });
            }
            return z.NEVER;
        }
        metrics = parsedMetrics.data;
    }

    return { ...value, metrics };
});

export type StammesSnapshotPayload = z.infer<typeof stammesSnapshotSchema>;

const errorCodePriority = [
    unsupportedSchemaVersionCode,
    missingRequiredFieldCode,
    invalidDateTimeCode,
    invalidMetricValueCode,
    invalidCoverageCode,
    invalidStammPlausibilityCode,
    invalidSnapshotPayloadCode,
] as const;

const mapIssueToCode = (issue: z.ZodIssue): string => {
    if (errorCodePriority.includes(issue.message as (typeof errorCodePriority)[number])) {
        return issue.message;
    }

    const fieldPath = issue.path.join('.');

    if (fieldPath === 'sent_at' || fieldPath === 'source_data_as_of') {
        return invalidDateTimeCode;
    }

    if (fieldPath.startsWith('metrics') || /^gruppen\.\d+\.(mitglieder|leitende)/.test(fieldPath)) {
        return invalidMetricValueCode;
    }

    return invalidSnapshotPayloadCode;
};

const buildValidationError = (issues: z.ZodIssue[]): AppError => {
    const codes = issues.map(mapIssueToCode);
    const mainCode =
        errorCodePriority.find((code) => codes.includes(code)) ?? invalidSnapshotPayloadCode;
    const fields = [...new Set(
        issues
            .map((issue) => issue.path.join('.'))
            .filter((fieldPath) => fieldPath.length > 0),
    )];

    return new AppError(
        'Snapshot payload is invalid',
        400,
        mainCode,
        fields,
    );
};

// Zeitstempel in der Zukunft wuerden einen Stamm dauerhaft als "neuesten Stand" festschreiben.
const MAX_CLOCK_SKEW_MS = 24 * 60 * 60 * 1000;

const findFutureTimestampFields = (
    snapshot: StammesSnapshotPayload,
    now: Date,
): string[] => {
    const latestAllowed = now.getTime() + MAX_CLOCK_SKEW_MS;

    return (['sent_at', 'source_data_as_of'] as const).filter(
        (fieldName) => Date.parse(snapshot[fieldName]) > latestAllowed,
    );
};

export const parseStammesSnapshotPayload = (
    input: unknown,
    now: Date = new Date(),
): StammesSnapshotPayload => {
    const parsed = stammesSnapshotSchema.safeParse(input);

    if (!parsed.success) {
        throw buildValidationError(parsed.error.issues);
    }

    const futureFields = findFutureTimestampFields(parsed.data, now);

    if (futureFields.length > 0) {
        throw new AppError(
            'Snapshot payload is invalid',
            400,
            invalidDateTimeCode,
            futureFields,
        );
    }

    return parsed.data;
};

export { SUPPORTED_SCHEMA_VERSION };