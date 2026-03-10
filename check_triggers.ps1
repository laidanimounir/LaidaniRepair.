$sql = "SELECT c.relname as table_name, t.tgname as trigger_name, p.proname as function_name, p.prosrc as function_logic FROM pg_trigger t JOIN pg_proc p ON t.tgfoid = p.oid JOIN pg_class c ON t.tgrelid = c.oid WHERE c.relname IN ('purchase_items', 'purchase_invoices', 'products', 'suppliers');"

npx -y supabase db query $sql --db-url "postgresql://postgres.igxpwxfruasfpvfagbaw:Laidani2025!!@aws-0-eu-central-1.pooler.supabase.com:6543/postgres"
