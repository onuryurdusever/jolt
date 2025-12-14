-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Bookmarks Table
CREATE TABLE public.bookmarks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    original_url TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active',
    scheduled_for TIMESTAMPTZ,
    title TEXT,
    excerpt TEXT,
    content_html TEXT,
    cover_image TEXT,
    reading_time_minutes INTEGER DEFAULT 0,
    type TEXT DEFAULT 'article',
    domain TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    read_at TIMESTAMPTZ,
    user_note TEXT,
    last_scroll_percentage DOUBLE PRECISION,
    metadata JSONB,
    is_starred BOOLEAN DEFAULT FALSE,
    collection_id UUID, -- We'll add FK later or leave loose for sync
    is_protected BOOLEAN,
    is_paywalled BOOLEAN,
    fetch_method TEXT,
    parse_confidence DOUBLE PRECISION,
    expires_at TIMESTAMPTZ,
    archived_at TIMESTAMPTZ,
    archived_reason TEXT,
    recovered_at TIMESTAMPTZ,
    snooze_count INTEGER DEFAULT 0,
    intent TEXT
);

-- 2. Collections Table
CREATE TABLE public.collections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    color TEXT DEFAULT '#CCFF00',
    icon TEXT DEFAULT 'folder.fill',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add Foreign Key to Bookmarks for Collection
ALTER TABLE public.bookmarks 
ADD CONSTRAINT fk_collection 
FOREIGN KEY (collection_id) 
REFERENCES public.collections(id) 
ON DELETE SET NULL;

-- 3. Routines Table
CREATE TABLE public.routines (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    icon TEXT,
    hour INTEGER NOT NULL,
    minute INTEGER NOT NULL,
    days INTEGER[] DEFAULT '{1,2,3,4,5,6,7}',
    is_enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Sync Actions Table
CREATE TABLE public.sync_actions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    action_type TEXT NOT NULL,
    target_id UUID NOT NULL,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    is_processed BOOLEAN DEFAULT FALSE
);

-- RLS Policies (Row Level Security) - Basic Setup covers own data

ALTER TABLE public.bookmarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.routines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sync_actions ENABLE ROW LEVEL SECURITY;

-- Bookmarks Policies
CREATE POLICY "Users can view own bookmarks" ON public.bookmarks FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own bookmarks" ON public.bookmarks FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own bookmarks" ON public.bookmarks FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own bookmarks" ON public.bookmarks FOR DELETE USING (auth.uid() = user_id);

-- Collections Policies
CREATE POLICY "Users can view own collections" ON public.collections FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own collections" ON public.collections FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own collections" ON public.collections FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own collections" ON public.collections FOR DELETE USING (auth.uid() = user_id);

-- Routines Policies
CREATE POLICY "Users can view own routines" ON public.routines FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own routines" ON public.routines FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own routines" ON public.routines FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own routines" ON public.routines FOR DELETE USING (auth.uid() = user_id);

-- Sync Actions Policies
CREATE POLICY "Users can view own sync actions" ON public.sync_actions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own sync actions" ON public.sync_actions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own sync actions" ON public.sync_actions FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own sync actions" ON public.sync_actions FOR DELETE USING (auth.uid() = user_id);
