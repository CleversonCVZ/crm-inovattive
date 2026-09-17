/* config.js — configuração de ambiente do OMNI.
   Este arquivo existe pra permitir que o MESMO código (omni-desktop.html /
   omni-mobile.html) sirva deploys diferentes (ex.: um beta tester futuro,
   cada um com seu próprio banco Supabase) sem duplicar o HTML inteiro —
   só esse arquivo muda entre um deploy e outro.

   Valores abaixo são os da Inovattive (produção atual) — nada mudou na
   prática, só o LUGAR onde esses dois valores moram no código.
   Ver supabase/PLANO-COMERCIALIZACAO.md para o contexto completo. */
window.OMNI_CONFIG = {
  supabaseUrl: 'https://bazoyvccbxtjwfbldvuz.supabase.co',
  supabaseKey: 'sb_publishable_z5HBPMKrCcMOYRfS5SQSTg_Gl04txHM'
};
