const cp = require('child_process');
const fs = require('fs');
const sql = `SELECT c.relname as table_name, t.tgname as trigger_name, p.proname as function_name, p.prosrc as function_logic FROM pg_trigger t JOIN pg_proc p ON t.tgfoid = p.oid JOIN pg_class c ON t.tgrelid = c.oid WHERE c.relname IN ('purchase_items', 'purchase_invoices', 'products', 'suppliers');`;
const url = 'postgresql://postgres.igxpwxfruasfpvfagbaw:Laidani2025!!@aws-0-eu-central-1.pooler.supabase.com:6543/postgres';

try {
    const result = cp.execSync(`npx -y supabase db query "${sql}" --db-url "${url}"`, { encoding: 'utf-8' });
    fs.writeFileSync('trigger_results.txt', result);
    console.log('Success, wrote to trigger_results.txt');
} catch (e) {
    console.error('Failed:', e.message);
}
