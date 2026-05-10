// ============================================
// SUPABASE EDGE FUNCTION - ART DECÒ
// send-appointment-reminders
// ============================================
// Configurazione completa - PRONTA ALL'USO
// Deploy: supabase functions deploy send-appointment-reminders

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ✅ CONFIGURAZIONE ONESIGNAL - Art Decò
const ONESIGNAL_APP_ID = "f6f03c5c-bb2d-4eb2-91b3-d5192747a10f";
const ONESIGNAL_REST_API_KEY = "nbfln3beuujl4hiwxrgdmaqz2";

// ✅ CONFIGURAZIONE SUPABASE - Art Decò
const SUPABASE_URL = "https://fykszvedjcgurryynhha.supabase.co";
const SUPABASE_SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5a3N6dmVkamNndXJyeXluaGhhIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjE4NzU4OSwiZXhwIjoyMDcxNzYzNTg5fQ.SCHl1DLsRPc2b8v3Oy7JwA8C7yZ9ELS1iGyjT_8Zuhs";

interface AppointmentData {
  id: number;
  data: string;
  ora_inizio: string;
  user_id: number;
  USERS: {
    uid: string;
    nome: string;
    cognome: string;
  };
  STYLIST: {
    descrizione: string;
  };
  APPUNTAMENTI_SERVIZI: Array<{
    SERVIZI: {
      descrizione: string;
    };
  }>;
}

/**
 * Invia una notifica push tramite OneSignal
 */
async function sendOneSignalNotification(
  firebaseUid: string,
  title: string,
  message: string,
  data: Record<string, any>
): Promise<boolean> {
  try {
    const response = await fetch("https://onesignal.com/api/v1/notifications", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Basic ${ONESIGNAL_REST_API_KEY}`,
      },
      body: JSON.stringify({
        app_id: ONESIGNAL_APP_ID,
        include_external_user_ids: [firebaseUid],
        headings: { en: title },
        contents: { en: message },
        android_channel_id: "appointments",
        priority: 10,
        data: data,
      }),
    });

    if (response.ok) {
      const result = await response.json();
      console.log(`✅ Notifica inviata con successo. ID: ${result.id}`);
      return true;
    } else {
      const error = await response.text();
      console.error(`❌ Errore OneSignal: ${response.status} - ${error}`);
      return false;
    }
  } catch (error) {
    console.error(`❌ Errore invio notifica:`, error);
    return false;
  }
}

/**
 * Formatta data in italiano
 */
function formatDate(dateString: string): string {
  const date = new Date(dateString);
  const weekdays = ['Domenica', 'Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato'];
  const months = [
    'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
    'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'
  ];

  return `${weekdays[date.getDay()]} ${date.getDate()} ${months[date.getMonth()]} ${date.getFullYear()}`;
}

/**
 * Main handler
 */
serve(async (req) => {
  try {
    console.log('🚀 Inizio processo invio reminder appuntamenti Art Decò...');

    // Inizializza Supabase client
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    // Calcola la data di domani
    const now = new Date();
    const tomorrow = new Date(now);
    tomorrow.setDate(tomorrow.getDate() + 1);
    tomorrow.setHours(0, 0, 0, 0);

    const tomorrowStr = tomorrow.toISOString().split('T')[0];
    console.log(`📅 Cerco appuntamenti per: ${tomorrowStr}`);

    // Query appuntamenti di domani
    const { data: appointments, error: queryError } = await supabase
      .from('APPUNTAMENTI')
      .select(`
        id,
        data,
        ora_inizio,
        user_id,
        USERS!inner(uid, nome, cognome),
        STYLIST!inner(descrizione),
        APPUNTAMENTI_SERVIZI(
          SERVIZI(descrizione)
        )
      `)
      .eq('data', tomorrowStr)
      .is('deleted_at', null);

    if (queryError) {
      throw queryError;
    }

    if (!appointments || appointments.length === 0) {
      console.log('ℹ️ Nessun appuntamento trovato per domani');
      return new Response(
        JSON.stringify({
          success: true,
          message: 'Nessun appuntamento da processare',
          total: 0,
          sent: 0
        }),
        {
          status: 200,
          headers: { "Content-Type": "application/json" }
        }
      );
    }

    console.log(`📋 Trovati ${appointments.length} appuntamenti per domani`);

    // Statistiche
    let sent = 0;
    let failed = 0;
    const results = [];

    // Processa ogni appuntamento
    for (const appt of appointments as AppointmentData[]) {
      try {
        // Prepara lista servizi
        const services = appt.APPUNTAMENTI_SERVIZI
          .map((s) => s.SERVIZI.descrizione)
          .join(', ');

        // Formato ora (rimuovi secondi)
        const time = appt.ora_inizio.substring(0, 5);

        // Crea messaggio
        const title = '📅 Promemoria Appuntamento';
        const message = `Ciao ${appt.USERS.nome}! Domani hai appuntamento alle ${time} con ${appt.STYLIST.descrizione} per: ${services}`;

        console.log(`📤 Invio notifica per appuntamento #${appt.id} a ${appt.USERS.nome} ${appt.USERS.cognome}`);

        // Invia notifica
        const success = await sendOneSignalNotification(
          appt.USERS.uid,
          title,
          message,
          {
            type: 'appointment_reminder',
            appointment_id: appt.id,
            date: appt.data,
            time: time,
          }
        );

        if (success) {
          sent++;
          results.push({
            appointment_id: appt.id,
            user: `${appt.USERS.nome} ${appt.USERS.cognome}`,
            status: 'sent',
          });
        } else {
          failed++;
          results.push({
            appointment_id: appt.id,
            user: `${appt.USERS.nome} ${appt.USERS.cognome}`,
            status: 'failed',
          });
        }

        // Piccola pausa per evitare rate limiting
        await new Promise(resolve => setTimeout(resolve, 100));

      } catch (err) {
        failed++;
        console.error(`❌ Errore processando appuntamento #${appt.id}:`, err);
        results.push({
          appointment_id: appt.id,
          status: 'error',
          error: String(err),
        });
      }
    }

    // Log finale
    console.log('✅ Processo completato');
    console.log(`   📊 Totale: ${appointments.length}`);
    console.log(`   ✅ Inviati: ${sent}`);
    console.log(`   ❌ Falliti: ${failed}`);

    // Registra l'esecuzione nel database
    try {
      await supabase.from('NOTIFICATION_LOGS').insert({
        type: 'reminder',
        date: tomorrowStr,
        total: appointments.length,
        sent: sent,
        failed: failed,
        executed_at: new Date().toISOString(),
        details: results,
      });
    } catch (logError) {
      console.error('⚠️ Errore logging:', logError);
    }

    // Risposta
    return new Response(
      JSON.stringify({
        success: true,
        message: 'Reminder inviati con successo',
        total: appointments.length,
        sent: sent,
        failed: failed,
        results: results,
      }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" }
      }
    );

  } catch (error) {
    console.error('💥 Errore generale:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : String(error),
      }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" }
      }
    );
  }
});