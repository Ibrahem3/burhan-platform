-- ============================================================
-- BURHAN PLATFORM — Official Sovereign Demo Seed Data
-- ============================================================

-- 1. Ensure Plans exist
INSERT INTO plans (slug, name, max_branches, max_storage_bytes, price_monthly_cents, is_active)
VALUES 
  ('community', '{"ar": "مجتمعي", "en": "Community"}', 3, 5368709120, 0, true),
  ('pro', '{"ar": "احترافي", "en": "Pro"}', 10, 53687091200, 4900, true)
ON CONFLICT (slug) DO NOTHING;

-- 2. Sovereign Organizations
INSERT INTO organizations (id, org_slug, name, settings)
VALUES 
  (
    '939d686d-b310-4d4e-bae2-ca5013f6519e',
    'burhan-lab',
    '{"ar": "مختبر بروتوكول بُرهان", "en": "Burhan Protocol Lab"}'::jsonb,
    '{"description": {"ar": "بنية تحتية سيادية للمعرفة الموزعة، توثيق مشفر، ومنظومات عمل محصنة ذاتياً.", "en": "Decentralized knowledge infrastructure, verifiable documentation, and sovereign workspace architecture."}}'::jsonb
  ),
  (
    'bd82c671-07dd-4ec8-930a-ba903936d06e',
    'nosana-deai',
    '{"ar": "كونسورتيوم نوزانا للذكاء الاصطناعي اللامركزي", "en": "Nosana DeAI Consortium"}'::jsonb,
    '{"description": {"ar": "أبحاث الحوسبة اللامركزية لمعالجات الرسوميات (GPU)، التشفير من طرف العميل، ونماذج الذكاء الاصطناعي غير الخاضعة للرقابة.", "en": "Benchmarking decentralized GPU inference, client-side encryption, and censorship-resistant AI tooling."}}'::jsonb
  ),
  (
    '95640ac7-dddd-4f85-827f-34a0c879ce33',
    'open-archives',
    '{"ar": "أرشيف السيادة المعرفية المفتوح", "en": "Open Sovereign Archives"}'::jsonb,
    '{"description": {"ar": "توثيق وأرشفة البحوث الاستقصائية، الدوريات الفكرية، والمخطوطات التقنية المحصنة ضد التعديل أو الحجب الرقمي.", "en": "Preserving uncensored investigative research, long-form journals, and verifiable technical manuscripts."}}'::jsonb
  )
ON CONFLICT (id) DO UPDATE SET
  org_slug = EXCLUDED.org_slug,
  name = EXCLUDED.name,
  settings = EXCLUDED.settings;

-- 3. Subscriptions (Active community plans)
INSERT INTO subscriptions (organization_id, plan_id, status, billing_period, starts_at, expires_at)
SELECT o.id, p.id, 'active', 'yearly', now(), NULL
FROM organizations o
CROSS JOIN (SELECT id FROM plans WHERE slug = 'community' LIMIT 1) p
WHERE o.id IN (
  '939d686d-b310-4d4e-bae2-ca5013f6519e',
  'bd82c671-07dd-4ec8-930a-ba903936d06e',
  '95640ac7-dddd-4f85-827f-34a0c879ce33'
)
ON CONFLICT DO NOTHING;

-- 4. Main Branches
INSERT INTO branches (id, organization_id, name, slug, module_type, is_active)
VALUES
  (
    '20622514-89cb-4a5f-b6c9-bc3992a439cf',
    '939d686d-b310-4d4e-bae2-ca5013f6519e',
    '{"ar": "الفرع الرئيسي", "en": "Main Branch"}'::jsonb,
    'main',
    'content',
    true
  ),
  (
    'ab0a8d8a-531b-40f0-be7d-a17dfeb9783f',
    'bd82c671-07dd-4ec8-930a-ba903936d06e',
    '{"ar": "الفرع الرئيسي", "en": "Main Branch"}'::jsonb,
    'main',
    'content',
    true
  ),
  (
    'e43d6e23-e795-4bbf-8ef7-ed3a81bd7495',
    '95640ac7-dddd-4f85-827f-34a0c879ce33',
    '{"ar": "الفرع الرئيسي", "en": "Main Branch"}'::jsonb,
    'main',
    'content',
    true
  )
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  is_active = EXCLUDED.is_active;

