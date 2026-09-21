import { z } from 'zod';

import { AppError } from '../../shared/errors.js';

const SUPPORTED_SCHEMA_VERSION = '2026-04-01';
const ISO_TIMESTAMP_PATTERN = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?(?:Z|[+-]\d{2}:\d{2})$/;

const missingRequiredFieldCode = 'missing_required_field';
const invalidDateTimeCode = 'invalid_datetime';
const invalidMetricValueCode = 'invalid_metric_value';
const unsupportedSchemaVersionCode = 'unsupported_schema_version';
const invalidStammPlausibilityCode = 'invalid_stamm_plausibility';
const invalidSnapshotPayloadCode = 'invalid_snapshot_payload';

const requiredStringField = (_fieldName: string) =>
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

const isoDateTimeField = (_fieldName: string) =>
    z.any().transform((value, ctx) => {
        if (value === undefined || value === null || value === '') {
            ctx.addIssue({
                code: 'custom',
                message: missingRequiredFieldCode,
            });

            return z.NEVER;
        }

        if (typeof value !== 'string' || !ISO_TIMESTAMP_PATTERN.test(value.trim())) {
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

const metricsSchema = z
    .object({
        aktive_mitglieder: aktiveMitgliederSchema,
        passive_mitglieder: nullableMetricField,
        biber: countByGenderSchema,
        woelflinge: countByGenderSchema,
        jungpfadfinder: countByGenderSchema,
        pfadfinder: countByGenderSchema,
        rover: countByGenderSchema,
        leitende: leitendeSchema,
        leitende_biber: countByGenderSchema,
        leitende_woelflinge: countByGenderSchema,
        leitende_jungpfadfinder: countByGenderSchema,
        leitende_pfadfinder: countByGenderSchema,
        leitende_rover: countByGenderSchema,
        nicht_leitende_erwachsene: nullableMetricField,
        stammesvorstand: nullableMetricField,
        kuraten: nullableMetricField,
    })
    .superRefine((value, ctx) => {
        const coreFields = [
            ['biber', value.biber.gesamt],
            ['woelflinge', value.woelflinge.gesamt],
            ['jungpfadfinder', value.jungpfadfinder.gesamt],
            ['pfadfinder', value.pfadfinder.gesamt],
            ['rover', value.rover.gesamt],
        ] as const;

        const hasRelevantCoreMetric = coreFields.some(([, metricValue]) =>
            metricValue != null && metricValue > 0,
        );

        if (!hasRelevantCoreMetric) {
            for (const [fieldName] of coreFields) {
                ctx.addIssue({
                    code: 'custom',
                    message: invalidStammPlausibilityCode,
                    path: [fieldName, 'gesamt'],
                });
            }
        }
    })
    .transform((value) => ({
        aktive_mitglieder: value.aktive_mitglieder,
        passive_mitglieder: value.passive_mitglieder ?? null,
        biber: value.biber,
        woelflinge: value.woelflinge,
        jungpfadfinder: value.jungpfadfinder,
        pfadfinder: value.pfadfinder,
        rover: value.rover,
        leitende: value.leitende,
        leitende_biber: value.leitende_biber,
        leitende_woelflinge: value.leitende_woelflinge,
        leitende_jungpfadfinder: value.leitende_jungpfadfinder,
        leitende_pfadfinder: value.leitende_pfadfinder,
        leitende_rover: value.leitende_rover,
        nicht_leitende_erwachsene: value.nicht_leitende_erwachsene ?? null,
        stammesvorstand: value.stammesvorstand ?? null,
        kuraten: value.kuraten ?? null,
    }));

const stammesSnapshotSchema = z.object({
    schema_version: schemaVersionField,
    stamm_id: requiredStringField('stamm_id'),
    dv_id: requiredStringField('dv_id'),
    bezirk_id: optionalStringField,
    sender_id: requiredStringField('sender_id'),
    sent_at: isoDateTimeField('sent_at'),
    source_data_as_of: isoDateTimeField('source_data_as_of'),
    metrics: z.any().transform((value, ctx) => {
        if (value === undefined || value === null) {
            ctx.addIssue({
                code: 'custom',
                message: missingRequiredFieldCode,
            });

            return z.NEVER;
        }

        const parsedMetrics = metricsSchema.safeParse(value);

        if (!parsedMetrics.success) {
            for (const issue of parsedMetrics.error.issues) {
                ctx.addIssue({
                    ...issue,
                    path: issue.path,
                });
            }

            return z.NEVER;
        }

        return parsedMetrics.data;
    }),
});

export type StammesSnapshotPayload = z.infer<typeof stammesSnapshotSchema>;

const errorCodePriority = [
    unsupportedSchemaVersionCode,
    missingRequiredFieldCode,
    invalidDateTimeCode,
    invalidMetricValueCode,
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

    if (fieldPath.startsWith('metrics')) {
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

export const parseStammesSnapshotPayload = (
    input: unknown,
): StammesSnapshotPayload => {
    const parsed = stammesSnapshotSchema.safeParse(input);

    if (!parsed.success) {
        throw buildValidationError(parsed.error.issues);
    }

    return parsed.data;
};

export { SUPPORTED_SCHEMA_VERSION };