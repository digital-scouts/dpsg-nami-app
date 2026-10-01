import nodemailer from 'nodemailer';

import type { ReportConfig } from '../../app/config.js';
import type { ReportMailer } from './report.js';

export const buildSmtpReportMailer = (config: ReportConfig): ReportMailer => {
    const transport = nodemailer.createTransport({
        host: config.smtpHost,
        port: config.smtpPort,
        // Port 465 spricht direkt TLS, alle anderen Ports nutzen STARTTLS.
        secure: config.smtpPort === 465,
        requireTLS: config.smtpPort !== 465,
        auth: config.smtpUser != null ? { user: config.smtpUser, pass: config.smtpPass ?? '' } : undefined,
    });

    return {
        send: async (message) => {
            await transport.sendMail({
                from: config.mailFrom,
                to: config.mailTo,
                subject: message.subject,
                text: message.text,
            });
        },
    };
};