-- 5. Series Tracks
INSERT INTO series (id, organization_id, branch_id, title, description, is_active)
VALUES
  (
    'a8e7b969-c3b2-4a18-9375-e93bd5ba7265',
    '939d686d-b310-4d4e-bae2-ca5013f6519e',
    '20622514-89cb-4a5f-b6c9-bc3992a439cf',
    '{"ar": "الهندسة المعمارية السيادية والبرمجيات اللامركزية", "en": "Core Architecture & Sovereign SaaS"}'::jsonb,
    '{"ar": "المفاهيم التأسيسية لتصميم أنظمة المعرفة محكمة العزل والمستقلة عن الخوادم السحابية الاحتكارية.", "en": "Foundational paradigms for designing zero-custody, cryptographically isolated knowledge networks."}'::jsonb,
    true
  ),
  (
    'fb0cec02-6b30-4edb-abb3-ee13270fee66',
    'bd82c671-07dd-4ec8-930a-ba903936d06e',
    'ab0a8d8a-531b-40f0-be7d-a17dfeb9783f',
    '{"ar": "خطوط معالجة الذكاء الاصطناعي على شبكات GPU الموزعة", "en": "Decentralized GPU Compute Pipelines"}'::jsonb,
    '{"ar": "دليل هندسي لتشغيل وتوزيع نماذج الاستدلال اللغوي الكبيرة (LLMs) على عقد حوسبة مشتتة جغرافياً.", "en": "Engineering workflows for orchestrating open-weights LLM inference over globally decentralized GPU nodes."}'::jsonb,
    true
  ),
  (
    '35a00c2a-62a3-4bf9-b9a9-adb0f2c5ce10',
    '95640ac7-dddd-4f85-827f-34a0c879ce33',
    'e43d6e23-e795-4bbf-8ef7-ed3a81bd7495',
    '{"ar": "أنظمة حفظ وتداول المعرفة المقاومة للرقابة", "en": "Censorship-Resistant Knowledge Systems"}'::jsonb,
    '{"ar": "دراسات معيارية حول استدامة الوثائق التاريخية والأكاديمية باستخدام بروتوكولات العنونة بالمحتوى والتشفير الدائم.", "en": "Architectural standards for immutable archival, content-addressed indexing, and decentralized replication."}'::jsonb,
    true
  )
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  is_active = EXCLUDED.is_active;

