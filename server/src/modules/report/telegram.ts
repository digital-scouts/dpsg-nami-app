import type { TelegramConfig } from '../../app/config.js';
import type { ReportNotifier } from './report.js';

const TELEGRAM_API = 'https://api.telegram.org';

// Schickt die Nachricht ueber die Bot-API (sendMessage) an einen festen Chat.
export const buildTelegramNotifier = (
    config: TelegramConfig,
    fetchFn: typeof fetch = fetch,
): ReportNotifier => ({
    send: async (text) => {
        const response = await fetchFn(`${TELEGRAM_API}/bot${config.botToken}/sendMessage`, {
            method: 'POST',
            headers: { 'content-type': 'application/json' },
            body: JSON.stringify({ chat_id: config.chatId, text, disable_web_page_preview: true }),
            signal: AbortSignal.timeout(10_000),
        });

        if (!response.ok) {
            // Antworttext ohne Token weitergeben; die URL enthaelt das Token und wird nicht geloggt.
            throw new Error(`Telegram antwortet mit ${response.status}: ${(await response.text()).slice(0, 200)}`);
        }
    },
});
