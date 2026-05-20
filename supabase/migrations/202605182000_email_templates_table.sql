-- Create email_templates table and seed core templates
CREATE TABLE IF NOT EXISTS public.email_templates (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  template_key TEXT UNIQUE NOT NULL,
  subject TEXT NOT NULL,
  body_html TEXT NOT NULL,
  variables JSONB DEFAULT '[]',
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.email_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "email_templates_authenticated_read" ON public.email_templates
  FOR SELECT TO authenticated USING (true);