-- 6. Verifiable Entities (Articles)
INSERT INTO entities (id, branch_id, organization_id, series_id, title, content, is_public_to_hub, is_premium, primary_source, content_type, sort_order)
VALUES
  (
    '0a846f48-1111-4000-8000-000000000001',
    '20622514-89cb-4a5f-b6c9-bc3992a439cf',
    '939d686d-b310-4d4e-bae2-ca5013f6519e',
    'a8e7b969-c3b2-4a18-9375-e93bd5ba7265',
    '{"ar": "القضاء على مخاطر المنصات: بنية انعدام الحفظ والسيادة الرقمية", "en": "Eliminating Platform Risk: The Zero-Custody Architecture"}'::jsonb,
    '{"ar": "تحليل تقني لكيفية بناء أنظمة حوسبة سحابية بدون وصاية مركزية، تضمن بقاء البيانات المشفرة تحت ملكية المستأجر حصراً دون إمكانية الوصول من مزودي الخدمة.", "en": "A comprehensive deep dive into zero-custody multi-tenant design, preventing platform vendor lock-in through cryptographic isolation."}'::jsonb,
    true, false, 'direct', 'article', 1
  ),
  (
    '0a846f48-1111-4000-8000-000000000002',
    '20622514-89cb-4a5f-b6c9-bc3992a439cf',
    '939d686d-b310-4d4e-bae2-ca5013f6519e',
    'a8e7b969-c3b2-4a18-9375-e93bd5ba7265',
    '{"ar": "التحقق البرمجي على المتصفح عبر WebAssembly وتشفير Ed25519", "en": "Client-Side Ed25519 WASM Verification on Solana"}'::jsonb,
    '{"ar": "كيفية تنفيذ عمليات التحقق والتوقيع الرقمي داخل المتصفح مباشرة عبر تجميعات WebAssembly، مما يلغي الحاجة لنقل المفاتيح الخاصة للخوادم.", "en": "Benchmarking high-throughput cryptographic verification inside the browser using WebAssembly and lightweight ed25519 primitives."}'::jsonb,
    true, false, 'direct', 'article', 2
  ),
  (
    '0a846f48-2222-4000-8000-000000000001',
    'ab0a8d8a-531b-40f0-be7d-a17dfeb9783f',
    'bd82c671-07dd-4ec8-930a-ba903936d06e',
    'fb0cec02-6b30-4edb-abb3-ee13270fee66',
    '{"ar": "تشغيل نماذج الاستدلال اللغوي على العناقيد اللامركزية", "en": "Running LLM Inference on Decentralized Clusters"}'::jsonb,
    '{"ar": "استراتيجيات توزيع الذاكرة وتقسيم أوزان النماذج عبر شبكات الند للند لتحقيق أداء يضاهي مراكز البيانات المركزية بتكلفة مخفضة وبدون رقابة.", "en": "Performance benchmarks and memory optimization strategies for distributed LLM inference across P2P node fleets."}'::jsonb,
    true, false, 'direct', 'article', 1
  ),
  (
    '0a846f48-2222-4000-8000-000000000002',
    'ab0a8d8a-531b-40f0-be7d-a17dfeb9783f',
    'bd82c671-07dd-4ec8-930a-ba903936d06e',
    'fb0cec02-6b30-4edb-abb3-ee13270fee66',
    '{"ar": "أمان مفاتيح التشفير الذاتية: عزل أسرار واجهات البرمجة على الحافة", "en": "BYOK Security: Isolating API Secrets on the Edge"}'::jsonb,
    '{"ar": "معايير Bring-Your-Own-Key (BYOK) لحماية واجهات البرمجة واستدعاءات الذكاء الاصطناعي من التسريب أو التخزين في السجلات المركزية.", "en": "Zero-knowledge edge secret vaults ensuring tenant API credentials are never logged or stored in centralized inference gateways."}'::jsonb,
    true, false, 'direct', 'article', 2
  ),
  (
    'dec21909-df7b-4128-8bad-69b5e6cc885e',
    'e43d6e23-e795-4bbf-8ef7-ed3a81bd7495',
    '95640ac7-dddd-4f85-827f-34a0c879ce33',
    '35a00c2a-62a3-4bf9-b9a9-adb0f2c5ce10',
    '{"ar": "السوابق التاريخية للاغتيال الرقمي ومحو المعرفة", "en": "Historical Precedents of Digital Assassination"}'::jsonb,
    '{"ar": "توثيق شامل لكيفية تحكم الكيانات الاحتكارية في محو الأبحاث والوثائق الحيوية، والحاجة الملحة للبنى التحتية السيادية الدائمة.", "en": "An investigative examination of modern digital deplatforming and historical censorship, necessitating sovereign knowledge infrastructure."}'::jsonb,
    true, false, 'direct', 'article', 1
  ),
  (
    'a8e78f7c-fe64-4d8f-833d-3b67ff8e5440',
    'e43d6e23-e795-4bbf-8ef7-ed3a81bd7495',
    '95640ac7-dddd-4f85-827f-34a0c879ce33',
    '35a00c2a-62a3-4bf9-b9a9-adb0f2c5ce10',
    '{"ar": "أرشفة الوسائط المعتمدة عبر العنونة بالمحتوى والتجزئة التشفيرية", "en": "Verifiable Media Archiving via Content Addressing"}'::jsonb,
    '{"ar": "استخدام بصمات التجزئة التشفيرية (Cryptographic Hashes) لإثبات سلامة وتطابق المخطوطات والوسائط التاريخية عبر الزمن دون وسيط.", "en": "Employing cryptographic hash verification and content-addressing schemes to preserve multimedia provenance indefinitely."}'::jsonb,
    true, false, 'direct', 'article', 2
  ),
  (
    'ceffed79-4e9a-4acd-a262-f371f23914fa',
    'e43d6e23-e795-4bbf-8ef7-ed3a81bd7495',
    '95640ac7-dddd-4f85-827f-34a0c879ce33',
    '35a00c2a-62a3-4bf9-b9a9-adb0f2c5ce10',
    '{"ar": "مصفوفات المعرفة المقاومة للحجب: بروتوكولات المزامنة في الشبكات المغلقة", "en": "Air-Gapped Sync: Sovereign Knowledge Arrays under Network Partitions"}'::jsonb,
    '{"ar": "كيف تعمل منصات المعرفة السيادية أثناء انقطاع الإنترنت أو الحجب الإقليمي عبر المزامنة اللاسلكية والذاكرة المحلية المشفرة.", "en": "Resilient peer synchronization protocols that maintain verifiable knowledge bases even during total internet blackouts."}'::jsonb,
    true, false, 'direct', 'article', 3
  )
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  is_public_to_hub = EXCLUDED.is_public_to_hub,
  is_premium = EXCLUDED.is_premium,
  sort_order = EXCLUDED.sort_order;
