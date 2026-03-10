const { Client } = require('pg');
const fs = require('fs');
const client = new Client({
  connectionString: 'postgresql://postgres.igxpwxfruasfpvfagbaw:Laidani2025!!@aws-0-eu-central-1.pooler.supabase.com:6543/postgres'
});
async function run() {
  try {
    await client.connect();
    const res = await client.query(
      SELECT c.relname as table_name, t.tgname as trigger_name, p.proname as function_name, p.prosrc as function_logic 
      FROM pg_trigger t 
      JOIN pg_proc p ON t.tgfoid = p.oid 
      JOIN pg_class c ON t.tgrelid = c.oid 
      WHERE c.relname IN ('purchase_items', 'purchase_invoices', 'products', 'suppliers')
      AND t.tgisinternal = false;
    );
    fs.writeFileSync('triggers.json', JSON.stringify(res.rows, null, 2));
    console.log('Success');
  } catch (err) {
    console.error(err);
  } finally {
    await client.end();
  }
}
run();
