-- Create campaigns table
CREATE TABLE IF NOT EXISTS public.campaigns (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    image_url TEXT NOT NULL,
    brand TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('product', 'place', 'service')),
    type TEXT NOT NULL CHECK (type IN ('popular', 'new_', 'ongoing')),
    reward_points INTEGER NOT NULL DEFAULT 0,
    reward_type TEXT NOT NULL DEFAULT 'points' CHECK (reward_type IN ('points', 'product', 'coupon')),
    reward_description TEXT NOT NULL DEFAULT '',
    deadline TIMESTAMP WITH TIME ZONE NOT NULL,
    participant_count INTEGER DEFAULT 0 NOT NULL,
    max_participants INTEGER,
    status TEXT DEFAULT 'active' NOT NULL CHECK (status IN ('active', 'completed', 'upcoming')),
    requirements TEXT[] DEFAULT '{}' NOT NULL,
    tags TEXT[] DEFAULT '{}' NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_campaigns_category ON public.campaigns(category);
CREATE INDEX IF NOT EXISTS idx_campaigns_type ON public.campaigns(type);
CREATE INDEX IF NOT EXISTS idx_campaigns_status ON public.campaigns(status);
CREATE INDEX IF NOT EXISTS idx_campaigns_deadline ON public.campaigns(deadline);
CREATE INDEX IF NOT EXISTS idx_campaigns_created_at ON public.campaigns(created_at);
CREATE INDEX IF NOT EXISTS idx_campaigns_brand ON public.campaigns(brand);

-- Enable Row Level Security (RLS)
ALTER TABLE public.campaigns ENABLE ROW LEVEL SECURITY;

-- Create policies for campaigns
-- Anyone can view active campaigns
CREATE POLICY "Anyone can view active campaigns" ON public.campaigns
    FOR SELECT USING (status = 'active');

-- Only authenticated users can view all campaigns
CREATE POLICY "Authenticated users can view all campaigns" ON public.campaigns
    FOR SELECT USING (auth.role() = 'authenticated');

-- Only advertisers can create campaigns
CREATE POLICY "Advertisers can create campaigns" ON public.campaigns
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() AND user_type = 'advertiser'
        )
    );

-- Only campaign creators can update their campaigns
CREATE POLICY "Campaign creators can update their campaigns" ON public.campaigns
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.user_profiles 
            WHERE id = auth.uid() AND user_type = 'advertiser'
        )
    );

-- Create trigger to automatically update updated_at
CREATE OR REPLACE TRIGGER update_campaigns_updated_at
    BEFORE UPDATE ON public.campaigns
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
